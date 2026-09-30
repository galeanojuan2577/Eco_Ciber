"""BBAS Importador de programas de bug bounty.

Estrategia:
  - HackerOne: API JSON directa (https://hackerone.com/<slug>/json)
  - Resto (Bugcrowd, Intigriti, genérico): render Chromium (extract.cjs) + parser de texto
Devuelve preview estructurado con in_scope / out_scope / reglas / puede-no-puede.
"""
from __future__ import annotations

import json
import re
import subprocess
from typing import Any, Dict, List
from urllib.parse import urlparse

from ..utils.logger import get_logger

logger = get_logger(__name__)

EXTRACT_CJS = "/root/.config/bbas/core/importer/extract.cjs"
PW_DIR = "/tmp/opencode/pw-diag"

# Tokens que cuentan como target (dominio/wildcard/URL/IP-CIDR)
TOKEN_RE = re.compile(
    r"(?:https?://)?(?:\*\.)?[a-z0-9][a-z0-9._-]*\.[a-z]{2,}(?:/[^\s,;)]*)?"
    r"|\d{1,3}(?:\.\d{1,3}){3}/?\d{0,2}"
    , re.I)

EXCLUDE_TOKENS = re.compile(
    r"bugcrowd\.com|hackerone\.com|intigriti\.com|yeswehack\.net|example\.com|"
    r"\.(png|jpg|jpeg|gif|svg|css|js|woff2?)$|sentry\.io|googleapis\.com|"
    r"w3\.org|schema\.org", re.I)


def _run_extractor(url: str, wait_ms: int = 6000) -> Dict[str, Any]:
    try:
        r = subprocess.run(
            ["node", EXTRACT_CJS, url, str(wait_ms)],
            cwd=PW_DIR, capture_output=True, text=True, timeout=120,
        )
        for line in reversed((r.stdout or "").splitlines()):
            line = line.strip()
            if line.startswith("{"):
                d = json.loads(line)
                if "ok" in d:
                    return d
        return {"ok": False, "error": (r.stderr or "sin salida")[:300]}
    except Exception as e:
        return {"ok": False, "error": str(e)}


# ─────────────────────────── PARSER ───────────────────────────

SECTION_IN = re.compile(r"^\s*(in[\s-]*scope|targets?|scope)\b.*$", re.I)
SECTION_OUT = re.compile(r"^\s*(out[\s-]*(of[\s-]*)?scope|excluded|exceptions?)\b.*$", re.I)


def parse_scope_text(text: str) -> Dict[str, Any]:
    in_scope: List[str] = []
    out_scope: List[str] = []
    section = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if SECTION_OUT.match(line):
            section = "out"
            continue
        if SECTION_IN.match(line):
            section = "in"
            continue
        # cortes de sección por encabezados comunes
        if re.match(r"^(rewards?|severity|brief|rules?|policy|description|reports?)\b", line, re.I):
            section = None
            continue
        tokens = [t.rstrip('.,;') for t in TOKEN_RE.findall(line)]
        tokens = [t for t in tokens if not EXCLUDE_TOKENS.search(t)]
        if not tokens:
            continue
        target_bucket = out_scope if ('out of scope' in line.lower() or section == "out") else (
            in_scope if section == "in" else in_scope)
        for t in tokens:
            bucket = out_scope if any(x in t.lower() for x in ()) or section == "out" else in_scope
            if t not in bucket and len(t) > 4:
                bucket.append(t)

    def clean(lst: List[str]) -> List[str]:
        seen, out = set(), []
        for t in lst:
            t = t.lower().rstrip('/')
            if t and t not in seen:
                seen.add(t)
                out.append(t)
        return out

    return {"in_scope": clean(in_scope), "out_scope": clean(out_scope)}


RULE_PATTERNS = [
    ("scanners",      r"automat(ed|ic|ization)|scanner?s?\s+(are\s+)?(not\s+)?(allowed|permitted)|no\s+scanning", True),
    ("dos",           r"denial.of.service|\bdos\b|load.test|stress.test|flood", True),
    ("phishing",      r"phish(ing)?|social.engineer", True),
    ("spam",          r"spam(ming)?\b", True),
    ("creds_needed",  r"credential(s)?\s+(required|provided|needed)|authenticated\s+testing", False),
    ("physical",      r"social.engineering|physical.attack|vishing", True),
]

CAN_DO_MAP = {
    "recon_pasivo": r"passive.recon|osint",
    "xss_sqli_rce": r"xss|sql.?injection|rce|ssrf|idor|auth(entication)?.?bypass",
}


def extract_rules(text: str) -> Dict[str, Any]:
    low = text.lower()
    forbidden: List[str] = []
    allowed_notes: List[str] = []
    flags: Dict[str, Any] = {}

    for key, pat, is_forbidden in RULE_PATTERNS:
        m = re.search(pat, low)
        if m:
            flags[key] = True if is_forbidden else "mencionado"
            if is_forbidden:
                label = {
                    "scanners": "Scanners/automatización (revisar términos: pueden exigir límites)",
                    "dos": "DoS / stress testing",
                    "phishing": "Phishing",
                    "spam": "Spam",
                    "physical": "Ingeniería social / ataques físicos",
                }[key]
                forbidden.append(label)
    if "rate limit" in low or "request" in low and "per second" in low:
        allowed_notes.append("Respeta rate limits mencionados en el programa")

    can_do = [
        "Recon pasivo y enumeración de subdominios (con límites razonables)",
        "Testing manual de vulnerabilidades web (IDOR, auth, lógica de negocio)",
    ]
    if not flags.get("scanners"):
        can_do.append("Scanners automatizados ligeros (nuclei/httpx) — sin límite agresivo")
    else:
        can_do.append("Escaneo automatizado SOLO si el programa lo permite explícitamente en su texto")
    cant_do = forbidden or ["Nada fuera del alcance definido (sigue el estándar VDP/RT del sector)"]
    return {"flags": flags, "can_do": can_do, "cant_do": cant_do,
            "allowed_notes": allowed_notes}


def _platform_from_url(url: str) -> str:
    host = urlparse(url).netloc.lower()
    if "bugcrowd" in host:
        return "bugcrowd"
    if "hackerone" in host:
        return "hackerone"
    if "intigriti" in host:
        return "intigriti"
    return "generico"


def _hackerone_json(url: str) -> Dict[str, Any]:
    path = urlparse(url).path.strip("/")
    slug = path.split("/")[0]
    import urllib.request
    req = urllib.request.Request(
        f"https://hackerone.com/{slug}/json",
        headers={"Accept": "application/json",
                 "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) Chrome/126"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.load(resp)
    name = data.get("name") or slug
    rel = data.get("relationships", {})
    targets = rel.get("structured_scopes", {}).get("data", [])
    ins, outs = [], []
    for t in targets:
        a = t.get("attributes", {})
        item = {"target": (a.get("asset_identifier") or "").lower(),
                "type": a.get("asset_type"), "eligible": a.get("eligible_for_bounty")}
        if a.get("eligible_for_submission") is False or a.get("instruction") and \
           "out of scope" in (a.get("instruction") or "").lower():
            outs.append(item["target"])
        else:
            (ins if a.get("eligible_for_bounty", True) else outs).append(item["target"])
    return {"platform": "hackerone", "program": name, "raw_text": "",
            "in_scope": [i for i in ins if i], "out_scope": [o for o in outs if o]}


def analyze_program(url: str) -> Dict[str, Any]:
    platform = _platform_from_url(url)

    if platform == "hackerone":
        try:
            d = _hackerone_json(url)
            rules = extract_rules(json.dumps(d) + " no dos phishing spam")
            d.update(rules)
            d["source"] = "hackerone-json"
            return d
        except Exception as e:
            logger.warning(f"H1 json falló ({e}); caigo a render")

    ext = _run_extractor(url)
    if not ext.get("ok"):
        return {"ok": False, "error": f"No pude renderizar la página: {ext.get('error')}"}

    text = ext.get("text") or ""
    parsed = parse_scope_text(text)
    rules = extract_rules(text)
    title = ext.get("title") or ""
    program = re.sub(r"\s*[\|\-–]\s*(Bugcrowd|HackerOne).*$", "", title, flags=re.I).strip() or \
              urlparse(url).path.strip("/").split("/")[-1]
    return {
        "ok": True,
        "platform": platform,
        "source": "render",
        "program": program,
        "url": url,
        **parsed,
        **rules,
    }
