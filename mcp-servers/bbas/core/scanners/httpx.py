"""HTTPx Scanner - HTTP probing and technology detection"""
import json
import re
from typing import List, Dict, Any, Optional
from .base import Scanner, ScanResult, run_command


class HttpxScanner(Scanner):
    """HTTPx for probing live hosts and detecting technologies"""

    def build_command(self, target: str, **kwargs) -> List[str]:
        # target can be a host or URL
        if not target.startswith(("http://", "https://")):
            target = "https://" + target

        cmd = [
            self.tool_path,
            "-u", target,
            "-json",
            "-title",
            "-tech-detect",
            "-status-code",
            "-content-length",
            "-web-server",
            "-cdn",
            "-follow-redirects",
            "-max-redirects", "5",
            "-timeout", str(kwargs.get("timeout", 10)),
            "-retries", "1",
        ]

        if kwargs.get("ports"):
            cmd.extend(["-ports", kwargs["ports"]])
        if kwargs.get("rate_limit"):
            cmd.extend(["-rl", str(kwargs["rate_limit"])])
        if kwargs.get("follow_host_redirects"):
            cmd.append("-follow-host-redirects")

        return cmd

    ANSI_RE = None

    def parse_output(self, stdout: str, stderr: str, target: str) -> List[Dict[str, Any]]:
        """Parse httpx JSONL output (tolerante a ANSI/ruido)."""
        import re as _re
        ansi = _re.compile(r"\x1b\[[0-9;]*m")
        results = []
        for line in (stdout or "").splitlines():
            line = ansi.sub("", line).strip()
            if not line or not line.startswith("{"):
                continue
            try:
                results.append(self._normalize(json.loads(line)))
            except Exception:
                continue
        return results

    def _normalize(self, data: Dict) -> Dict[str, Any]:
        """Normalize httpx output"""
        return {
            "url": data.get("url", ""),
            "host": data.get("host", ""),
            "status_code": data.get("status_code", 0),
            "title": data.get("title", ""),
            "webserver": data.get("webserver", ""),
            "tech": data.get("tech", []),
            "cdn": data.get("cdn", []),
            "content_length": data.get("content_length", 0),
            "ip": data.get("ip", ""),
            "final_url": data.get("final_url", data.get("url", "")),
        }

    def _parse_text(self, line: str) -> Optional[Dict[str, Any]]:
        """Parse text output as fallback"""
        # Format: url [status] [title] [server] [tech] [cdn]
        parts = line.split(" ", 5)
        if len(parts) < 2:
            return None
        return {
            "url": parts[0],
            "status_code": int(parts[1].strip("[]")) if parts[1].startswith("[") else 0,
            "title": parts[2].strip("[]") if len(parts) > 2 and parts[2].startswith("[") else "",
            "webserver": parts[3].strip("[]") if len(parts) > 3 and parts[3].startswith("[") else "",
            "tech": [],
            "cdn": [],
        }

    def run_batch(self, targets: List[str], **kwargs) -> Dict[str, ScanResult]:
        """Run httpx on multiple targets"""
        if not targets:
            return {}

        import tempfile
        with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as f:
            f.write("\n".join(targets))
            temp_file = f.name

        try:
            cmd = [
                self.tool_path,
                "-l", temp_file,
                "-silent",
                "-json",
                "-title",
                "-tech-detect",
                "-status-code",
                "-web-server",
                "-cdn",
                "-follow-redirects",
                "-timeout", str(kwargs.get("timeout", 10)),
                "-retries", "1",
            ]
            if kwargs.get("rate_limit"):
                cmd.extend(["-rl", str(kwargs["rate_limit"])])

            result = run_command(cmd, timeout=kwargs.get("timeout", 30) * len(targets) + 60)

            # Parse and group by host
            parsed = self.parse_output(result.stdout, result.stderr, "")
            grouped = {}
            for item in parsed:
                host = item.get("host", "")
                if host not in grouped:
                    grouped[host] = []
                grouped[host].append(item)

            return {host: ScanResult(success=True, parsed_data=items) for host, items in grouped.items()}

        finally:
            import os
            os.unlink(temp_file)