"""Gobuster Scanner - Directory/file enumeration"""
from typing import List, Dict, Any
from .base import Scanner, ScanResult, run_command


class GobusterScanner(Scanner):
    """Gobuster for directory enumeration"""

    def build_command(self, target: str, **kwargs) -> List[str]:
        if not target.startswith(("http://", "https://")):
            target = "https://" + target

        mode = kwargs.get("mode", "dir")
        wordlist = kwargs.get("wordlist", self.config.get("wordlists", {}).get("directories", "/usr/share/wordlists/dirb/common.txt"))

        cmd = [
            self.tool_path,
            mode,
            "-u", target,
            "-w", wordlist,
            "-q",  # quiet
            "-t", str(kwargs.get("threads", 20)),
        ]

        if kwargs.get("extensions"):
            cmd.extend(["-x", kwargs["extensions"]])
        if kwargs.get("status_codes"):
            cmd.extend(["-s", kwargs["status_codes"]])
        if kwargs.get("exclude_status"):
            cmd.extend(["-b", kwargs["exclude_status"]])
        if kwargs.get("follow_redirect"):
            cmd.append("-r")
        if kwargs.get("timeout"):
            cmd.extend(["--timeout", f"{kwargs['timeout']}s"])
        if kwargs.get("user_agent"):
            cmd.extend(["-a", kwargs["user_agent"]])

        return cmd

    def parse_output(self, stdout: str, stderr: str, target: str) -> List[Dict[str, Any]]:
        """Parse Gobuster output"""
        findings = []
        # Format: /path (Status: 200) [Size: 1234]
        import re
        pattern = r"^(\S+)\s+\(Status:\s+(\d+)\)\s*\[Size:\s+(\d+)\]"
        for line in stdout.strip().split("\n"):
            line = line.strip()
            if not line:
                continue
            match = re.match(pattern, line)
            if match:
                findings.append({
                    "tool": "gobuster",
                    "path": match.group(1),
                    "status_code": int(match.group(2)),
                    "size": int(match.group(3)),
                    "url": target.rstrip("/") + match.group(1),
                })
        return findings

    def run_batch(self, targets: List[str], **kwargs) -> Dict[str, ScanResult]:
        """Run gobuster on multiple targets sequentially"""
        results = {}
        for target in targets:
            result = self.run(target, **kwargs)
            results[target] = result
        return results