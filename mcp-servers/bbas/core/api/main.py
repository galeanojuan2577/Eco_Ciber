"""BBAS HTTP API"""
import os
import json
import re
import uuid
import subprocess
from datetime import datetime
from typing import Optional, List, Dict, Any
from pathlib import Path

from fastapi import FastAPI, HTTPException, BackgroundTasks, Query, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, Response, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from ..models.database import Database, init_db
from ..models.models import (
    Project, ScopeRule, Target, Finding, AttackPath,
    Session, ScanJob, WorkUnit
)
from ..queue.queue import TaskQueue, WorkUnitQueue, QueueConfig
from ..workers import WorkerPool, WorkerConfig, ReconWorker, ScanWorker, EnumWorker
from ..scanners import (
    SubfinderScanner, HttpxScanner, NucleiScanner,
    ZAPScanner, NiktoScanner, GobusterScanner,
    AmassScanner, NmapScanner
)
from ..utils.config import load_config, Config
from ..utils.scope import check_scope, load_scope, ScopeChecker
from ..utils.logger import get_logger
from ..pipeline import normalize_seed, classify_target
import asyncio
import time as _time
from ..importer.importer import analyze_program
from ..utils.scope import UNIT_PHASE


logger = get_logger(__name__)

# Directorio del frontend construido (Vite)
WEB_UI_DIR = Path(os.path.expanduser("~/.config/bbas/web-ui/dist"))

# Global instances
config: Config = None
db: Database = None
task_queue: TaskQueue = None
work_unit_queue: WorkUnitQueue = None
worker_pool: WorkerPool = None
scope_checker: ScopeChecker = None


# Pydantic models for API
class ProjectCreate(BaseModel):
    name: str
    program_url: str = ""
    config: Dict[str, Any] = {}


class ProjectResponse(BaseModel):
    id: str
    name: str
    program_url: str
    scope_file: str
    folder: Optional[str] = None
    created_at: str
    updated_at: str
    config: Dict[str, Any]


class ScopeRuleCreate(BaseModel):
    target: str
    type: str = "all"
    until: Optional[str] = None
    note: str = ""
    excluded: bool = False


class ScopeRuleResponse(BaseModel):
    id: int
    project_id: str
    target: str
    type: str
    since: str
    until: Optional[str]
    note: str
    excluded: bool


class SessionCreate(BaseModel):
    project_id: str
    name: str = ""
    config: Dict[str, Any] = {}


class SessionResponse(BaseModel):
    id: int
    project_id: str
    name: str
    status: str
    started_at: str
    ended_at: Optional[str]
    config: Dict[str, Any]
    stats: Dict[str, Any]


class ScanJobCreate(BaseModel):
    session_id: int
    job_type: str
    target_pattern: str = ""
    priority: int = 0
    total_targets: int = 0


class ScanJobResponse(BaseModel):
    id: int
    session_id: int
    job_type: str
    target_pattern: str
    status: str
    priority: int
    progress: int
    total_targets: int
    completed_targets: int
    error_message: str
    started_at: Optional[str]
    completed_at: Optional[str]


class WorkUnitResponse(BaseModel):
    id: int
    scan_job_id: int
    unit_type: str
    target_host: str
    target_url: str
    status: str
    priority: int
    attempts: int
    max_attempts: int
    result: Dict[str, Any]
    error_message: str


class FindingCreate(BaseModel):
    project_id: str
    target_id: Optional[int] = None
    target_host: str
    type: str = "vuln"
    severity: str = "medium"
    cvss_score: Optional[float] = None
    cwe_id: str = ""
    cve_id: str = ""
    title: str
    description: str = ""
    poc: str = ""
    tool: str = "manual"
    tags: List[str] = []
    status: str = "open"
    bounty_probability: str = "unknown"
    exploit_difficulty: str = "medium"


class FindingResponse(BaseModel):
    id: Optional[int] = None
    project_id: str
    target_id: Optional[int] = None
    target_host: str
    type: str = "vuln"
    severity: str = "medium"
    cvss_score: Optional[float] = None
    cwe_id: str = ""
    cve_id: str = ""
    title: str
    description: str = ""
    poc: str = ""
    tool: str = "manual"
    tags: List[str] = []
    status: str = "open"
    bounty_probability: str = "unknown"
    exploit_difficulty: str = "medium"


class AttackPathResponse(BaseModel):
    id: int
    project_id: str
    name: str
    description: str
    steps: List[Dict[str, Any]]
    findings_ids: List[int]
    severity: str
    bounty_potential: str
    status: str


class TargetResponse(BaseModel):
    id: int
    project_id: str
    host: str
    url: str
    ip: str
    status_code: int
    title: str
    server: str
    tech_stack: List[str]
    cdn: str
    locked_type: str
    score: int


class ScanRequest(BaseModel):
    targets: List[str]
    project_id: str
    job_type: str = "recon"
    deep: bool = False


class FindingFilter(BaseModel):
    project_id: Optional[str] = None
    min_severity: Optional[str] = None
    tech: Optional[str] = None
    status: Optional[str] = None
    limit: int = 100
    offset: int = 0


def detail_dict(rejected: list, msg: str):
    d = {"message": msg}
    if rejected:
        d["rejected"] = rejected
        d["hint"] = ("Importa el programa desde la pestaña correspondiente o añade "
                     "reglas en Settings → Scope (soporta wildcards *.dominio.tld).")
    return d



BUGBONTY_DIR = Path("/root/Bugbonty")


def _project_folder(name: str) -> Path:
    d = BUGBONTY_DIR / name
    (d / "reports").mkdir(parents=True, exist_ok=True)
    return d


def _sync_fs_projects() -> int:
    """Registra como proyectos las carpetas de /root/Bugbonty que falten."""
    n = 0
    if BUGBONTY_DIR.exists():
        for d in sorted(BUGBONTY_DIR.iterdir()):
            if d.is_dir() and not db.fetchone("SELECT id FROM projects WHERE id=?", (d.name,)):
                try:
                    with db.transaction():
                        db.execute(
                            "INSERT INTO projects (id,name,folder,config_json) VALUES (?,?,?,'{}')",
                            (d.name, d.name, str(d)))
                    n += 1
                except Exception:
                    pass
    return n

# Create FastAPI app
def create_app(cfg: Config = None) -> FastAPI:
    global config, db, task_queue, work_unit_queue, worker_pool, scope_checker
    
    config = cfg or load_config()
    db = init_db()
    task_queue = TaskQueue(QueueConfig())
    work_unit_queue = WorkUnitQueue(QueueConfig())
    scope_checker = ScopeChecker()

    app = FastAPI(
        title="BBAS API",
        description="Bug Bounty Analysis System - REST API",
        version="1.0.0",
    )

    # CORS for local UI
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["http://127.0.0.1:9000", "http://localhost:9000", "*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.on_event("startup")
    async def startup():
        global worker_pool
        worker_config = WorkerConfig(
            max_concurrent=config.daemon.get("workers", 10),
            rate_limit=config.scanner.get("rate_limit", 10.0),
        )
        worker_pool = WorkerPool(
            num_workers=config.daemon.get("workers", 10),
            config=worker_config
        )
        worker_pool.start()
        try:
            n = _sync_fs_projects()
            if n: logger.info(f"Sincronizadas {n} carpetas desde {BUGBONTY_DIR}")
        except Exception as e:
            logger.warning(f"sync FS: {e}")
        logger.info("BBAS API started")

    @app.on_event("shutdown")
    async def shutdown():
        if worker_pool:
            worker_pool.stop()
        logger.info("BBAS API stopped")

    @app.get("/health")
    async def health():
        return {"status": "ok", "timestamp": datetime.now().isoformat()}

    @app.get("/api/stats")
    async def stats():
        pool_stats = worker_pool.get_stats() if worker_pool else {}
        return {
            "workers": pool_stats,
            "queue": work_unit_queue.get_stats() if work_unit_queue else {},
            "timestamp": datetime.now().isoformat()
        }

    # Projects
    @app.post("/api/projects", response_model=ProjectResponse)
    async def create_project(project: ProjectCreate):
        base_slug = re.sub(r"[^a-zA-Z0-9_-]+", "-", project.name.strip())[:50].strip("-") or "proyecto"
        project_id, n = base_slug, 0
        while db.fetchone("SELECT id FROM projects WHERE id=?", (project_id,)):
            n += 1
            project_id = f"{base_slug}-{n}"
        folder = str(_project_folder(project_id))
        p = Project(
            id=project_id,
            name=project.name,
            program_url=project.program_url,
            config_json=json.dumps(project.config),
        )
        with db.transaction() as conn:
            conn.execute(
                """INSERT INTO projects (id, name, program_url, folder, config_json)
                   VALUES (?, ?, ?, ?, ?)""",
                (p.id, p.name, p.program_url, folder, p.config_json)
            )
        scope_checker.invalidate_cache()
        return ProjectResponse(
            id=p.id, name=p.name, program_url=p.program_url,
            scope_file=p.scope_file, folder=folder, created_at=p.created_at,
            updated_at=p.updated_at, config=json.loads(p.config_json)
        )

    @app.get("/api/projects", response_model=List[ProjectResponse])
    async def list_projects():
        try:
            _sync_fs_projects()
        except Exception:
            pass
        rows = db.fetchall("SELECT * FROM projects ORDER BY created_at DESC")
        return [ProjectResponse(
            id=r["id"], name=r["name"], program_url=r["program_url"] or "",
            scope_file=r["scope_file"] or "", folder=r["folder"],
            created_at=r["created_at"],
            updated_at=r["updated_at"], config=json.loads(r["config_json"]) if r["config_json"] else {}
        ) for r in rows]

    @app.get("/api/projects/{project_id}", response_model=ProjectResponse)
    async def get_project(project_id: str):
        row = db.fetchone("SELECT * FROM projects WHERE id = ?", (project_id,))
        if not row:
            raise HTTPException(404, "Project not found")
        return ProjectResponse(
            id=row["id"], name=row["name"], program_url=row["program_url"] or "",
            scope_file=row["scope_file"] or "", folder=row["folder"],
            created_at=row["created_at"],
            updated_at=row["updated_at"], config=json.loads(row["config_json"]) if row["config_json"] else {}
        )

    @app.delete("/api/projects/{project_id}")
    async def delete_project(project_id: str):
        with db.transaction() as conn:
            conn.execute("DELETE FROM projects WHERE id = ?", (project_id,))
        scope_checker.invalidate_cache()
        return {"ok": True}

    # Scope Rules
    @app.post("/api/projects/{project_id}/scope", response_model=ScopeRuleResponse)
    async def add_scope_rule(project_id: str, rule: ScopeRuleCreate):
        with db.transaction() as conn:
            cursor = conn.execute(
                """INSERT INTO scope_rules (project_id, target, type, until, note, excluded)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (project_id, rule.target, rule.type, rule.until, rule.note, rule.excluded)
            )
            rule_id = cursor.lastrowid
        scope_checker.invalidate_cache()
        return ScopeRuleResponse(
            id=rule_id, project_id=project_id, target=rule.target,
            type=rule.type, since=datetime.now().isoformat(),
            until=rule.until, note=rule.note, excluded=rule.excluded
        )

    @app.get("/api/projects/{project_id}/scope", response_model=List[ScopeRuleResponse])
    async def list_scope_rules(project_id: str):
        rows = db.fetchall("SELECT * FROM scope_rules WHERE project_id = ? ORDER BY id", (project_id,))
        return [ScopeRuleResponse(
            id=r["id"], project_id=r["project_id"], target=r["target"],
            type=r["type"], since=r["since"], until=r["until"],
            note=r["note"], excluded=bool(r["excluded"])
        ) for r in rows]

    @app.delete("/api/projects/{project_id}/scope/{rule_id}")
    async def delete_scope_rule(project_id: str, rule_id: int):
        with db.transaction() as conn:
            conn.execute("DELETE FROM scope_rules WHERE id = ? AND project_id = ?", (rule_id, project_id))
        scope_checker.invalidate_cache()
        return {"ok": True}

    @app.get("/api/projects/{project_id}/scope/check")
    async def check_scope_endpoint(target: str, type: str = "recon"):
        authorized = check_scope(target, type, project_id)
        return {"target": target, "type": type, "authorized": authorized}

    # Sessions
    @app.post("/api/sessions", response_model=SessionResponse)
    async def create_session(session: SessionCreate):
        s = task_queue.create_session(session.project_id, session.name, session.config)
        return SessionResponse(**s.to_dict())

    @app.get("/api/sessions", response_model=List[SessionResponse])
    async def list_sessions(project_id: str = None):
        query = "SELECT * FROM sessions"
        params = []
        if project_id:
            query += " WHERE project_id = ?"
            params.append(project_id)
        query += " ORDER BY started_at DESC LIMIT 50"
        rows = db.fetchall(query, tuple(params))
        return [SessionResponse(
            id=r["id"], project_id=r["project_id"], name=r["name"],
            status=r["status"], started_at=r["started_at"], ended_at=r["ended_at"],
            config=json.loads(r["config_json"]), stats=json.loads(r["stats_json"])
        ) for r in rows]

    @app.get("/api/sessions/{session_id}", response_model=SessionResponse)
    async def get_session(session_id: int):
        s = task_queue.get_session(session_id)
        if not s:
            raise HTTPException(404, "Session not found")
        return SessionResponse(**s.to_dict())

    @app.post("/api/sessions/{session_id}/pause")
    async def pause_session(session_id: int):
        s = task_queue.get_session(session_id)
        if not s:
            raise HTTPException(404, "Session not found")
        s.status = "paused"
        task_queue.update_session(s)
        return {"ok": True}

    @app.post("/api/sessions/{session_id}/resume")
    async def resume_session(session_id: int):
        s = task_queue.get_session(session_id)
        if not s:
            raise HTTPException(404, "Session not found")
        s.status = "running"
        task_queue.update_session(s)
        return {"ok": True}

    # Scan Jobs
    @app.post("/api/sessions/{session_id}/jobs", response_model=ScanJobResponse)
    async def create_scan_job(session_id: int, job: ScanJobCreate):
        j = task_queue.create_scan_job(
            session_id, job.job_type, job.target_pattern,
            job.priority, job.total_targets
        )
        return ScanJobResponse(**j.to_dict())

    @app.get("/api/sessions/{session_id}/jobs", response_model=List[ScanJobResponse])
    async def list_scan_jobs(session_id: int):
        rows = db.fetchall("SELECT * FROM scan_jobs WHERE session_id = ? ORDER BY created_at", (session_id,))
        return [ScanJobResponse(**{
            "id": r["id"], "session_id": r["session_id"], "job_type": r["job_type"],
            "target_pattern": r["target_pattern"], "status": r["status"],
            "priority": r["priority"], "progress": r["progress"],
            "total_targets": r["total_targets"], "completed_targets": r["completed_targets"],
            "error_message": r["error_message"], "started_at": r["started_at"],
            "completed_at": r["completed_at"]
        }) for r in rows]

    @app.get("/api/jobs/{job_id}", response_model=ScanJobResponse)
    async def get_scan_job(job_id: int):
        j = task_queue.get_scan_job(job_id)
        if not j:
            raise HTTPException(404, "Job not found")
        return ScanJobResponse(**j.to_dict())

    @app.get("/api/jobs/{job_id}/workunits", response_model=List[WorkUnitResponse])
    async def list_work_units(job_id: int, status: str = None):
        query = "SELECT * FROM work_units WHERE scan_job_id = ?"
        params = [job_id]
        if status:
            query += " AND status = ?"
            params.append(status)
        query += " ORDER BY created_at"
        rows = db.fetchall(query, tuple(params))
        return [WorkUnitResponse(
            id=r["id"], scan_job_id=r["scan_job_id"], unit_type=r["unit_type"],
            target_host=r["target_host"], target_url=r["target_url"],
            status=r["status"], priority=r["priority"], attempts=r["attempts"],
            max_attempts=r["max_attempts"],
            result=json.loads(r["result_json"]) if r["result_json"] else {},
            error_message=r["error_message"]
        ) for r in rows]

    # Findings
    @app.post("/api/findings/filter", response_model=List[FindingResponse])
    async def filter_findings(filter: FindingFilter = Body(...)):
        query = "SELECT * FROM findings WHERE 1=1"
        params = []
        
        if filter.project_id:
            query += " AND project_id = ?"
            params.append(filter.project_id)
        if filter.min_severity:
            severity_order = {"critical": 5, "high": 4, "medium": 3, "low": 2, "info": 1}
            min_val = severity_order.get(filter.min_severity.lower(), 1)
            query += " AND CASE severity WHEN 'critical' THEN 5 WHEN 'high' THEN 4 WHEN 'medium' THEN 3 WHEN 'low' THEN 2 ELSE 1 END >= ?"
            params.append(min_val)
        if filter.tech:
            query += " AND tags LIKE ?"
            params.append(f"%{filter.tech}%")
        if filter.status:
            query += " AND status = ?"
            params.append(filter.status)
        
        query += " ORDER BY CASE severity WHEN 'critical' THEN 5 WHEN 'high' THEN 4 WHEN 'medium' THEN 3 WHEN 'low' THEN 2 ELSE 1 END DESC, created_at DESC"
        query += " LIMIT ? OFFSET ?"
        params.extend([filter.limit, filter.offset])
        
        rows = db.fetchall(query, tuple(params))
        return [FindingResponse(
            id=r["id"], project_id=r["project_id"], target_host=r["target_host"],
            type=r["type"], severity=r["severity"], cvss_score=r["cvss_score"],
            cwe_id=r["cwe_id"], cve_id=r["cve_id"], title=r["title"],
            description=r["description"], poc=r["poc"], tool=r["tool"],
            tags=json.loads(r["tags"]) if r["tags"] else [],
            status=r["status"], bounty_probability=r["bounty_probability"],
            exploit_difficulty=r["exploit_difficulty"]
        ) for r in rows]

    @app.get("/api/projects/{project_id}/findings", response_model=List[FindingResponse])
    async def list_findings(
        project_id: str,
        min_severity: str = None,
        tech: str = None,
        status: str = None,
        limit: int = 100,
        offset: int = 0
    ):
        filter = FindingFilter(
            project_id=project_id, min_severity=min_severity,
            tech=tech, status=status, limit=limit, offset=offset
        )
        return await filter_findings(filter)

    @app.get("/api/findings/{finding_id}", response_model=FindingResponse)
    async def get_finding(finding_id: int):
        row = db.fetchone("SELECT * FROM findings WHERE id = ?", (finding_id,))
        if not row:
            raise HTTPException(404, "Finding not found")
        return FindingResponse(
            id=row["id"], project_id=row["project_id"], target_host=row["target_host"],
            type=row["type"], severity=row["severity"], cvss_score=row["cvss_score"],
            cwe_id=row["cwe_id"], cve_id=row["cve_id"], title=row["title"],
            description=row["description"], poc=row["poc"], tool=row["tool"],
            tags=json.loads(row["tags"]) if row["tags"] else [],
            status=row["status"], bounty_probability=row["bounty_probability"],
            exploit_difficulty=row["exploit_difficulty"]
        )

    @app.post("/api/findings", response_model=FindingResponse)
    async def create_finding(finding: FindingCreate):
        with db.transaction() as conn:
            cursor = conn.execute(
                """INSERT INTO findings (project_id, target_id, target_host, type, severity,
                           cvss_score, cwe_id, cve_id, title, description, poc, evidence,
                           tool, tags, status, bounty_probability, exploit_difficulty)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (finding.project_id, finding.target_id or None, finding.target_host,
                 finding.type, finding.severity, finding.cvss_score, finding.cwe_id,
                 finding.cve_id, finding.title, finding.description, finding.poc, "{}",
                 finding.tool, json.dumps(finding.tags), finding.status,
                 finding.bounty_probability, finding.exploit_difficulty)
            )
            finding_id = cursor.lastrowid
        return FindingResponse(id=finding_id, **finding.model_dump())

    @app.patch("/api/findings/{finding_id}")
    async def update_finding(finding_id: int, updates: Dict[str, Any] = Body(...)):
        allowed = {"status", "bounty_probability", "exploit_difficulty", "notes"}
        set_clause = ", ".join(f"{k} = ?" for k in updates if k in allowed)
        if not set_clause:
            raise HTTPException(400, "No valid fields to update")
        values = [v for k, v in updates.items() if k in allowed]
        values.append(finding_id)
        with db.transaction() as conn:
            conn.execute(f"UPDATE findings SET {set_clause}, updated_at = ? WHERE id = ?",
                        values + [datetime.now().isoformat()])
        return {"ok": True}

    # Attack Paths
    @app.get("/api/projects/{project_id}/attack-paths", response_model=List[AttackPathResponse])
    async def list_attack_paths(project_id: str):
        rows = db.fetchall("SELECT * FROM attack_paths WHERE project_id = ? ORDER BY created_at DESC", (project_id,))
        return [AttackPathResponse(
            id=r["id"], project_id=r["project_id"], name=r["name"],
            description=r["description"], steps=json.loads(r["steps"]) if r["steps"] else [],
            findings_ids=json.loads(r["findings_ids"]) if r["findings_ids"] else [],
            severity=r["severity"], bounty_potential=r["bounty_potential"],
            status=r["status"]
        ) for r in rows]

    @app.post("/api/projects/{project_id}/attack-paths", response_model=AttackPathResponse)
    async def create_attack_path(project_id: str, path: AttackPathResponse):
        with db.transaction() as conn:
            cursor = conn.execute(
                """INSERT INTO attack_paths (project_id, name, description, steps,
                           findings_ids, severity, bounty_potential, status, notes)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (project_id, path.name, path.description, json.dumps(path.steps),
                 json.dumps(path.findings_ids), path.severity, path.bounty_potential,
                 path.status, path.notes)
            )
            path.id = cursor.lastrowid
        return path

    @app.patch("/api/attack-paths/{path_id}")
    async def update_attack_path(path_id: int, updates: Dict[str, Any] = Body(...)):
        allowed = {"status", "notes", "bounty_potential"}
        set_clause = ", ".join(f"{k} = ?" for k in updates if k in allowed)
        if not set_clause:
            raise HTTPException(400, "No valid fields to update")
        values = [v for k, v in updates.items() if k in allowed]
        values.append(path_id)
        with db.transaction() as conn:
            conn.execute(f"UPDATE attack_paths SET {set_clause}, updated_at = ? WHERE id = ?",
                        values + [datetime.now().isoformat()])
        return {"ok": True}

    # Targets
    @app.get("/api/projects/{project_id}/targets", response_model=List[TargetResponse])
    async def list_targets(project_id: str, limit: int = 100, offset: int = 0):
        rows = db.fetchall(
            "SELECT * FROM targets WHERE project_id = ? ORDER BY score DESC LIMIT ? OFFSET ?",
            (project_id, limit, offset)
        )
        return [TargetResponse(
            id=r["id"], project_id=r["project_id"], host=r["host"], url=r["url"],
            ip=r["ip"], status_code=r["status_code"], title=r["title"],
            server=r["server"], tech_stack=json.loads(r["tech_stack"]) if r["tech_stack"] else [],
            cdn=r["cdn"], locked_type=r["locked_type"], score=r["score"]
        ) for r in rows]

    @app.get("/api/targets/{target_id}", response_model=TargetResponse)
    async def get_target(target_id: int):
        row = db.fetchone("SELECT * FROM targets WHERE id = ?", (target_id,))
        if not row:
            raise HTTPException(404, "Target not found")
        return TargetResponse(
            id=row["id"], project_id=row["project_id"], host=row["host"], url=row["url"],
            ip=row["ip"], status_code=row["status_code"], title=row["title"],
            server=row["server"], tech_stack=json.loads(row["tech_stack"]) if row["tech_stack"] else [],
            cdn=row["cdn"], locked_type=row["locked_type"], score=row["score"]
        )

    # Quick Scan Endpoint (pipeline real por proyecto)
    @app.post("/api/scan")
    async def quick_scan(request: ScanRequest, background_tasks: BackgroundTasks):
        # 1. Proyecto obligatorio y existente
        proj = db.fetchone("SELECT * FROM projects WHERE id = ?", (request.project_id,))
        if not proj:
            raise HTTPException(404, f"Proyecto {request.project_id} no existe")

        # 2. Normalizar seeds (*.dom → dom) y validar contra scope del proyecto BBAS
        accepted, rejected = [], []
        for raw in request.targets:
            seed = normalize_seed(raw)
            if not seed:
                continue
            phase = "recon" if request.job_type == "enum" else request.job_type
            if check_scope(seed, phase, bbas_project=request.project_id):
                accepted.append((raw, seed))
            else:
                rejected.append(raw)
        if not accepted:
            raise HTTPException(400, detail_dict(rejected, "Ningún target está en el scope del proyecto"))

        # 3. Sesión + job con project_id real
        session = task_queue.create_session(request.project_id,
                                            f"{request.job_type}-{datetime.now().strftime('%H%M%S')}",
                                            {"deep": request.deep})
        job = task_queue.create_scan_job(session.id, request.job_type,
                                         ",".join(t for _, t in accepted),
                                         total_targets=len(accepted))
        if hasattr(job, "project_id"):
            job.project_id = request.project_id
        job.status = "running"
        job.started_at = datetime.now().isoformat()
        with db.transaction() as conn:
            conn.execute("UPDATE scan_jobs SET project_id=?, status='running', started_at=? WHERE id=?",
                         (request.project_id, job.started_at, job.id))

        # 4. Encolar subfinder por semilla (el pipeline encadena httpx/nuclei)
        work_units = []
        for raw, seed in accepted:
            work_units.append(WorkUnit(
                scan_job_id=job.id, project_id=request.project_id,
                unit_type="subfinder", target_host=seed,
                target_url=f"https://{seed}", priority=10,
                parameters={"seed_raw": raw, "deep": request.deep},
            ))
        work_unit_queue.enqueue_batch(work_units)

        resp = {
            "session_id": session.id,
            "job_id": job.id,
            "project_id": request.project_id,
            "seeds": [t for _, t in accepted],
            "work_units_queued": len(work_units),
        }
        if rejected:
            resp["rejected_out_of_scope"] = rejected
        return resp

    # Recon Triage (hunting mode)
    @app.post("/api/recon/triage")
    async def recon_triage(domains: List[str] = Body(..., embed=True), consent: bool = Body(False, embed=True)):
        if not domains:
            raise HTTPException(400, "No domains provided")
        
        import tempfile
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("\n".join(domains))
            domains_file = f.name
        
        try:
            cmd = ["/root/.config/opencode/tools/recon-triage.sh", "--domains", domains_file]
            if consent:
                cmd.append("--consent")
            
            import subprocess
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
            
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "report_dir": result.stdout.split("->")[-1].strip() if "->" in result.stdout else None
            }
        finally:
            os.unlink(domains_file)

    @app.get("/api/projects/{project_id}/report.pdf")
    async def export_report_pdf(project_id: str):
        from ..reporting.pdf_report import build_report
        proj = db.fetchone("SELECT * FROM projects WHERE id=?", (project_id,))
        if not proj:
            raise HTTPException(404, "Proyecto no existe")
        targets = [dict(r) for r in db.fetchall(
            "SELECT * FROM targets WHERE project_id=? ORDER BY score DESC", (project_id,))]
        for t in targets:
            try: t["tech_stack"] = json.loads(t.get("tech_stack") or "[]")
            except Exception: t["tech_stack"] = []
        findings = [dict(r) for r in db.fetchall(
            "SELECT * FROM findings WHERE project_id=?", (project_id,))]
        paths = [dict(r) for r in db.fetchall(
            "SELECT * FROM attack_paths WHERE project_id=?", (project_id,))]
        scope_in  = [dict(r) for r in db.fetchall(
            "SELECT target FROM scope_rules WHERE project_id=? AND excluded=0", (project_id,))]
        scope_out = [dict(r) for r in db.fetchall(
            "SELECT target FROM scope_rules WHERE project_id=? AND excluded=1", (project_id,))]

        pdf = build_report(dict(proj), targets, findings, paths, scope_in, scope_out)
        fname = f"informe_{proj['name'].replace(' ','_')}_{datetime.now().strftime('%Y%m%d')}.pdf"
        try:
            folder = proj["folder"] or ""
            if folder and Path(folder).exists():
                Path(folder, "reports").mkdir(parents=True, exist_ok=True)
                Path(folder, "reports", fname).write_bytes(pdf)
        except Exception as e:
            logger.warning(f"No pude guardar PDF en carpeta: {e}")
        return Response(content=pdf, media_type="application/pdf",
                        headers={"Content-Disposition": f'attachment; filename="{fname}"',
                                 "Cache-Control": "no-cache"})


    # ─── Terminal en vivo (SSE) ──────────────────────────────────
    @app.get("/api/sessions/{session_id}/stream")
    async def stream_session(session_id: int):
        async def gen():
            last_id = 0
            started = _time.time()
            dead_counter = 0
            yield f"event: open\ndata: {{\"session\": {session_id}}}\n\n"
            idle_beats = 0
            while True:
                if _time.time() - started > 1800:   # corte duro 30 min
                    yield 'event: end\ndata: {"reason":"timeout"}\n\n'
                    return
                rows = db.fetchall(
                    """SELECT wu.id, wu.unit_type, wu.target_host, wu.status,
                              wu.error_message, wu.result_json
                       FROM work_units wu JOIN scan_jobs j ON j.id = wu.scan_job_id
                       WHERE j.session_id = ? AND wu.id > ? AND wu.status IN ('completed','failed')
                       ORDER BY wu.id LIMIT 200""",
                    (session_id, last_id))
                sent = False
                for r in rows:
                    last_id = r["id"]
                    res = {}
                    try:
                        res = json.loads(r["result_json"] or "{}")
                    except Exception:
                        pass
                    tool, host, st = r["unit_type"], r["target_host"], r["status"]
                    ts = datetime.now().strftime("%H:%M:%S")
                    if st == "failed":
                        line = f"{ts}  {tool:<9} {host[:42]:<43} ✗ {(r['error_message'] or 'error')[:70]}"
                    elif tool == "subfinder":
                        n = len(res.get("data") or []) if isinstance(res.get("data"), list) else 0
                        line = f"{ts}  subfinder {host[:42]:<43} ✓ {n} subdominios"
                    elif tool == "httpx":
                        items = res.get("data") or []
                        it = items[0] if isinstance(items, list) and items else None
                        if it and it.get("status_code"):
                            t = (it.get("title") or "")[:34]
                            lk = it.get("locked_type")
                            extra = f" [{lk}]" if lk else ""
                            line = f"{ts}  httpx     {host[:42]:<43} {it.get('status_code')} {t}{extra}"
                        else:
                            dead_counter += 1
                            if dead_counter % 25 == 0:
                                dl = f"{ts}  httpx     ··· {dead_counter} hosts sin respuesta (descartados)"
                                yield f"event: log\ndata: {json.dumps({'line': dl}, ensure_ascii=False)}\n\n"
                            continue
                    elif tool == "nuclei":
                        n = len(res.get("data") or []) if isinstance(res.get("data"), list) else 0
                        line = f"{ts}  nuclei    {host[:42]:<43} {'⚠ '+str(n)+' hallazgos' if n else 'sin hallazgos'}"
                    else:
                        line = f"{ts}  {tool:<9} {host[:42]:<43} ok"
                    sent = True
                    yield f"event: log\ndata: {json.dumps({'line': line}, ensure_ascii=False)}\n\n"

                # stats globales de la sesión
                stats_rows = db.fetchall(
                    """SELECT wu.status, COUNT(*) c FROM work_units wu
                       JOIN scan_jobs j ON j.id = wu.scan_job_id
                       WHERE j.session_id = ? GROUP BY wu.status""",
                    (session_id,))
                st_map = {r["status"]: r["c"] for r in stats_rows}
                pend = st_map.get("pending", 0) + st_map.get("running", 0)
                proj_row = db.fetchone(
                    "SELECT project_id FROM sessions WHERE id=?", (session_id,))
                live = 0
                if proj_row and proj_row["project_id"]:
                    lr = db.fetchone(
                        "SELECT COUNT(*) c FROM targets WHERE project_id=? AND status_code>0",
                        (proj_row["project_id"],))
                    live = lr["c"] if lr else 0
                stats = {"pending": st_map.get("pending", 0), "running": st_map.get("running", 0),
                         "completed": st_map.get("completed", 0), "failed": st_map.get("failed", 0),
                         "live": live}
                yield f"event: stats\ndata: {json.dumps(stats)}\n\n"

                if pend == 0:
                    idle_beats += 1
                    if idle_beats >= 3:   # ~6-12 s seguidos sin cola → fin real
                        yield 'event: end\ndata: {"reason":"done"}\n\n'
                        return
                else:
                    idle_beats = 0
                await asyncio.sleep(1.5 if sent else 5)

        return StreamingResponse(gen(), media_type="text/event-stream",
                                 headers={"Cache-Control": "no-cache",
                                          "X-Accel-Buffering": "no"})





    # ─── Importador de programas bug bounty ──────────────────────
    class ImportAnalyzeRequest(BaseModel):
        url: str

    class ImportCommitRequest(BaseModel):
        program: str
        url: str = ""
        project_id: Optional[str] = None
        in_scope: List[str]
        out_scope: List[str] = []
        consent: bool = False
        launch_recon: bool = False
        deep: bool = False

    @app.post("/api/import/analyze")
    async def import_analyze(req: ImportAnalyzeRequest):
        result = analyze_program(req.url)
        if not result.get("ok"):
            raise HTTPException(502, result.get("error", "No se pudo analizar el programa"))
        return result

    @app.post("/api/import/commit")
    async def import_commit(req: ImportCommitRequest):
        if not req.consent:
            raise HTTPException(400, "Debes confirmar la autorización/legalidad del programa (consent)")
        if not req.in_scope and not req.out_scope:
            raise HTTPException(400, "No hay targets para importar")

        # 1) Resolver o crear proyecto
        if req.project_id:
            row = db.fetchone("SELECT id,name FROM projects WHERE id=?", (req.project_id,))
            if not row:
                raise HTTPException(404, "Proyecto no existe")
            pid, pname = row["id"], row["name"]
        else:
            base_slug = re.sub(r"[^a-z0-9-]+", "-", req.program.lower()).strip("-")[:40] or "programa"
            pid, pname = None, base_slug
            n = 0
            while db.fetchone("SELECT id FROM projects WHERE name=?", (pname,)):
                if pid is None:
                    row = db.fetchone("SELECT id FROM projects WHERE name=?", (pname,))
                    pid, pname = row["id"], row["name"]
                    break
                n += 1
                pname = f"{base_slug}-{n}"
            if pid is None:
                base_slug = re.sub(r"[^a-zA-Z0-9_-]+", "-", pname)[:50].strip("-") or "programa"
                pid, n2 = base_slug, 0
                while db.fetchone("SELECT id FROM projects WHERE id=?", (pid,)):
                    n2 += 1
                    pid = f"{base_slug}-{n2}"
                pname = pid
                _project_folder(pid)
                with db.transaction() as conn:
                    conn.execute("INSERT INTO projects (id,name,program_url,folder,config_json) VALUES (?,?,?,?,?)",
                                 (pid, req.program, req.url, str(BUGBONTY_DIR / pid), "{}"))

        def _audit(msg):
            try:
                subprocess.run(["bash", "/root/.config/opencode/tools/audit-log.sh", msg],
                               capture_output=True, timeout=10)
            except Exception:
                pass

        _audit(f"IMPORT programa [{pid}]: {req.url or req.program} in={len(req.in_scope)} out={len(req.out_scope)}")

        # 2) Espejo en ecosistema ECC (best-effort)
        try:
            subprocess.run(["bash", "/root/.config/opencode/tools/authorize.sh", "init",
                            req.url or req.program, "--project", pname],
                           capture_output=True, timeout=15)
        except Exception:
            pass

        added_in = added_out = 0
        with db.transaction() as conn:
            existing = {(r["target"], r["excluded"]) for r in conn.execute(
                "SELECT target, excluded FROM scope_rules WHERE project_id=?", (pid,))}
            for t in dict.fromkeys(x.strip().lower() for x in req.in_scope if x.strip()):
                if (t, 0) in existing:
                    continue
                conn.execute("""INSERT INTO scope_rules (project_id,target,type,note,excluded)
                                VALUES (?,?,'all','importado del programa',0)""", (pid, t))
                added_in += 1
            for t in dict.fromkeys(x.strip().lower() for x in req.out_scope if x.strip()):
                if (t, 1) in existing:
                    continue
                conn.execute("""INSERT INTO scope_rules (project_id,target,type,note,excluded)
                                VALUES (?,?,'all','fuera de alcance (OOS)',1)""", (pid, t))
                added_out += 1
        for t in list(dict.fromkeys(x.strip().lower() for x in req.in_scope if x.strip()))[:60]:
            try:
                subprocess.run(["bash", "/root/.config/opencode/tools/authorize.sh", "add", t, "all",
                                "--project", pname], capture_output=True, timeout=15)
            except Exception:
                pass
        scope_checker.invalidate_cache()

        resp = {"ok": True, "project_id": pid, "project_name": pname,
                "added_in": added_in, "added_out": added_out}

        # 3) Recon opcional (usa el mismo pipeline de /api/scan)
        if req.launch_recon:
            seeds = []
            rejected = []
            for raw in req.in_scope:
                seed = normalize_seed(raw)
                if seed and check_scope(seed, "recon", bbas_project=pid):
                    seeds.append(seed)
                else:
                    rejected.append(raw)
            session = task_queue.create_session(pid, f"import-recon-{datetime.now().strftime('%H%M%S')}",
                                                {"deep": req.deep})
            job = task_queue.create_scan_job(session.id, "recon", ",".join(seeds), total_targets=len(seeds))
            with db.transaction() as conn:
                conn.execute("UPDATE scan_jobs SET project_id=?, status='running', started_at=? WHERE id=?",
                             (pid, datetime.now().isoformat(), job.id))
            units = [WorkUnit(scan_job_id=job.id, project_id=pid, unit_type="subfinder",
                              target_host=seed, target_url=f"https://{seed}", priority=10,
                              parameters={"deep": req.deep}) for seed in dict.fromkeys(seeds)]
            work_unit_queue.enqueue_batch(units)
            resp["scan"] = {"session_id": session.id, "job_id": job.id,
                            "seeds": list(dict.fromkeys(seeds)),
                            "rejected_out_of_scope": rejected,
                            "work_units_queued": len(units)}
        return resp


    # ─── SPA / Web UI (servir frontend React) ────────────────────
    @app.get("/", include_in_schema=False)
    async def spa_index():
        idx = WEB_UI_DIR / "index.html"
        if idx.exists():
            return FileResponse(idx, headers={"Cache-Control": "no-cache, must-revalidate"})
        return HTMLResponse("<h1>BBAS</h1><p>Web UI no construida. Ejecuta: cd ~/.config/bbas/web-ui && npm run build</p>")

    @app.delete("/api/findings/{finding_id}")
    async def delete_finding(finding_id: int):
        with db.transaction() as conn:
            conn.execute("DELETE FROM findings WHERE id = ?", (finding_id,))
        return {"ok": True}

    @app.delete("/api/attack-paths/{path_id}")
    async def delete_attack_path(path_id: int):
        with db.transaction() as conn:
            conn.execute("DELETE FROM attack_paths WHERE id = ?", (path_id,))
        return {"ok": True}

    @app.delete("/api/sessions/{session_id}")
    async def delete_session(session_id: int):
        with db.transaction() as conn:
            conn.execute("DELETE FROM sessions WHERE id = ?", (session_id,))
        return {"ok": True}

    # Catch-all SPA: cualquier ruta no-API devuelve index.html
    @app.get("/{full_path:path}", include_in_schema=False)
    async def spa_fallback(full_path: str):
        if full_path.startswith("api/"):
            raise HTTPException(404, "Not found")
        candidate = WEB_UI_DIR / full_path
        if full_path and candidate.is_file():
            if "assets/" in full_path:
                # Assets con hash en el nombre: cache agresivo seguro
                return FileResponse(candidate, headers={"Cache-Control": "public, max-age=31536000, immutable"})
            return FileResponse(candidate, headers={"Cache-Control": "no-cache, must-revalidate"})
        idx = WEB_UI_DIR / "index.html"
        if idx.exists():
            return FileResponse(idx, headers={"Cache-Control": "no-cache, must-revalidate"})
        raise HTTPException(404, "Not found")

    return app


def _get_active_project() -> Optional[str]:
    return os.environ.get("CYBER_PROJECT")


# Create app instance
app = create_app()
