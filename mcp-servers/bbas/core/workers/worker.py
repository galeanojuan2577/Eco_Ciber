"""Base Worker Classes"""
import threading
import time
import uuid
import signal
import sys
from typing import Dict, Any, List, Optional, Callable
from dataclasses import dataclass, field
from datetime import datetime

from ..queue.queue import WorkUnitQueue
from ..models.database import Database
from ..models.models import WorkUnit, ScanJob
from ..scanners import (
    SubfinderScanner, HttpxScanner, NucleiScanner,
    ZAPScanner, NiktoScanner, GobusterScanner,
    AmassScanner, NmapScanner
)
from ..utils.scope import check_scope
from ..pipeline import ingest_unit_result, classify_target, sanitize_host
from ..utils.logger import get_logger


logger = get_logger(__name__)


@dataclass
class WorkerConfig:
    worker_id: str = field(default_factory=lambda: f"worker-{uuid.uuid4().hex[:8]}")
    unit_types: List[str] = field(default_factory=list)  # Empty = all
    max_concurrent: int = 1
    poll_interval: float = 1.0
    stale_timeout: int = 1800  # 30 minutes
    rate_limit: float = 10.0  # requests per second per domain
    check_scope: bool = True


class Worker:
    """Base worker that processes work units"""

    def __init__(self, config: WorkerConfig, queue: WorkUnitQueue, db: Database):
        self.config = config
        self.queue = queue
        self.db = db
        self.running = False
        self.current_units: Dict[int, WorkUnit] = {}
        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        self.scanners = self._init_scanners()
        self.domain_last_request: Dict[str, float] = {}
        self._rate_lock = threading.Lock()

    def _init_scanners(self) -> Dict[str, Any]:
        """Initialize scanner instances"""
        scanner_config = {
            "tools": self.config.__dict__.get("tools", {}),
            "wordlists": self.config.__dict__.get("wordlists", {}),
            "nuclei": self.config.__dict__.get("nuclei", {}),
        }
        return {
            "subfinder": SubfinderScanner(scanner_config),
            "httpx": HttpxScanner(scanner_config),
            "nuclei": NucleiScanner(scanner_config),
            "zap": ZAPScanner(scanner_config),
            "nikto": NiktoScanner(scanner_config),
            "gobuster": GobusterScanner(scanner_config),
            "amass": AmassScanner(scanner_config),
            "nmap": NmapScanner(scanner_config),
        }

    def _rate_limit(self, domain: str):
        """Enforce rate limiting per domain"""
        with self._rate_lock:
            now = time.time()
            last = self.domain_last_request.get(domain, 0)
            min_interval = 1.0 / self.config.rate_limit if self.config.rate_limit > 0 else 0
            if now - last < min_interval:
                time.sleep(min_interval - (now - last))
            self.domain_last_request[domain] = time.time()

    def start(self):
        """Start worker in background thread"""
        if self.running:
            return
        self.running = True
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()
        logger.info(f"Worker {self.config.worker_id} started")

    def stop(self, wait: bool = True):
        """Stop worker"""
        self.running = False
        self._stop_event.set()
        if self._thread and wait:
            self._thread.join(timeout=30)
        logger.info(f"Worker {self.config.worker_id} stopped")

    def _run_loop(self):
        """Main worker loop"""
        while self.running and not self._stop_event.is_set():
            try:
                units = self.queue.dequeue(
                    self.config.worker_id,
                    self.config.unit_types,
                    limit=self.config.max_concurrent
                )

                if not units:
                    self._idle_cycles = min(getattr(self, "_idle_cycles", 0) + 1, 6)
                    time.sleep(self.config.poll_interval * (1 + self._idle_cycles))
                    continue
                self._idle_cycles = 0

                for unit in units:
                    if self._stop_event.is_set():
                        break
                    self._process_unit(unit)

            except Exception as e:
                logger.error(f"Worker {self.config.worker_id} error: {e}")
                time.sleep(5)

    def _process_unit(self, unit: WorkUnit):
        """Process a single work unit"""
        self.current_units[unit.id] = unit
        logger.info(f"Worker {self.config.worker_id} processing {unit.unit_type} for {unit.target_host}")

        try:
            # Router: subfinder SOLO para dominios raíz; resto → probe directo
            if unit.unit_type == "subfinder" and \
               classify_target(unit.target_host) != "domain_root":
                kind = classify_target(unit.target_host)
                logger.info(f"[router] {unit.target_host} es {kind} → sondeo directo httpx")
                unit = WorkUnit(
                    scan_job_id=unit.scan_job_id, project_id=unit.project_id,
                    unit_type="httpx", target_host=sanitize_host(unit.target_host),
                    target_url=f"https://{sanitize_host(unit.target_host)}",
                    priority=unit.priority,
                    parameters={**(unit.parameters_dict or {}), "_converted_from": "subfinder"},
                )

            # Check scope: primero reglas BBAS del proyecto de la unidad; fallback ECC
            if self.config.check_scope:
                allowed = check_scope(unit.target_host, unit.unit_type,
                                      bbas_project=getattr(unit, "project_id", "") or None)
                if not allowed:
                    reason = (f"Fuera de scope: {unit.target_host} "
                              f"(proyecto={getattr(unit, 'project_id', '') or 'sin pin'})")
                    self.queue.complete(unit, error=reason)
                    logger.warning(f"Scope check failed: {reason}")
                    return

            # Apply rate limiting
            self._rate_limit(unit.target_host)

            # Execute based on unit type
            result = self._execute_unit(unit)

            # Ingesta + encadenamiento (subfinder→httpx→nuclei)
            if result.get("success"):
                try:
                    ingest_unit_result(self.db, self.queue, unit, result)
                except Exception as e:
                    logger.error(f"Ingest error {unit.unit_type}/{unit.target_host}: {e}")

            # Complete
            self.queue.complete(unit, result=result)

        except Exception as e:
            logger.error(f"Error processing unit {unit.id}: {e}")
            self.queue.complete(unit, error=str(e))
        finally:
            self.current_units.pop(unit.id, None)

    def _execute_unit(self, unit: WorkUnit) -> Dict[str, Any]:
        """Execute the appropriate scanner for the unit type"""
        unit_type = unit.unit_type
        target = sanitize_host(unit.target_url or unit.target_host)
        params = unit.parameters_dict if hasattr(unit, 'parameters_dict') else unit.parameters

        scanner = self.scanners.get(unit_type)
        if not scanner:
            raise ValueError(f"No scanner for unit type: {unit_type}")

        # Add common parameters
        scan_params = {
            "timeout": params.get("timeout", 300),
            "rate_limit": self.config.rate_limit,
        }
        scan_params.update(params)

        result = scanner.run(target, **scan_params)

        return {
            "success": result.success,
            "data": result.parsed_data,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "exit_code": result.exit_code,
            "duration_ms": result.duration_ms,
            "error": result.error,
        }


class WorkerPool:
    """Manage multiple workers"""

    def __init__(self, num_workers: int = 4, config: WorkerConfig = None):
        self.config = config or WorkerConfig()
        self.queue = WorkUnitQueue()
        self.db = Database()
        self.workers: List[Worker] = []
        self.num_workers = num_workers
        self._monitor_thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()

    def start(self):
        """Start all workers"""
        for i in range(self.num_workers):
            worker_config = WorkerConfig(
                worker_id=f"{self.config.worker_id}-{i}",
                unit_types=self.config.unit_types,
                max_concurrent=self.config.max_concurrent,
                poll_interval=self.config.poll_interval,
                rate_limit=self.config.rate_limit,
                check_scope=self.config.check_scope,
            )
            worker = Worker(worker_config, self.queue, self.db)
            self.workers.append(worker)
            worker.start()

        # Start monitor thread
        self._stop_event.clear()
        self._monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self._monitor_thread.start()

        logger.info(f"Worker pool started with {self.num_workers} workers")

    def stop(self, wait: bool = True):
        """Stop all workers"""
        self._stop_event.set()
        for worker in self.workers:
            worker.stop(wait=wait)
        if self._monitor_thread and wait:
            self._monitor_thread.join(timeout=10)
        logger.info("Worker pool stopped")

    def _monitor_loop(self):
        """Monitor for stale work units and recover them"""
        while not self._stop_event.is_set():
            time.sleep(60)  # Check every minute
            try:
                recovered = self.queue.recover_stale(self.config.stale_timeout)
                if recovered:
                    logger.info(f"Recovered {recovered} stale work units")
            except Exception as e:
                logger.error(f"Monitor error: {e}")

    def get_stats(self) -> Dict[str, Any]:
        """Get pool statistics"""
        total_stats = {"pending": 0, "running": 0, "completed": 0, "failed": 0, "skipped": 0}
        for worker in self.workers:
            stats = worker.queue.get_stats()
            for k, v in stats.items():
                total_stats[k] = total_stats.get(k, 0) + v
        return {
            "workers": len(self.workers),
            "queue": total_stats,
            "active_units": sum(len(w.current_units) for w in self.workers),
        }