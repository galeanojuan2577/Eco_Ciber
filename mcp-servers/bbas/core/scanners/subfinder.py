"""Subfinder Scanner - Subdomain enumeration"""
import json
from typing import List, Dict, Any
from .base import Scanner, ScanResult, run_command


class SubfinderScanner(Scanner):
    """Subfinder for passive subdomain enumeration"""

    def build_command(self, target: str, **kwargs) -> List[str]:
        # defensa: nunca pasar esquemas/rutas al dominio
        t = target.strip().lower()
        if "://" in t: t = t.split("://", 1)[1]
        t = t.split("/")[0].lstrip(".")
        while t.startswith("*."): t = t[2:]
        cmd = [self.tool_path, "-d", t, "-silent"]
        if kwargs.get("recursive"):
            cmd.append("-recursive")
        if kwargs.get("sources"):
            cmd.extend(["-sources", kwargs["sources"]])
        if kwargs.get("exclude_sources"):
            cmd.extend(["-exclude-sources", kwargs["exclude_sources"]])
        if kwargs.get("rate_limit"):
            cmd.extend(["-rate-limit", str(kwargs["rate_limit"])])
        return cmd

    def parse_output(self, stdout: str, stderr: str, target: str) -> List[str]:
        """Parse subfinder output - one subdomain per line"""
        subdomains = []
        for line in stdout.strip().split("\n"):
            line = line.strip()
            if line and not line.startswith("["):
                subdomains.append(line)
        return subdomains

    def run_multiple(self, targets: List[str], **kwargs) -> Dict[str, ScanResult]:
        """Run subfinder on multiple domains at once"""
        if not targets:
            return {}

        # Write targets to temp file
        import tempfile
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("\n".join(targets))
            temp_file = f.name

        try:
            cmd = [self.tool_path, "-dL", temp_file, "-silent"]
            if kwargs.get("rate_limit"):
                cmd.extend(["-rate-limit", str(kwargs["rate_limit"])])
            if kwargs.get("max_subdomains"):
                cmd.extend(["-max-subdomains", str(kwargs["max_subdomains"])])

            result = run_command(cmd, timeout=kwargs.get("timeout", 600))

            # Parse and group by root domain
            all_subs = self.parse_output(result.stdout, result.stderr, "")
            grouped = {}
            for sub in all_subs:
                # Find which root domain this belongs to
                for root in targets:
                    if sub.endswith("." + root) or sub == root:
                        if root not in grouped:
                            grouped[root] = []
                        grouped[root].append(sub)
                        break

            return {root: ScanResult(success=True, parsed_data=subs) for root, subs in grouped.items()}

        finally:
            import os
            os.unlink(temp_file)