"""Nikto Scanner - Web server vulnerability scanner"""
import tempfile
import os
from typing import List, Dict, Any
from .base import Scanner, ScanResult, run_command


class NiktoScanner(Scanner):
    """Nikto for web server scanning"""

    def build_command(self, target: str, **kwargs) -> List[str]:
        if not target.startswith(("http://", "https://")):
            target = "https://" + target

        cmd = [
            self.tool_path,
            "-h", target,
            "-nointeractive",
            "-maxtime", str(kwargs.get("maxtime", 120)),
            "-timeout", str(kwargs.get("timeout", 10)),
        ]

        if kwargs.get("format"):
            cmd.extend(["-Format", kwargs["format"]])
        if kwargs.get("output"):
            cmd.extend(["-o", kwargs["output"]])
        if kwargs.get("tuning"):
            cmd.extend(["-Tuning", kwargs["tuning"]])
        if kwargs.get("ssl"):
            cmd.append("-ssl")
        if kwargs.get("user_agent"):
            cmd.extend(["-useragent", kwargs["user_agent"]])

        return cmd

    def run(self, target: str, timeout: int = 300, **kwargs) -> ScanResult:
        """Run Nikto scan with temp output file"""
        if not target.startswith(("http://", "https://")):
            target = "https://" + target

        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            output_file = f.name

        try:
            cmd = self.build_command(target, **kwargs)
            cmd.extend(["-o", output_file, "-Format", "txt"])

            result = run_command(cmd, timeout=timeout)
            parsed = self.parse_output(output_file, target)
            result.parsed_data = parsed
            return result

        finally:
            if os.path.exists(output_file):
                os.unlink(output_file)

    def parse_output(self, output_file: str, target: str) -> List[Dict[str, Any]]:
        """Parse Nikto text output"""
        findings = []
        if not os.path.exists(output_file):
            return findings

        with open(output_file, "r") as f:
            content = f.read()

        # Parse Nikto output format
        # + OSVDB-XXXXX: Description
        # + /path: Description
        import re
        for line in content.split("\n"):
            line = line.strip()
            if not line or line.startswith("+ Target") or line.startswith("+ Host"):
                continue

            if line.startswith("+"):
                # Finding line
                parts = line.split(":", 1)
                if len(parts) == 2:
                    finding = parts[1].strip()
                    findings.append({
                        "tool": "nikto",
                        "finding": finding,
                        "raw": line,
                    })

        return findings