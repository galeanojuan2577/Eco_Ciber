"""BBAS Task Queue Implementation"""
import json
import os
import threading
import time
from datetime import datetime
from typing import Optional, List, Dict, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
import sqlite3

from ..models.database import Database
from ..models.models import WorkUnit, ScanJob, Session


class QueueBackend(Enum):
    SQLITE = "sqlite"
    REDIS = "redis"


@dataclass
class QueueConfig:
    backend: QueueBackend = QueueBackend.SQLITE
    sqlite_path: str = "~/.config/bbas/bbas.db"
    redis_url: str = "redis://localhost:6379/0"
    max_retries: int = 3
    retry_delay: int = 30
    checkpoint_interval: int = 50


class TaskQueue:
    """High-level task queue for scan jobs"""

    def __init__(self, config: QueueConfig = None):
        self.config = config or QueueConfig()
        self.db = Database(os.path.expanduser(self.config.sqlite_path))
        self._lock = threading.Lock()

    def create_session(self, project_id: str, name: str = "", config: Dict = None) -> Session:
        """Create a new scan session"""
        session = Session(
            project_id=project_id,
            name=name or f"session_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            config_json=json.dumps(config or {}),
        )
        with self.db.transaction() as conn:
            cursor = conn.execute(
                """INSERT INTO sessions (project_id, name, status, config_json, stats_json)
                   VALUES (?, ?, ?, ?, ?)""",
                (session.project_id, session.name, session.status, session.config_json, session.stats_json)
            )
            session.id = cursor.lastrowid
        return session

    def get_session(self, session_id: int) -> Optional[Session]:
        """Get session by ID"""
        row = self.db.fetchone("SELECT * FROM sessions WHERE id = ?", (session_id,))
        if row:
            return Session(
                id=row["id"],
                project_id=row["project_id"],
                name=row["name"],
                status=row["status"],
                started_at=row["started_at"],
                ended_at=row["ended_at"],
                config_json=row["config_json"],
                stats_json=row["stats_json"],
            )
        return None

    def update_session(self, session: Session):
        """Update session"""
        with self.db.transaction() as conn:
            conn.execute(
                """UPDATE sessions SET status = ?, ended_at = ?, stats_json = ?
                   WHERE id = ?""",
                (session.status, session.ended_at, session.stats_json, session.id)
            )

    def create_scan_job(self, session_id: int, job_type: str, target_pattern: str = "",
                        priority: int = 0, total_targets: int = 0) -> ScanJob:
        """Create a scan job within a session"""
        job = ScanJob(
            session_id=session_id,
            job_type=job_type,
            target_pattern=target_pattern,
            priority=priority,
            total_targets=total_targets,
        )
        with self.db.transaction() as conn:
            cursor = conn.execute(
                """INSERT INTO scan_jobs (session_id, job_type, target_pattern, status, priority, total_targets)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (job.session_id, job.job_type, job.target_pattern, job.status, job.priority, job.total_targets)
            )
            job.id = cursor.lastrowid
        return job

    def get_scan_job(self, job_id: int) -> Optional[ScanJob]:
        """Get scan job by ID"""
        row = self.db.fetchone("SELECT * FROM scan_jobs WHERE id = ?", (job_id,))
        if row:
            return ScanJob(
                id=row["id"],
                session_id=row["session_id"],
                job_type=row["job_type"],
                target_pattern=row["target_pattern"],
                status=row["status"],
                priority=row["priority"],
                progress=row["progress"],
                total_targets=row["total_targets"],
                completed_targets=row["completed_targets"],
                error_message=row["error_message"],
                started_at=row["started_at"],
                completed_at=row["completed_at"],
                created_at=row["created_at"],
            )
        return None

    def update_scan_job(self, job: ScanJob):
        """Update scan job"""
        with self.db.transaction() as conn:
            conn.execute(
                """UPDATE scan_jobs SET status = ?, progress = ?, completed_targets = ?,
                          error_message = ?, started_at = ?, completed_at = ?
                   WHERE id = ?""",
                (job.status, job.progress, job.completed_targets,
                 job.error_message, job.started_at, job.completed_at, job.id)
            )

    def get_pending_jobs(self, session_id: int = None, limit: int = 100) -> List[ScanJob]:
        """Get pending scan jobs ordered by priority"""
        query = "SELECT * FROM scan_jobs WHERE status = 'pending'"
        params = []
        if session_id:
            query += " AND session_id = ?"
            params.append(session_id)
        query += " ORDER BY priority DESC, created_at ASC LIMIT ?"
        params.append(limit)

        rows = self.db.fetchall(query, tuple(params))
        return [ScanJob(
            id=r["id"], session_id=r["session_id"], job_type=r["job_type"],
            target_pattern=r["target_pattern"], status=r["status"],
            priority=r["priority"], progress=r["progress"],
            total_targets=r["total_targets"], completed_targets=r["completed_targets"],
            error_message=r["error_message"], started_at=r["started_at"],
            completed_at=r["completed_at"], created_at=r["created_at"]
        ) for r in rows]

    def get_running_jobs(self) -> List[ScanJob]:
        """Get currently running scan jobs"""
        rows = self.db.fetchall("SELECT * FROM scan_jobs WHERE status = 'running'")
        return [ScanJob(
            id=r["id"], session_id=r["session_id"], job_type=r["job_type"],
            target_pattern=r["target_pattern"], status=r["status"],
            priority=r["priority"], progress=r["progress"],
            total_targets=r["total_targets"], completed_targets=r["completed_targets"],
            error_message=r["error_message"], started_at=r["started_at"],
            completed_at=r["completed_at"], created_at=r["created_at"]
        ) for r in rows]


class WorkUnitQueue:
    """Low-level work unit queue for workers"""

    def __init__(self, config: QueueConfig = None):
        self.config = config or QueueConfig()
        self.db = Database(os.path.expanduser(self.config.sqlite_path))
        self._lock = threading.Lock()

    def enqueue(self, work_unit: WorkUnit) -> int:
        """Add a work unit to the queue"""
        with self.db.transaction() as conn:
            cursor = conn.execute(
                """INSERT INTO work_units (scan_job_id, project_id, unit_type, target_host, target_url,
                          parameters, status, priority, max_attempts)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (work_unit.scan_job_id, getattr(work_unit, 'project_id', ''), work_unit.unit_type,
                 work_unit.target_host, work_unit.target_url,
                 json.dumps(work_unit.parameters) if work_unit.parameters else "{}",
                 work_unit.status, work_unit.priority, work_unit.max_attempts)
            )
            work_unit.id = cursor.lastrowid
        return work_unit.id

    def enqueue_batch(self, work_units: List[WorkUnit]) -> List[int]:
        """Add multiple work units efficiently"""
        ids = []
        with self.db.transaction() as conn:
            for wu in work_units:
                cursor = conn.execute(
                    """INSERT INTO work_units (scan_job_id, project_id, unit_type, target_host, target_url,
                              parameters, status, priority, max_attempts)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    (wu.scan_job_id, getattr(wu, 'project_id', ''), wu.unit_type, wu.target_host,
                     wu.target_url, json.dumps(wu.parameters) if wu.parameters else "{}",
                     wu.status, wu.priority, wu.max_attempts)
                )
                ids.append(cursor.lastrowid)
        return ids

    def dequeue(self, worker_id: str, unit_types: List[str] = None, limit: int = 10) -> List[WorkUnit]:
        """Get next work units for a worker"""
        with self._lock:
            placeholders = ",".join(["?"] * len(unit_types)) if unit_types else "1=1"
            type_clause = f"AND unit_type IN ({placeholders})" if unit_types else ""

            # Find and lock work units
            query = f"""
                SELECT * FROM work_units
                WHERE status = 'pending' {type_clause}
                ORDER BY priority DESC, created_at ASC
                LIMIT ?
            """
            params = list(unit_types) + [limit] if unit_types else [limit]

            rows = self.db.fetchall(query, tuple(params))
            work_units = []
            for row in rows:
                wu = WorkUnit(
                    id=row["id"], scan_job_id=row["scan_job_id"],
                    project_id=row["project_id"] or "",
                    unit_type=row["unit_type"],
                    target_host=row["target_host"], target_url=row["target_url"],
                    parameters=json.loads(row["parameters"]) if row["parameters"] else {},
                    status=row["status"], priority=row["priority"],
                    attempts=row["attempts"], max_attempts=row["max_attempts"],
                    result_json=row["result_json"], error_message=row["error_message"],
                    worker_id=row["worker_id"], started_at=row["started_at"],
                    completed_at=row["completed_at"], created_at=row["created_at"]
                )
                # Mark as running
                self.db.execute(
                    """UPDATE work_units SET status = 'running', worker_id = ?, started_at = ?
                       WHERE id = ?""",
                    (worker_id, datetime.now().isoformat(), wu.id)
                )
                work_units.append(wu)
            return work_units

    def complete(self, work_unit: WorkUnit, result: Dict = None, error: str = None):
        """Mark work unit as completed or failed"""
        status = "failed" if error else "completed"
        with self.db.transaction() as conn:
            conn.execute(
                """UPDATE work_units SET status = ?, result_json = ?, error_message = ?,
                          attempts = attempts + 1, completed_at = ?
                       WHERE id = ?""",
                (status, json.dumps(result) if result else None, error,
                 datetime.now().isoformat(), work_unit.id)
            )

            # Update scan job progress
            conn.execute(
                """UPDATE scan_jobs SET completed_targets = completed_targets + 1,
                          progress = CAST(completed_targets * 100.0 / total_targets AS INTEGER)
                       WHERE id = (SELECT scan_job_id FROM work_units WHERE id = ?)""",
                (work_unit.id,)
            )

    def requeue_failed(self, max_attempts: int = None) -> int:
        """Requeue failed work units that haven't exceeded max attempts"""
        max_att = max_attempts or self.config.max_retries
        with self.db.transaction() as conn:
            cursor = conn.execute(
                """UPDATE work_units SET status = 'pending', worker_id = '', error_message = ''
                   WHERE status = 'failed' AND attempts < ?""",
                (max_att,)
            )
            return cursor.rowcount

    def get_stale_work_units(self, stuck_minutes: int = 30) -> List[WorkUnit]:
        """Get work units stuck in 'running' state"""
        rows = self.db.fetchall(
            """SELECT * FROM work_units
               WHERE status = 'running'
               AND started_at < datetime('now', ?)""",
            (f"-{stuck_minutes} minutes",)
        )
        return [WorkUnit(
            id=r["id"], scan_job_id=r["scan_job_id"], unit_type=r["unit_type"],
            target_host=r["target_host"], target_url=r["target_url"],
            parameters=json.loads(r["parameters"]) if r["parameters"] else {},
            status=r["status"], priority=r["priority"],
            attempts=r["attempts"], max_attempts=r["max_attempts"],
            result_json=r["result_json"], error_message=r["error_message"],
            worker_id=r["worker_id"], started_at=r["started_at"],
            completed_at=r["completed_at"], created_at=r["created_at"]
        ) for r in rows]

    def recover_stale(self, stuck_minutes: int = 30) -> int:
        """Recover stale work units back to pending"""
        stale = self.get_stale_work_units(stuck_minutes)
        count = 0
        for wu in stale:
            with self.db.transaction() as conn:
                conn.execute(
                    """UPDATE work_units SET status = 'pending', worker_id = '',
                           attempts = attempts + 1
                       WHERE id = ?""",
                    (wu.id,)
                )
                count += 1
        return count

    def get_stats(self, scan_job_id: int = None) -> Dict[str, int]:
        """Get queue statistics"""
        where = "WHERE scan_job_id = ?" if scan_job_id else ""
        params = (scan_job_id,) if scan_job_id else ()

        rows = self.db.fetchall(
            f"""SELECT status, COUNT(*) as count FROM work_units {where}
                GROUP BY status""",
            params
        )
        return {row["status"]: row["count"] for row in rows}

    def save_tool_result(self, work_unit_id: int, tool: str, command: str,
                         stdout: str, stderr: str, exit_code: int, duration_ms: int):
        """Save raw tool output"""
        with self.db.transaction() as conn:
            conn.execute(
                """INSERT INTO tool_results (work_unit_id, tool, command, stdout, stderr, exit_code, duration_ms)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (work_unit_id, tool, command, stdout, stderr, exit_code, duration_ms)
            )