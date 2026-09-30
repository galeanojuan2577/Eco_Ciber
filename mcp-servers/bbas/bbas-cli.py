#!/usr/bin/env python3
"""BBAS CLI Entry Point"""
import sys
import os
import json
import argparse
from pathlib import Path
from datetime import datetime

# Add core to path
sys.path.insert(0, str(Path(__file__).parent))

from core.models.database import init_db
from core.models.models import Project, ScopeRule, Finding, AttackPath, WorkUnit
from core.queue.queue import TaskQueue, WorkUnitQueue, QueueConfig
from core.workers import WorkerPool, WorkerConfig
from core.scanners import (
    SubfinderScanner, HttpxScanner, NucleiScanner,
    ZAPScanner, NiktoScanner, GobusterScanner,
    AmassScanner, NmapScanner
)
from core.utils.config import load_config
from core.utils.scope import check_scope, load_scope, ScopeChecker
from core.utils.logger import setup_logging, get_logger


logger = get_logger(__name__)


def main():
    parser = argparse.ArgumentParser(description="BBAS CLI - Bug Bounty Analysis System")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Global options
    parser.add_argument("--config", help="Config file path")
    parser.add_argument("--project", help="Project ID")
    parser.add_argument("--log-level", default="INFO", help="Log level")

    # Project commands
    proj_parser = subparsers.add_parser("project", help="Project management")
    proj_sub = proj_parser.add_subparsers(dest="project_cmd")
    
    proj_create = proj_sub.add_parser("create", help="Create project")
    proj_create.add_argument("name")
    proj_create.add_argument("--program-url", default="")
    
    proj_list = proj_sub.add_parser("list", help="List projects")
    
    proj_show = proj_sub.add_parser("show", help="Show project")
    proj_show.add_argument("project_id")

    # Scope commands
    scope_parser = subparsers.add_parser("scope", help="Scope management")
    scope_sub = scope_parser.add_subparsers(dest="scope_cmd")
    
    scope_add = scope_sub.add_parser("add", help="Add scope rule")
    scope_add.add_argument("target")
    scope_add.add_argument("--type", default="all")
    scope_add.add_argument("--until")
    scope_add.add_argument("--note", default="")
    scope_add.add_argument("--excluded", action="store_true")
    
    scope_list = scope_sub.add_parser("list", help="List scope rules")
    
    scope_check = scope_sub.add_parser("check", help="Check if target in scope")
    scope_check.add_argument("target")
    scope_check.add_argument("--type", default="recon")

    # Scan commands
    scan_parser = subparsers.add_parser("scan", help="Run scans")
    scan_sub = scan_parser.add_subparsers(dest="scan_cmd")
    
    scan_recon = scan_sub.add_parser("recon", help="Run reconnaissance")
    scan_recon.add_argument("targets", nargs="+")
    scan_recon.add_argument("--deep", action="store_true")
    
    scan_vuln = scan_sub.add_parser("vuln", help="Run vulnerability scan")
    scan_vuln.add_argument("targets", nargs="+")
    scan_vuln.add_argument("--severity", default="critical,high,medium")
    
    scan_enum = scan_sub.add_parser("enum", help="Run enumeration")
    scan_enum.add_argument("targets", nargs="+")

    # Findings commands
    find_parser = subparsers.add_parser("findings", help="Manage findings")
    find_sub = find_parser.add_subparsers(dest="find_cmd")
    
    find_list = find_sub.add_parser("list", help="List findings")
    find_list.add_argument("--min-severity")
    find_list.add_argument("--tech")
    find_list.add_argument("--status")
    find_list.add_argument("--limit", type=int, default=50)
    
    find_add = find_sub.add_parser("add", help="Add manual finding")
    find_add.add_argument("--target")
    find_add.add_argument("--type", default="vuln")
    find_add.add_argument("--severity", default="medium")
    find_add.add_argument("--title")
    find_add.add_argument("--description")
    find_add.add_argument("--poc")
    find_add.add_argument("--tool", default="manual")
    find_add.add_argument("--tags", default="")

    # Attack paths
    path_parser = subparsers.add_parser("paths", help="Attack paths")
    path_sub = path_parser.add_subparsers(dest="path_cmd")
    
    path_list = path_sub.add_parser("list", help="List attack paths")
    path_list.add_argument("--status")
    
    path_create = path_sub.add_parser("create", help="Create attack path")
    path_create.add_argument("--name")
    path_create.add_argument("--description")
    path_create.add_argument("--steps", help="JSON array of steps")
    path_create.add_argument("--findings", help="JSON array of finding IDs")
    path_create.add_argument("--severity", default="medium")
    path_create.add_argument("--bounty-potential", default="medium")

    # Session commands
    session_parser = subparsers.add_parser("session", help="Session management")
    session_sub = session_parser.add_subparsers(dest="session_cmd")
    
    session_list = session_sub.add_parser("list", help="List sessions")
    session_list.add_argument("--project")
    
    session_show = session_sub.add_parser("show", help="Show session")
    session_show.add_argument("session_id", type=int)

    # Worker commands
    worker_parser = subparsers.add_parser("worker", help="Worker management")
    worker_sub = worker_parser.add_subparsers(dest="worker_cmd")
    
    worker_start = worker_sub.add_parser("start", help="Start worker pool")
    worker_start.add_argument("--workers", type=int, default=4)
    worker_start.add_argument("--types", help="Comma-separated unit types")

    # Daemon commands
    daemon_parser = subparsers.add_parser("daemon", help="Daemon management")
    daemon_sub = daemon_parser.add_subparsers(dest="daemon_cmd")
    
    daemon_start = daemon_sub.add_parser("start", help="Start daemon in background")
    daemon_start.add_argument("--host", default="127.0.0.1")
    daemon_start.add_argument("--port", type=int, default=9000)
    daemon_start.add_argument("--log-file", default="/tmp/bbas-daemon.log")
    daemon_start.add_argument("--pid-file", default="/tmp/bbas-daemon.pid")
    
    daemon_stop = daemon_sub.add_parser("stop", help="Stop background daemon")
    daemon_stop.add_argument("--pid-file", default="/tmp/bbas-daemon.pid")
    daemon_stop.add_argument("--port", type=int, default=9000)
    
    daemon_status = daemon_sub.add_parser("status", help="Check daemon status")
    daemon_status.add_argument("--pid-file", default="/tmp/bbas-daemon.pid")
    daemon_status.add_argument("--port", type=int, default=9000)
    
    daemon_logs = daemon_sub.add_parser("logs", help="Show daemon logs")
    daemon_logs.add_argument("--log-file", default="/tmp/bbas-daemon.log")
    daemon_logs.add_argument("-f", "--follow", action="store_true", help="Follow log output")
    daemon_logs.add_argument("-n", "--lines", type=int, default=100, help="Number of lines to show")
    daemon_logs.add_argument("--port", type=int, default=9000)
    
    # Triage command
    triage_parser = subparsers.add_parser("triage", help="Run recon triage")
    triage_parser.add_argument("domains", nargs="+")
    triage_parser.add_argument("--consent", action="store_true")
    triage_parser.add_argument("--project")
    triage_parser.add_argument("--topN", type=int, default=5)
    triage_parser.add_argument("--cap", type=int, default=50)

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    # Setup logging
    setup_logging(args.log_level)

    # Load config
    config = load_config(args.config)

    # Initialize DB
    db = init_db()

    # Get project
    project_id = args.project or os.environ.get("CYBER_PROJECT")
    if not project_id and args.command in ["scope", "scan", "findings", "paths", "session"]:
        # Try to get from session
        from core.utils.scope import _get_active_project
        project_id = _get_active_project()
    
    if not project_id and args.command in ["scope", "scan", "findings", "paths"]:
        print("Error: No project specified. Use --project or set CYBER_PROJECT env var.")
        return 1

    # Execute commands
    try:
        if args.command == "project":
            return handle_project(args, db)
        elif args.command == "scope":
            return handle_scope(args, db, project_id)
        elif args.command == "scan":
            return handle_scan(args, db, project_id, config)
        elif args.command == "findings":
            return handle_findings(args, db, project_id)
        elif args.command == "paths":
            return handle_paths(args, db, project_id)
        elif args.command == "session":
            return handle_session(args, db, project_id)
        elif args.command == "worker":
            return handle_worker(args, config)
        elif args.command == "daemon":
            return handle_daemon(args)
        elif args.command == "triage":
            return handle_triage(args)
    except Exception as e:
        logger.error(f"Error: {e}")
        return 1

    return 0


def handle_project(args, db):
    if args.project_cmd == "create":
        project_id = f"proj-{os.urandom(6).hex()}"
        p = Project(id=project_id, name=args.name, program_url=args.program_url)
        with db.transaction() as conn:
            conn.execute(
                "INSERT INTO projects (id, name, program_url, config_json) VALUES (?, ?, ?, ?)",
                (p.id, p.name, p.program_url, "{}")
            )
        print(f"Created project: {project_id}")
        return 0
    elif args.project_cmd == "list":
        rows = db.fetchall("SELECT * FROM projects ORDER BY created_at DESC")
        for r in rows:
            print(f"  {r['id']} | {r['name']} | {r['program_url']} | {r['created_at']}")
        return 0
    elif args.project_cmd == "show":
        row = db.fetchone("SELECT * FROM projects WHERE id = ?", (args.project_id,))
        if not row:
            print("Project not found")
            return 1
        print(json.dumps(dict(row), indent=2))
        return 0
    return 1


def handle_scope(args, db, project_id):
    if args.scope_cmd == "add":
        with db.transaction() as conn:
            cursor = conn.execute(
                """INSERT INTO scope_rules (project_id, target, type, until, note, excluded)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (project_id, args.target, args.type, args.until, args.note, args.excluded)
            )
        print(f"Added scope rule: {args.target} (type={args.type})")
        return 0
    elif args.scope_cmd == "list":
        rows = db.fetchall("SELECT * FROM scope_rules WHERE project_id = ? ORDER BY id", (project_id,))
        for r in rows:
            excl = " [EXCLUDED]" if r["excluded"] else ""
            print(f"  {r['id']} | {r['target']} | {r['type']} | {r['since']} | {r['until'] or '∞'}{excl}")
        return 0
    elif args.scope_cmd == "check":
        authorized = check_scope(args.target, args.type, project_id)
        print(f"Target: {args.target} | Type: {args.type} | Authorized: {authorized}")
        return 0
    return 1


def handle_scan(args, db, project_id, config):
    if args.scan_cmd == "recon":
        # Create session
        task_queue = TaskQueue(QueueConfig())
        session = task_queue.create_session(project_id, f"recon-{datetime.now().strftime('%H%M%S')}")
        
        # Create job
        job = task_queue.create_scan_job(session.id, "recon", ",".join(args.targets), total_targets=len(args.targets))
        job.status = "running"
        job.started_at = datetime.now().isoformat()
        task_queue.update_scan_job(job)
        with db.transaction() as conn:
            conn.execute("UPDATE scan_jobs SET project_id=? WHERE id=?", (project_id, job.id))

        # Enqueue work units
        work_unit_queue = WorkUnitQueue(QueueConfig())
        work_units = []
        for target in args.targets:
            # subfinder
            wu1 = WorkUnit(
                scan_job_id=job.id, project_id=project_id, unit_type="subfinder", target_host=target,
                target_url=f"https://{target}", priority=10, parameters={"deep": bool(args.deep)}
            )
            # httpx
            wu2 = WorkUnit(
                scan_job_id=job.id, project_id=project_id, unit_type="httpx", target_host=target,
                target_url=f"https://{target}", priority=5, parameters={}
            )
            work_units.extend([wu1, wu2])
            if args.deep:
                wu3 = WorkUnit(
                    scan_job_id=job.id, project_id=project_id, unit_type="nuclei", target_host=target,
                    target_url=f"https://{target}", priority=1, parameters={}
                )
                work_units.append(wu3)
        
        work_unit_queue.enqueue_batch(work_units)
        
        print(f"Session: {session.id}")
        print(f"Job: {job.id}")
        print(f"Queued {len(work_units)} work units")
        return 0
    elif args.scan_cmd == "vuln":
        # Similar but just nuclei
        task_queue = TaskQueue(QueueConfig())
        session = task_queue.create_session(project_id, f"vuln-{datetime.now().strftime('%H%M%S')}")
        job = task_queue.create_scan_job(session.id, "scan", ",".join(args.targets), total_targets=len(args.targets))
        job.status = "running"
        job.started_at = datetime.now().isoformat()
        task_queue.update_scan_job(job)

        work_unit_queue = WorkUnitQueue(QueueConfig())
        work_units = []
        severity = args.severity.split(",")
        for target in args.targets:
            work_units.append({
                "scan_job_id": job.id, "unit_type": "nuclei", "target_host": target,
                "target_url": f"https://{target}", "priority": 10,
                "parameters": {"severity": severity}
            })
        work_unit_queue.enqueue_batch([type('WorkUnit', (), w)() for w in work_units])
        
        print(f"Session: {session.id}")
        print(f"Job: {job.id}")
        print(f"Queued {len(work_units)} nuclei scans")
        return 0
    return 1


def handle_findings(args, db, project_id):
    if args.find_cmd == "list":
        query = "SELECT * FROM findings WHERE project_id = ?"
        params = [project_id]
        
        if args.min_severity:
            severity_order = {"critical": 5, "high": 4, "medium": 3, "low": 2, "info": 1}
            min_val = severity_order.get(args.min_severity.lower(), 1)
            query += " AND CASE severity WHEN 'critical' THEN 5 WHEN 'high' THEN 4 WHEN 'medium' THEN 3 WHEN 'low' THEN 2 ELSE 1 END >= ?"
            params.append(min_val)
        if args.tech:
            query += " AND tags LIKE ?"
            params.append(f"%{args.tech}%")
        if args.status:
            query += " AND status = ?"
            params.append(args.status)
        
        query += " ORDER BY CASE severity WHEN 'critical' THEN 5 WHEN 'high' THEN 4 WHEN 'medium' THEN 3 WHEN 'low' THEN 2 ELSE 1 END DESC LIMIT ?"
        params.append(args.limit)
        
        rows = db.fetchall(query, tuple(params))
        for r in rows:
            tags = json.loads(r["tags"]) if r["tags"] else []
            print(f"  [{r['severity'].upper()}] {r['title']} @ {r['target_host']} ({r['tool']}) {tags}")
        return 0
    elif args.find_cmd == "add":
        tags = [t.strip() for t in args.tags.split(",")] if args.tags else []
        with db.transaction() as conn:
            cursor = conn.execute(
                """INSERT INTO findings (project_id, target_host, type, severity, title, description, poc, tool, tags, status)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (project_id, args.target, args.type, args.severity, args.title,
                 args.description, args.poc, args.tool, json.dumps(tags), "open")
            )
        print(f"Added finding #{cursor.lastrowid}")
        return 0
    return 1


def handle_paths(args, db, project_id):
    if args.path_cmd == "list":
        query = "SELECT * FROM attack_paths WHERE project_id = ?"
        params = [project_id]
        if args.status:
            query += " AND status = ?"
            params.append(args.status)
        query += " ORDER BY created_at DESC"
        
        rows = db.fetchall(query, tuple(params))
        for r in rows:
            steps = json.loads(r["steps"]) if r["steps"] else []
            print(f"  {r['id']} | {r['name']} | {r['severity']} | {r['status']} | {len(steps)} steps")
        return 0
    elif args.path_cmd == "create":
        steps = json.loads(args.steps) if args.steps else []
        findings_ids = json.loads(args.findings) if args.findings else []
        with db.transaction() as conn:
            cursor = conn.execute(
                """INSERT INTO attack_paths (project_id, name, description, steps, findings_ids, severity, bounty_potential, status)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (project_id, args.name, args.description, json.dumps(steps),
                 json.dumps(findings_ids), args.severity, args.bounty_potential, "theoretical")
            )
        print(f"Created attack path #{cursor.lastrowid}")
        return 0
    return 1


def handle_session(args, db, project_id):
    if args.session_cmd == "list":
        query = "SELECT * FROM sessions WHERE project_id = ? ORDER BY started_at DESC LIMIT 20"
        rows = db.fetchall(query, (project_id,))
        for r in rows:
            stats = json.loads(r["stats_json"]) if r["stats_json"] else {}
            print(f"  {r['id']} | {r['name']} | {r['status']} | {r['started_at']} | {stats}")
        return 0
    elif args.session_cmd == "show":
        row = db.fetchone("SELECT * FROM sessions WHERE id = ?", (args.session_id,))
        if not row:
            print("Session not found")
            return 1
        print(json.dumps(dict(row), indent=2))
        return 0
    return 1


def handle_worker(args, config):
    if args.worker_cmd == "start":
        worker_config = WorkerConfig(
            max_concurrent=1,
            rate_limit=config.scanner.get("rate_limit", 10.0),
        )
        if args.types:
            worker_config.unit_types = args.types.split(",")
        
        pool = WorkerPool(num_workers=args.workers, config=worker_config)
        pool.start()
        print(f"Started {args.workers} workers")
        
        # Keep running
        import time
        try:
            while True:
                time.sleep(10)
                stats = pool.get_stats()
                print(f"Stats: {stats}")
        except KeyboardInterrupt:
            pool.stop()
            print("Stopped")
        return 0


def handle_daemon(args):
    """Handle daemon management commands"""
    import subprocess
    import time
    import signal
    
    pid_file = getattr(args, 'pid_file', '/tmp/bbas-daemon.pid')
    log_file = getattr(args, 'log_file', '/tmp/bbas-daemon.log')
    
    def is_running(pid):
        """Check if process with PID is running"""
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False
    
    def read_pid():
        """Read PID from file"""
        try:
            with open(pid_file, 'r') as f:
                return int(f.read().strip())
        except (FileNotFoundError, ValueError):
            return None
    
    if args.daemon_cmd == "start":
        # Check if already running
        pid = read_pid()
        if pid and is_running(pid):
            print(f"Daemon already running with PID {pid}")
            return 0
        
        port = getattr(args, 'port', 9000)
        log_file = getattr(args, 'log_file', '/tmp/bbas-daemon.log')
        pid_file = getattr(args, 'pid_file', '/tmp/bbas-daemon.pid')
        
        with open(log_file, 'a') as log_f:
            proc = subprocess.Popen(
                [sys.executable, "bbas-daemon.py", "--port", str(getattr(args, 'port', 9000))],
                stdout=open(log_file, 'a'),
                stderr=subprocess.STDOUT,
                start_new_session=True,
                cwd="/root/.config/bbas"
            )
        
        with open(pid_file, 'w') as f:
            f.write(str(proc.pid))
        
        print(f"Daemon started with PID {proc.pid}")
        print(f"Log file: {log_file}")
        print(f"PID file: {pid_file}")
        
        print("Waiting for daemon to be ready...", end="", flush=True)
        for i in range(30):
            try:
                import urllib.request
                urllib.request.urlopen(f"http://127.0.0.1:{getattr(args, 'port', 9000)}/health", timeout=2)
                print(" Ready!")
                return 0
            except:
                print(".", end="", flush=True)
                time.sleep(1)
        print(" Timeout!")
        return 1
    
    elif args.daemon_cmd == "stop":
        pid = read_pid()
        if not pid:
            print("No PID file found. Daemon may not be running.")
            return 1
        
        if is_running(pid):
            os.kill(pid, signal.SIGTERM)
            print(f"Sent SIGTERM to PID {pid}")
            
            for _ in range(10):
                if not is_running(pid):
                    break
                time.sleep(1)
            
            if is_running(pid):
                os.kill(pid, signal.SIGKILL)
                print(f"Force killed PID {pid}")
            
            try:
                os.unlink(pid_file)
            except:
                pass
            print("Daemon stopped")
        else:
            print(f"Process {pid} not running")
            try:
                os.unlink(pid_file)
            except:
                pass
        return 0
    
    elif args.daemon_cmd == "status":
        pid = read_pid()
        port = getattr(args, 'port', 9000)
        if pid and is_running(pid):
            print(f"Daemon is RUNNING (PID: {pid})")
            try:
                import urllib.request
                import json
                resp = urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=2)
                data = json.load(resp)
                print(f"Health: {data}")
            except:
                print("Health check: FAILED (daemon not responding)")
        else:
            print("Daemon is STOPPED")
        return 0
    
    elif args.daemon_cmd == "logs":
        log_file = getattr(args, 'log_file', '/tmp/bbas-daemon.log')
        follow = getattr(args, 'follow', False)
        lines = getattr(args, 'lines', 100)
        
        if not os.path.exists(log_file):
            print(f"Log file not found: {log_file}")
            return 1
        
        if follow:
            subprocess.run(["tail", "-f", "-n", str(lines), log_file])
        else:
            with open(log_file, 'r') as f:
                all_lines = f.readlines()
                for line in all_lines[-lines:]:
                    print(line.rstrip())
        return 0
    
    return 1


def handle_triage(args):
    import subprocess
    import tempfile
    
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
        f.write("\n".join(args.domains))
        domains_file = f.name
    
    try:
        cmd = ["/root/.config/opencode/tools/recon-triage.sh", "--domains", domains_file]
        if args.consent:
            cmd.append("--consent")
        if args.project:
            cmd.extend(["--project", args.project])
        if args.topN:
            cmd.extend(["--topN", str(args.topN)])
        if args.cap:
            cmd.extend(["--cap", str(args.cap)])
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
        print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        return result.returncode
    finally:
        os.unlink(domains_file)


if __name__ == "__main__":
    sys.exit(main())