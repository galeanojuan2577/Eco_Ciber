"""BBAS Data Models (Dataclasses)"""
from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import Optional, List, Dict, Any
import json


@dataclass
class Project:
    id: str
    name: str
    program_url: str = ""
    scope_file: str = ""
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now().isoformat())
    config_json: str = "{}"

    @property
    def config(self) -> Dict[str, Any]:
        return json.loads(self.config_json) if self.config_json else {}

    @config.setter
    def config(self, value: Dict[str, Any]):
        self.config_json = json.dumps(value)

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d['config'] = self.config
        return d


@dataclass
class ScopeRule:
    id: Optional[int] = None
    project_id: str = ""
    target: str = ""
    type: str = "all"  # recon, scan, enumerate, exploit, post-exploit, dos, phishing, all
    since: str = field(default_factory=lambda: datetime.now().isoformat())
    until: Optional[str] = None
    note: str = ""
    excluded: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class Target:
    id: Optional[int] = None
    project_id: str = ""
    host: str = ""
    url: str = ""
    ip: str = ""
    status_code: int = 0
    title: str = ""
    server: str = ""
    tech_stack: List[str] = field(default_factory=list)
    cdn: str = ""
    locked_type: str = ""  # github-pages, cf-error, sso, shopify-password
    score: int = 0
    last_scanned: Optional[str] = None
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now().isoformat())

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["tech_stack"] = json.dumps(self.tech_stack)
        return d

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> "Target":
        return cls(
            id=row["id"],
            project_id=row["project_id"],
            host=row["host"],
            url=row["url"],
            ip=row["ip"],
            status_code=row["status_code"],
            title=row["title"],
            server=row["server"],
            tech_stack=json.loads(row["tech_stack"]) if row["tech_stack"] else [],
            cdn=row["cdn"],
            locked_type=row["locked_type"],
            score=row["score"],
            last_scanned=row["last_scanned"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )


@dataclass
class Finding:
    id: Optional[int] = None
    project_id: str = ""
    target_id: Optional[int] = None
    target_host: str = ""
    type: str = "info"  # vuln, exposure, misconfig, info, logic
    severity: str = "info"  # critical, high, medium, low, info
    cvss_score: Optional[float] = None
    cwe_id: str = ""
    cve_id: str = ""
    title: str = ""
    description: str = ""
    poc: str = ""
    evidence: str = ""
    tool: str = ""
    tags: List[str] = field(default_factory=list)
    status: str = "open"  # open, confirmed, false_positive, fixed, wont_fix
    bounty_probability: str = "unknown"  # high, medium, low, unknown
    exploit_difficulty: str = "medium"  # easy, medium, hard
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now().isoformat())
    closed_at: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["tags"] = json.dumps(self.tags)
        d["evidence"] = self.evidence
        return d

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> "Finding":
        return cls(
            id=row["id"],
            project_id=row["project_id"],
            target_id=row["target_id"],
            target_host=row["target_host"],
            type=row["type"],
            severity=row["severity"],
            cvss_score=row["cvss_score"],
            cwe_id=row["cwe_id"],
            cve_id=row["cve_id"],
            title=row["title"],
            description=row["description"],
            poc=row["poc"],
            evidence=row["evidence"],
            tool=row["tool"],
            tags=json.loads(row["tags"]) if row["tags"] else [],
            status=row["status"],
            bounty_probability=row["bounty_probability"],
            exploit_difficulty=row["exploit_difficulty"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
            closed_at=row["closed_at"],
        )


@dataclass
class AttackPath:
    id: Optional[int] = None
    project_id: str = ""
    name: str = ""
    description: str = ""
    steps: List[Dict[str, Any]] = field(default_factory=list)
    findings_ids: List[int] = field(default_factory=list)
    severity: str = "medium"
    bounty_potential: str = "medium"
    status: str = "theoretical"  # theoretical, testing, confirmed, exploited
    notes: str = ""
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = field(default_factory=lambda: datetime.now().isoformat())

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["steps"] = json.dumps(self.steps)
        d["findings_ids"] = json.dumps(self.findings_ids)
        return d

    @classmethod
    def from_row(cls, row: sqlite3.Row) -> "AttackPath":
        return cls(
            id=row["id"],
            project_id=row["project_id"],
            name=row["name"],
            description=row["description"],
            steps=json.loads(row["steps"]) if row["steps"] else [],
            findings_ids=json.loads(row["findings_ids"]) if row["findings_ids"] else [],
            severity=row["severity"],
            bounty_potential=row["bounty_potential"],
            status=row["status"],
            notes=row["notes"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )


@dataclass
class Session:
    id: Optional[int] = None
    project_id: str = ""
    name: str = ""
    status: str = "running"  # running, paused, completed, failed
    started_at: str = field(default_factory=lambda: datetime.now().isoformat())
    ended_at: Optional[str] = None
    config_json: str = "{}"
    stats_json: str = "{}"

    @property
    def config(self) -> Dict[str, Any]:
        return json.loads(self.config_json) if self.config_json else {}

    @property
    def stats(self) -> Dict[str, Any]:
        return json.loads(self.stats_json) if self.stats_json else {}

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class ScanJob:
    id: Optional[int] = None
    session_id: int = 0
    job_type: str = "recon"  # recon, scan, enum, triage
    target_pattern: str = ""
    status: str = "pending"  # pending, running, completed, failed, skipped
    priority: int = 0
    progress: int = 0
    total_targets: int = 0
    completed_targets: int = 0
    error_message: str = ""
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class WorkUnit:
    id: Optional[int] = None
    scan_job_id: int = 0
    project_id: str = ""
    unit_type: str = ""  # probe, nuclei, zap, nikto, gobuster, ffuf, enum, manual
    target_host: str = ""
    target_url: str = ""
    parameters: Dict[str, Any] = field(default_factory=dict)
    status: str = "pending"  # pending, running, completed, failed, skipped
    priority: int = 0
    attempts: int = 0
    max_attempts: int = 3
    result_json: str = ""
    error_message: str = ""
    worker_id: str = ""
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())

    @property
    def parameters_dict(self) -> Dict[str, Any]:
        return json.loads(self.parameters) if isinstance(self.parameters, str) else self.parameters

    @parameters_dict.setter
    def parameters_dict(self, value: Dict[str, Any]):
        self.parameters = json.dumps(value)

    @property
    def result(self) -> Dict[str, Any]:
        return json.loads(self.result_json) if self.result_json else {}

    @result.setter
    def result(self, value: Dict[str, Any]):
        self.result_json = json.dumps(value)

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["parameters"] = self.parameters if isinstance(self.parameters, str) else json.dumps(self.parameters)
        d["result_json"] = self.result_json
        return d


@dataclass
class ToolResult:
    id: Optional[int] = None
    work_unit_id: int = 0
    tool: str = ""
    command: str = ""
    stdout: str = ""
    stderr: str = ""
    exit_code: int = 0
    duration_ms: int = 0
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


# Import sqlite3 for type hints
import sqlite3