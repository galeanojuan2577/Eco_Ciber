"""BBAS SQLite Database Layer"""
import sqlite3
import json
import os
from pathlib import Path
from datetime import datetime
from contextlib import contextmanager
from typing import Optional, List, Dict, Any, Generator
import threading


class Database:
    """Thread-safe SQLite database wrapper"""

    _instance: Optional["Database"] = None
    _lock = threading.Lock()
    _write_lock = threading.Lock()

    def __new__(cls, db_path: str = None):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self, db_path: str = None):
        if self._initialized:
            return

        if db_path is None:
            db_path = os.path.expanduser("~/.config/bbas/bbas.db")

        self.db_path = db_path
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)

        self._local = threading.local()
        self._init_db()
        self._initialized = True

    def _get_conn(self) -> sqlite3.Connection:
        """Get thread-local connection"""
        if not hasattr(self._local, "conn") or self._local.conn is None:
            self._local.conn = sqlite3.connect(
                self.db_path,
                check_same_thread=False,
                timeout=30.0
            )
            self._local.conn.row_factory = sqlite3.Row
            self._local.conn.execute("PRAGMA foreign_keys = ON")
            self._local.conn.execute("PRAGMA journal_mode = WAL")
            self._local.conn.execute("PRAGMA synchronous = NORMAL")
            self._local.conn.execute("PRAGMA busy_timeout = 8000")
        return self._local.conn

    @contextmanager
    def transaction(self) -> Generator[sqlite3.Connection, None, None]:
        """Transacción serializada por proceso + busy_timeout de SQLite."""
        conn = self._get_conn()
        with Database._write_lock:
            self._local.in_txn = True
            try:
                yield conn
                conn.commit()
            except Exception:
                conn.rollback()
                raise
            finally:
                self._local.in_txn = False

    def execute(self, query: str, params: tuple = ()) -> sqlite3.Cursor:
        """Execute a query. DML fuera de transacción hace autocommit
        para nunca retener el lock de escritura."""
        conn = self._get_conn()
        cur = conn.execute(query, params)
        if not getattr(self._local, "in_txn", False):
            head = query.lstrip().split(" ", 1)[0].upper()
            if head in ("INSERT", "UPDATE", "DELETE", "REPLACE"):
                conn.commit()
        return cur

    def executemany(self, query: str, params_list: list) -> sqlite3.Cursor:
        """Execute many queries"""
        conn = self._get_conn()
        return conn.executemany(query, params_list)

    def fetchone(self, query: str, params: tuple = ()) -> Optional[sqlite3.Row]:
        """Fetch one row"""
        return self.execute(query, params).fetchone()

    def fetchall(self, query: str, params: tuple = ()) -> List[sqlite3.Row]:
        """Fetch all rows"""
        return self.execute(query, params).fetchall()

    def _init_db(self):
        """Initialize database schema"""
        schema = """
        -- Projects table
        CREATE TABLE IF NOT EXISTS projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            program_url TEXT,
            scope_file TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            config_json TEXT DEFAULT '{}'
        );

        -- Scope rules (from authorize.sh scope.json)
        CREATE TABLE IF NOT EXISTS scope_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id TEXT NOT NULL,
            target TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'all',
            since TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            until TIMESTAMP,
            note TEXT,
            excluded BOOLEAN DEFAULT FALSE,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_scope_project ON scope_rules(project_id);
        CREATE INDEX IF NOT EXISTS idx_scope_target ON scope_rules(target);

        -- Targets discovered
        CREATE TABLE IF NOT EXISTS targets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id TEXT NOT NULL,
            host TEXT NOT NULL,
            url TEXT,
            ip TEXT,
            status_code INTEGER,
            title TEXT,
            server TEXT,
            tech_stack TEXT,  -- JSON array
            cdn TEXT,
            locked_type TEXT,  -- github-pages, cf-error, sso, shopify-password
            score INTEGER DEFAULT 0,
            last_scanned TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_targets_project ON targets(project_id);
        CREATE INDEX IF NOT EXISTS idx_targets_host ON targets(host);
        CREATE INDEX IF NOT EXISTS idx_targets_score ON targets(score DESC);

        -- Findings (vulnerabilities, exposures, etc.)
        CREATE TABLE IF NOT EXISTS findings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id TEXT NOT NULL,
            target_id INTEGER,
            target_host TEXT NOT NULL,
            type TEXT NOT NULL,  -- vuln, exposure, misconfig, info, logic
            severity TEXT NOT NULL,  -- critical, high, medium, low, info
            cvss_score REAL,
            cwe_id TEXT,
            cve_id TEXT,
            title TEXT NOT NULL,
            description TEXT,
            poc TEXT,  -- sanitized
            evidence TEXT,  -- JSON
            tool TEXT,  -- nuclei, zap, nikto, manual, etc.
            tags TEXT,  -- JSON array
            status TEXT DEFAULT 'open',  -- open, confirmed, false_positive, fixed, wont_fix
            bounty_probability TEXT,  -- high, medium, low, unknown
            exploit_difficulty TEXT,  -- easy, medium, hard
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            closed_at TIMESTAMP,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
            FOREIGN KEY (target_id) REFERENCES targets(id) ON DELETE SET NULL
        );
        CREATE INDEX IF NOT EXISTS idx_findings_project ON findings(project_id);
        CREATE INDEX IF NOT EXISTS idx_findings_severity ON findings(severity);
        CREATE INDEX IF NOT EXISTS idx_findings_status ON findings(status);
        CREATE INDEX IF NOT EXISTS idx_findings_target ON findings(target_host);

        -- Attack paths (chains of findings)
        CREATE TABLE IF NOT EXISTS attack_paths (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id TEXT NOT NULL,
            name TEXT NOT NULL,
            description TEXT,
            steps TEXT NOT NULL,  -- JSON array of steps
            findings_ids TEXT,  -- JSON array of finding IDs
            severity TEXT NOT NULL,  -- critical, high, medium, low
            bounty_potential TEXT,  -- high, medium, low
            status TEXT DEFAULT 'theoretical',  -- theoretical, testing, confirmed, exploited
            notes TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_attack_paths_project ON attack_paths(project_id);
        CREATE INDEX IF NOT EXISTS idx_attack_paths_status ON attack_paths(status);

        -- Sessions (BBAS runs)
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id TEXT NOT NULL,
            name TEXT,
            status TEXT DEFAULT 'running',  -- running, paused, completed, failed
            started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            ended_at TIMESTAMP,
            config_json TEXT DEFAULT '{}',
            stats_json TEXT DEFAULT '{}',
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project_id);

        -- Scan jobs (high-level scan operations)
        CREATE TABLE IF NOT EXISTS scan_jobs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            job_type TEXT NOT NULL,  -- recon, scan, enum, triage
            target_pattern TEXT,
            status TEXT DEFAULT 'pending',  -- pending, running, completed, failed, skipped
            priority INTEGER DEFAULT 0,
            progress INTEGER DEFAULT 0,
            total_targets INTEGER DEFAULT 0,
            completed_targets INTEGER DEFAULT 0,
            error_message TEXT,
            started_at TIMESTAMP,
            completed_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_scan_jobs_session ON scan_jobs(session_id);
        CREATE INDEX IF NOT EXISTS idx_scan_jobs_status ON scan_jobs(status);

        -- Work units (atomic tasks for workers)
        CREATE TABLE IF NOT EXISTS work_units (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scan_job_id INTEGER NOT NULL,
            unit_type TEXT NOT NULL,  -- probe, nuclei, zap, nikto, gobuster, ffuf, enum, manual
            target_host TEXT NOT NULL,
            target_url TEXT,
            parameters TEXT,  -- JSON
            status TEXT DEFAULT 'pending',  -- pending, running, completed, failed, skipped
            priority INTEGER DEFAULT 0,
            attempts INTEGER DEFAULT 0,
            max_attempts INTEGER DEFAULT 3,
            result_json TEXT,  -- JSON result
            error_message TEXT,
            worker_id TEXT,
            started_at TIMESTAMP,
            completed_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (scan_job_id) REFERENCES scan_jobs(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_work_units_job ON work_units(scan_job_id);
        CREATE INDEX IF NOT EXISTS idx_work_units_status ON work_units(status);
        CREATE INDEX IF NOT EXISTS idx_work_units_target ON work_units(target_host);

        -- Tool results (raw output from tools)
        CREATE TABLE IF NOT EXISTS tool_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            work_unit_id INTEGER NOT NULL,
            tool TEXT NOT NULL,
            command TEXT,
            stdout TEXT,
            stderr TEXT,
            exit_code INTEGER,
            duration_ms INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (work_unit_id) REFERENCES work_units(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_tool_results_work_unit ON tool_results(work_unit_id);

        -- Configuration / key-value store
        CREATE TABLE IF NOT EXISTS config (
            key TEXT PRIMARY KEY,
            value TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- Audit log (mirror of audit-log.sh)
        CREATE TABLE IF NOT EXISTS audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id TEXT,
            action TEXT NOT NULL,
            target TEXT,
            tool TEXT,
            phase TEXT,
            details TEXT,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_audit_project ON audit_log(project_id);
        CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp);
        """
        with self.transaction() as conn:
            conn.executescript(schema)
            self._migrate(conn)

    @staticmethod
    def _migrate(conn):
        """Migraciones idempotentes (no destruyen datos existentes)."""
        # F1: project_id en work_units y scan_jobs
        for table in ("work_units", "scan_jobs"):
            cols = {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}
            if "project_id" not in cols:
                conn.execute(f"ALTER TABLE {table} ADD COLUMN project_id TEXT")
        # F6: carpeta física por proyecto
        cols_p = {r[1] for r in conn.execute("PRAGMA table_info(projects)")}
        if "folder" not in cols_p:
            conn.execute("ALTER TABLE projects ADD COLUMN folder TEXT")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_wu_project ON work_units(project_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_job_project ON scan_jobs(project_id)")

    def close(self):
        """Close thread-local connection"""
        if hasattr(self._local, "conn") and self._local.conn:
            self._local.conn.close()
            self._local.conn = None

    @classmethod
    def reset_instance(cls):
        """Reset singleton (for testing)"""
        if cls._instance:
            cls._instance.close()
        cls._instance = None


def init_db(db_path: str = None) -> Database:
    """Initialize and return database instance"""
    return Database(db_path)