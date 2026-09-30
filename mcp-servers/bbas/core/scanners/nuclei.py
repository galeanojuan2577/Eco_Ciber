"""Nuclei Scanner - Vulnerability scanning"""
import json
from typing import List, Dict, Any
from .base import Scanner, ScanResult, run_command


class NucleiScanner(Scanner):
    """Nuclei for vulnerability scanning"""

    def build_command(self, target: str, **kwargs) -> List[str]:
        if not target.startswith(("http://", "https://")):
            target = "https://" + target

        cmd = [
            self.tool_path,
            "-u", target,
            "-silent",
            "-json",
        ]

        # Severity
        severity = kwargs.get("severity", ["critical", "high", "medium"])
        if severity:
            cmd.extend(["-severity", ",".join(severity)])

        # Tags
        tags = kwargs.get("tags", ["exposures", "default-login", "misconfig", "cves", "takeover"])
        if tags:
            cmd.extend(["-tags", ",".join(tags)])

        # Rate limiting
        if kwargs.get("rate_limit"):
            cmd.extend(["-rate-limit", str(kwargs["rate_limit"])])
        if kwargs.get("bulk_size"):
            cmd.extend(["-bulk-size", str(kwargs["bulk_size"])])
        if kwargs.get("concurrency"):
            cmd.extend(["-c", str(kwargs["concurrency"])])

        # Templates
        if kwargs.get("templates"):
            cmd.extend(["-t", kwargs["templates"]])
        elif self.config.get("nuclei", {}).get("templates_path"):
            cmd.extend(["-t", self.config["nuclei"]["templates_path"]])

        # Timeouts
        if kwargs.get("timeout"):
            cmd.extend(["-timeout", str(kwargs["timeout"])])
        if kwargs.get("retries"):
            cmd.extend(["-retries", str(kwargs["retries"])])

        # Headers
        if kwargs.get("headers"):
            for h in kwargs["headers"]:
                cmd.extend(["-H", h])

        return cmd

    def parse_output(self, stdout: str, stderr: str, target: str) -> List[Dict[str, Any]]:
        """Parse nuclei JSON output"""
        findings = []
        for line in stdout.strip().split("\n"):
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                findings.append(self._normalize(data))
            except json.JSONDecodeError:
                continue
        return findings

    def _normalize(self, data: Dict) -> Dict[str, Any]:
        """Normalize nuclei finding"""
        info = data.get("info", {})
        return {
            "template_id": data.get("template-id", ""),
            "name": info.get("name", ""),
            "severity": info.get("severity", "info").lower(),
            "description": info.get("description", ""),
            "tags": info.get("tags", []),
            "reference": info.get("reference", []),
            "matcher_name": data.get("matcher-name", ""),
            "matched_at": data.get("matched-at", ""),
            "extracted_results": data.get("extracted-results", []),
            "host": data.get("host", ""),
            "url": data.get("url", ""),
            "type": data.get("type", ""),
            "protocol": data.get("protocol", ""),
            "cve": self._extract_cve(info),
            "cwe": self._extract_cwe(info),
            "cvss": self._extract_cvss(info),
        }

    def _extract_cve(self, info: Dict) -> List[str]:
        """Extract CVE IDs from references"""
        cves = []
        for ref in info.get("reference", []):
            if isinstance(ref, str) and "cve-" in ref.lower():
                # Extract CVE-YYYY-NNNNN
                import re
                matches = re.findall(r"CVE-\d{4}-\d{4,}", ref, re.IGNORECASE)
                cves.extend(matches)
        return list(set(cves))

    def _extract_cwe(self, info: Dict) -> List[str]:
        """Extract CWE IDs"""
        cwes = []
        for ref in info.get("reference", []):
            if isinstance(ref, str) and "cwe-" in ref.lower():
                import re
                matches = re.findall(r"CWE-\d+", ref, re.IGNORECASE)
                cwes.extend(matches)
        # Also check classification
        classification = info.get("classification", {})
        if isinstance(classification, dict):
            cwe_id = classification.get("cwe-id", "")
            if cwe_id:
                cwes.append(f"CWE-{cwe_id}")
        return list(set(cwes))

    def _extract_cvss(self, info: Dict) -> Optional[float]:
        """Extract CVSS score"""
        classification = info.get("classification", {})
        if isinstance(classification, dict):
            cvss = classification.get("cvss-score", "")
            if cvss:
                try:
                    return float(cvss)
                except ValueError:
                    pass
        # Try from metadata
        metadata = info.get("metadata", {})
        if isinstance(metadata, dict):
            cvss = metadata.get("cvss-score", "")
            if cvss:
                try:
                    return float(cvss)
                except ValueError:
                    pass
        return None

    def run_batch(self, targets: List[str], **kwargs) -> Dict[str, ScanResult]:
        """Run nuclei on multiple targets"""
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
            ]
            severity = kwargs.get("severity", ["critical", "high", "medium"])
            if severity:
                cmd.extend(["-severity", ",".join(severity)])
            tags = kwargs.get("tags", ["exposures", "default-login", "misconfig", "cves", "takeover"])
            if tags:
                cmd.extend(["-tags", ",".join(tags)])
            if kwargs.get("rate_limit"):
                cmd.extend(["-rate-limit", str(kwargs["rate_limit"])])
            if kwargs.get("templates"):
                cmd.extend(["-t", kwargs["templates"]])
            elif self.config.get("nuclei", {}).get("templates_path"):
                cmd.extend(["-t", self.config["nuclei"]["templates_path"]])

            result = run_command(cmd, timeout=kwargs.get("timeout", 600))

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