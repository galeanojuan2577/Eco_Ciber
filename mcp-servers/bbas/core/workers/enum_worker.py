"""Enum Worker - Specialized for deep enumeration"""
from typing import List, Dict, Any
from .worker import Worker, WorkerConfig
from ..queue.queue import WorkUnitQueue
from ..models.database import Database


class EnumWorker(Worker):
    """Worker specialized for deep enumeration"""

    def __init__(self, config: WorkerConfig, queue: WorkUnitQueue, db: Database):
        if not config.unit_types:
            config.unit_types = ["gobuster", "ffuf", "sqlmap", "enum4linux"]
        super().__init__(config, queue, db)

    def _execute_unit(self, unit) -> Dict[str, Any]:
        """Execute enumeration-specific logic"""
        unit_type = unit.unit_type
        target = unit.target_url or unit.target_host
        params = unit.parameters_dict if hasattr(unit, 'parameters_dict') else unit.parameters

        scan_params = {
            "timeout": params.get("timeout", 300),
            "rate_limit": self.config.rate_limit,
        }

        if unit_type == "gobuster":
            scan_params.update({
                "mode": params.get("mode", "dir"),
                "wordlist": params.get("wordlist"),
                "threads": params.get("threads", 20),
                "extensions": params.get("extensions", "php,html,js,txt,json,xml"),
                "status_codes": params.get("status_codes", "200,201,204,301,302,307,401,403"),
            })
        elif unit_type == "nmap":
            scan_params.update({
                "scan_type": params.get("scan_type", "service"),
            })

        scan_params.update(params)

        scanner = self.scanners.get(unit_type)
        if not scanner:
            # For tools not yet implemented, return a placeholder
            if unit_type in ["ffuf", "sqlmap", "enum4linux"]:
                return {
                    "success": False,
                    "error": f"Scanner for {unit_type} not yet implemented",
                    "data": [],
                }
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


def create_enum_worker(config: WorkerConfig = None, queue: WorkUnitQueue = None, db: Database = None) -> EnumWorker:
    """Factory function to create an enum worker"""
    config = config or WorkerConfig(unit_types=["gobuster", "nmap"])
    queue = queue or WorkUnitQueue()
    db = db or Database()
    return EnumWorker(config, queue, db)