"""Scan Worker - Specialized for vulnerability scanning"""
from typing import List, Dict, Any
from .worker import Worker, WorkerConfig
from ..queue.queue import WorkUnitQueue
from ..models.database import Database


class ScanWorker(Worker):
    """Worker specialized for vulnerability scanning"""

    def __init__(self, config: WorkerConfig, queue: WorkUnitQueue, db: Database):
        if not config.unit_types:
            config.unit_types = ["nuclei", "zap", "nikto"]
        super().__init__(config, queue, db)

    def _execute_unit(self, unit) -> Dict[str, Any]:
        """Execute scan-specific logic"""
        unit_type = unit.unit_type
        target = unit.target_url or unit.target_host
        params = unit.parameters_dict if hasattr(unit, 'parameters_dict') else unit.parameters

        scan_params = {
            "timeout": params.get("timeout", 300),
            "rate_limit": self.config.rate_limit,
        }

        if unit_type == "nuclei":
            scan_params.update({
                "severity": params.get("severity", ["critical", "high", "medium"]),
                "tags": params.get("tags", ["exposures", "default-login", "misconfig", "cves", "takeover"]),
                "templates": params.get("templates"),
            })
        elif unit_type == "zap":
            scan_params.update({
                "spider_time": params.get("spider_time", 2),
                "scan_time": params.get("scan_time", 5),
            })
        elif unit_type == "nikto":
            scan_params.update({
                "maxtime": params.get("maxtime", 120),
                "tuning": params.get("tuning", "x"),  # Default tuning
            })

        scan_params.update(params)

        scanner = self.scanners.get(unit_type)
        if not scanner:
            raise ValueError(f"No scanner for unit type: {unit_type}")

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


def create_scan_worker(config: WorkerConfig = None, queue: WorkUnitQueue = None, db: Database = None) -> ScanWorker:
    """Factory function to create a scan worker"""
    config = config or WorkerConfig(unit_types=["nuclei", "zap", "nikto"])
    queue = queue or WorkUnitQueue()
    db = db or Database()
    return ScanWorker(config, queue, db)