"""Amass Scanner - Passive/Active subdomain enumeration"""
import json
import tempfile
import os
from typing import List, Dict, Any
from .base import Scanner, ScanResult, run_command


class AmassScanner(Scanner):
    """Amass for subdomain enumeration"""

    def build_command(self, target: str, **kwargs) -> List[str]:
        mode = kwargs.get("mode", "enum")  # enum, intel, track
        passive = kwargs.get("passive", True)

        cmd = [self.tool_path, mode]

        if mode == "enum":
            if passive:
                cmd.append("-passive")
            cmd.extend(["-d", target])
            if kwargs.get("config"):
                cmd.extend(["-config", kwargs["config"]])
            if kwargs.get("max_dns_queries"):
                cmd.extend(["-max-dns-queries", str(kwargs["max_dns_queries"])])
        elif mode == "intel":
            cmd.extend(["-whois", "-d", target])

        cmd.extend(["-json", "-silent"])
        return cmd

    def run(self, target: str, timeout: int = 600, **kwargs) -> ScanResult:
        """Run Amass with temp output file"""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            output_file = f.name

        try:
            cmd = self.build_command(target, **kwargs)
            cmd.extend(["-o", output_file])

            result = run_command(cmd, timeout=timeout)
            parsed = self.parse_output(output_file)
            result.parsed_data = parsed
            return result

        finally:
            if os.path.exists(output_file):
                os.unlink(output_file)

    def parse_output(self, output_file: str) -> List[Dict[str, Any]]:
        """Parse Amass JSON output"""
        findings = []
        if not os.path.exists(output_file):
            return findings

        with open(output_file, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    findings.append({
                        "tool": "amass",
                        "name": data.get("name", ""),
                        "domain": data.get("domain", ""),
                        "subdomain": data.get("subdomain", ""),
                        "tag": data.get("tag", ""),
                        "source": data.get("source", ""),
                        "ip": data.get("ip", []),
                    })
                except json.JSONDecodeError:
                    continue
        return findings