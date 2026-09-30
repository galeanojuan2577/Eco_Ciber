"""BBAS Pipeline — ingesta de resultados y encadenamiento subfinder→httpx→nuclei.

Cada unidad completada alimenta la siguiente fase:
  subfinder → crea targets + encola httpx por subdominio (cap MAX_FANOUT)
  httpx     → actualiza target (status/tech/locked/score) [+ encola nuclei si deep]
  nuclei    → crea findings deduplicados
Todas las escrituras usan transacciones con reintento ante lock.
"""
from __future__ import annotations

import json
import re
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

from .models.database import Database
from .models.models import WorkUnit
from .utils.logger import get_logger

logger = get_logger(__name__)

MAX_FANOUT = 500


def normalize_seed(raw: str) -> str:
    """'*.optus.com.au' / 'https://www.x.com/path' → dominio raíz escaneable."""
    t = raw.strip()
    t = re.sub(r'^https?://', '', t)
    t = t.split('/')[0].split(':')[0]
    t = t.lstrip('.').lower()
    if t.startswith('*.'):
        t = t[2:]
    return t


def _host_from_url(url: str) -> str:
    try:
        return urlparse(url).netloc.lower()
    except Exception:
        return url.lower()


def _score_heuristic(status: int = 0, line: str = '', locked: Optional[str] = None) -> int:
    if locked:
        return 5
    s = 5
    low = (line or '').lower()
    if 200 <= status < 300:
        s = 20
    elif 300 <= status < 400:
        s = 10
    elif status in (401, 403):
        s = 15
    if any(k in low for k in ['react', 'next', 'vue', 'angular', 'graphql', 'swagger',
                              'openapi', 'node', 'express', 'api', 'nest']):
        s += 15
    elif any(c in low for c in ['wordpress', 'drupal', 'joomla']):
        s += 10
    if any(k in low for k in ['admin', 'login', 'portal', 'staging', 'dev', 'test',
                              'api', 'swagger', 'graphql', 'actuator', '.git', '.env',
                              'oauth', 'panel']):
        s += 15
    cdn = any(x in low for x in ['cloudflare', 'akamai', 'imperva', 'cloudfront', 'fastly'])
    if cdn and not (200 <= status < 300):
        s = min(s, 5)
    return min(100, s)


# ──────────────────────────── TARGETS ────────────────────────────

def upsert_target(db: Database, project_id: str, host: str,
                  url: str = '', score: int = 20) -> int:
    row = db.fetchone(
        "SELECT id FROM targets WHERE project_id = ? AND host = ?",
        (project_id, host),
    )
    if row:
        return row["id"]
    with db.transaction():
        cur = db.execute(
            "INSERT INTO targets (project_id, host, url, score) VALUES (?, ?, ?, ?)",
            (project_id, host, url or f"https://{host}", score),
        )
        return cur.lastrowid


def update_target_probe(db: Database, project_id: str, host: str, probe: Dict[str, Any]) -> None:
    tech = probe.get("tech") or []
    row = db.fetchone(
        "SELECT id FROM targets WHERE project_id = ? AND host = ?", (project_id, host)
    )
    tid = row["id"] if row else upsert_target(db, project_id, host)
    score = _score_heuristic(int(probe.get("status_code") or 0),
                             json.dumps(probe), probe.get("locked_type"))
    with db.transaction():
        db.execute(
            """UPDATE targets SET url=?, ip=?, status_code=?, title=?, server=?,
                                  tech_stack=?, cdn=?, locked_type=?, score=?,
                                  last_scanned=CURRENT_TIMESTAMP, updated_at=CURRENT_TIMESTAMP
               WHERE id=?""",
            (
                probe.get("url") or f"https://{host}",
                probe.get("ip", ""),
                int(probe.get("status_code") or 0),
                probe.get("title", ""),
                probe.get("webserver", ""),
                json.dumps(tech),
                ",".join(probe.get("cdn") or []),
                probe.get("locked_type", ""),
                score,
                tid,
            ),
        )


# ──────────────────────── INGEST POR TIPO ────────────────────────

def ingest_subfinder(db: Database, queue, unit: WorkUnit, data: List[str]) -> int:
    pid = unit.project_id
    created = 0
    subs = [s.strip().lower() for s in data if s and '.' in s]
    root = unit.target_host.lower()
    for seed_host in (root, f"www.{root}"):
        if seed_host not in subs:
            subs.insert(0, seed_host)
    existing = {
        r["host"]
        for r in db.fetchall("SELECT host FROM targets WHERE project_id = ?", (pid,))
    }
    fanout = 0
    params_base = unit.parameters_dict or {}
    for sub in subs[:MAX_FANOUT]:
        if sub not in existing:
            upsert_target(db, pid, sub)
            created += 1
        if fanout < MAX_FANOUT:
            queue.enqueue(WorkUnit(
                scan_job_id=unit.scan_job_id,
                project_id=pid,
                unit_type="httpx",
                target_host=sub,
                target_url=f"https://{sub}",
                priority=5,
                parameters={"deep": bool(params_base.get("deep"))},
            ))
            fanout += 1
    logger.info(f"[pipeline] subfinder {unit.target_host}: {created} nuevos, {fanout} httpx")
    return created


def detect_locked(probe: Dict[str, Any]) -> str:
    final = (probe.get("final_url") or "").lower()
    status = int(probe.get("status_code") or 0)
    if 'github.com/login' in final or 'github.com' in final:
        return 'github-pages'
    if status in (530, 523, 524):
        return 'cf-error'
    if any(s in final for s in ('okta.com/oauth2', 'login.microsoftonline.com',
                                'auth0.com/authorize', 'onelogin.com')):
        return 'sso'
    if 'shopify' in final and '/password' in final:
        return 'shopify-password'
    return ''


def ingest_httpx(db: Database, queue, unit: WorkUnit, items: List[Dict[str, Any]]) -> int:
    pid = unit.project_id
    deep = bool((unit.parameters_dict or {}).get("deep"))
    updated = 0
    seen_hosts = set()
    for it in items:
        host = (it.get("host") or _host_from_url(it.get("url", ""))).lower()
        if not host or host in seen_hosts:
            continue
        seen_hosts.add(host)
        locked = detect_locked(it)
        probe = {
            "url": it.get("url"),
            "ip": it.get("ip"),
            "status_code": it.get("status_code"),
            "title": it.get("title"),
            "webserver": it.get("webserver"),
            "tech": it.get("tech") or [],
            "cdn": it.get("cdn") or [],
            "locked_type": locked,
            "final_url": it.get("final_url"),
        }
        update_target_probe(db, pid, host, probe)
        updated += 1
        if deep and not locked and (int(it.get("status_code") or 0) > 0):
            queue.enqueue(WorkUnit(
                scan_job_id=unit.scan_job_id,
                project_id=pid,
                unit_type="nuclei",
                target_host=host,
                target_url=f"https://{host}",
                priority=1,
                parameters={},
            ))
    logger.info(f"[pipeline] httpx: {updated} actualizados (deep={deep})")
    return updated


def ingest_nuclei(db: Database, unit: WorkUnit, findings: List[Dict[str, Any]]) -> int:
    pid = unit.project_id
    created = 0
    batch = []
    for f in findings:
        host = (f.get("host") or unit.target_host).lower()
        title = f.get("name") or f.get("template_id") or "finding"
        sev = (f.get("severity") or "info").lower()
        cves = ",".join(f.get("cve") or [])
        cwes = ",".join(f.get("cwe") or [])
        dup = db.fetchone(
            """SELECT id FROM findings WHERE project_id=? AND target_host=? AND title=? AND tool='nuclei'""",
            (pid, host, title),
        )
        if dup:
            continue
        batch.append((pid, host, 'vuln', sev, cwes, cves, title,
                      f.get("description", ""), f.get("matched_at", ""), 'nuclei',
                      json.dumps(f.get("tags") or []),
                      'medium' if sev in ('critical', 'high') else 'low',
                      'easy' if sev in ('critical', 'info') else 'medium'))
        created += 1
    if batch:
        with db.transaction():
            for b in batch:
                db.execute(
                    """INSERT INTO findings (project_id, target_host, type, severity, cwe_id, cve_id,
                             title, description, evidence, tool, tags, status,
                             bounty_probability, exploit_difficulty)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open', ?, ?)""",
                    b,
                )
    logger.info(f"[pipeline] nuclei {unit.target_host}: {created} findings nuevos")
    return created


def ingest_unit_result(db: Database, queue, unit: WorkUnit, result: Dict[str, Any]) -> None:
    utype = unit.unit_type
    data = result.get("data")
    try:
        if utype == "subfinder" and isinstance(data, list):
            ingest_subfinder(db, queue, unit, data)
        elif utype == "httpx" and isinstance(data, list):
            ingest_httpx(db, queue, unit, data)
        elif utype == "nuclei" and isinstance(data, list):
            ingest_nuclei(db, unit, data)
    except Exception as e:
        logger.error(f"[pipeline] error ingiriendo {utype} {unit.target_host}: {e}")


# ──────────────────── CLASIFICACIÓN DE TARGETS ────────────────────

MULTI_SUFFIXES = {
    'com.au', 'net.au', 'org.au', 'edu.au', 'gov.au',
    'com.mx', 'gob.mx', 'com.ar', 'com.br', 'co.nz', 'co.uk', 'org.uk',
    'com.co', 'com.pe', 'com.uy', 'gub.uy', 'com.py', 'com.ec',
}


def sanitize_host(raw: str) -> str:
    """URL/host → host pelado en minúsculas."""
    t = (raw or '').strip()
    t = re.sub(r'^[a-zA-Z][a-zA-Z0-9+.-]*://', '', t)
    t = t.split('/')[0].split('?')[0].split(':')[0]
    t = t.lower().rstrip('.')
    while t.startswith('*.') or t.startswith('.'):  # wildcards
        t = t[2:] if t.startswith('*.') else t[1:]
    return t


def classify_target(raw: str) -> str:
    """'domain_root' | 'subdomain' | 'ip' | 'cidr' | 'invalid'"""
    raw_stripped = (raw or '').strip()
    t = sanitize_host(raw_stripped)
    if not t:
        return 'invalid'
    if raw_stripped.count('/') >= 1 and any(c.isdigit() for c in t.split('.')[0]) and '/' in raw_stripped:
        return 'cidr'
    if re.match(r'^\d{1,3}(\.\d{1,3}){3}$', t):
        return 'ip'
    labels = [l for l in t.split('.') if l]
    if len(labels) < 2:
        return 'invalid'
    last2 = '.'.join(labels[-2:])
    if last2 in MULTI_SUFFIXES:
        return 'domain_root' if len(labels) == 3 else 'subdomain'
    return 'domain_root' if len(labels) == 2 else 'subdomain'
