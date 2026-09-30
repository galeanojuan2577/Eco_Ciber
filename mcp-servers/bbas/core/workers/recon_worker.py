"""Recon Worker - Specialized for reconnaissance tasks"""
from typing import List, Dict, Any
from .worker import Worker, WorkerConfig
from ..queue.queue import WorkUnitQueue
from ..models.database import Database


class ReconWorker(Worker):
    """Worker specialized for reconnaissance tasks"""

    def __init__(self, config: WorkerConfig, queue: WorkUnitQueue, db: Database):
        # Only handle recon unit types
        if not config.unit_types:
            config.unit_types = ["subfinder", "amass", "httpx", "nmap"]
        super().__init__(config, queue, db)

    def _execute_unit(self, unit) -> Dict[str, Any]:
        """Execute recon-specific logic"""
        unit_type = unit.unit_type
        target = unit.target_url or unit.target_host
        params = unit.parameters_dict if hasattr(unit, 'parameters_dict') else unit.parameters

        # Add recon-specific defaults
        scan_params = {
            "timeout": params.get("timeout", 300),
            "rate_limit": self.config.rate_limit,
        }

        # Add specific parameters based on unit type
        if unit_type == "subfinder":
            scan_params.update({
                "recursive": params.get("recursive", False),
                "max_subdomains": params.get("max_subdomains", 1000),
            })
        elif unit_type == "amass":
            scan_params.update({
                "passive": params.get("passive", True),
                "mode": params.get("mode", "enum"),
            })
        elif unit_type == "httpx":
            scan_params.update({
                "ports": params.get("ports", "80,443,8080,8443"),
                "follow_host_redirects": params.get("follow_host_redirects", True),
            })
        elif unit_type == "nmap":
            scan_params.update({
                "scan_type": params.get("scan_type", "service"),
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


def create_recon_worker(config: WorkerConfig = None, queue: WorkUnitQueue = None, db: Database = None) -> ReconWorker:
    """Factory function to create a recon worker"""
    config = config or WorkerConfig(unit_types=["subfinder", "amass", "httpx", "nmap"])
    queue = queue or WorkUnitQueue()
    db = db or Database()
    return ReconWorker(config, queue, db)