"""ZAP Scanner - Baseline passive scan"""
import json
import tempfile
import os
from typing import List, Dict, Any
from .base import Scanner, ScanResult, run_command


class ZAPScanner(Scanner):
    """OWASP ZAP Baseline scan"""

    def build_command(self, target: str, **kwargs) -> List[str]:
        if not target.startswith(("http://", "https://")):
            target = "https://" + target

        # ZAP baseline uses a YAML config, we'll generate it
        return []  # Command built in run() with temp config

    def run(self, target: str, timeout: int = 300, **kwargs) -> ScanResult:
        """Run ZAP baseline scan"""
        if not target.startswith(("http://", "https://")):
            target = "https://" + target

        # Generate ZAP config
        config = self._generate_config(target, kwargs)
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as f:
            f.write(config)
            config_file = f.name

        try:
            cmd = [
                self.tool_path,
                "-cmd",
                "-silent",
                "-autorun", config_file,
            ]
            if kwargs.get("port"):
                cmd.extend(["-port", str(kwargs["port"])])
            if kwargs.get("host"):
                cmd.extend(["-host", kwargs["host"]])

            result = run_command(cmd, timeout=timeout)
            parsed = self.parse_output(result.stdout, result.stderr, target)
            result.parsed_data = parsed
            return result

        finally:
            os.unlink(config_file)

    def _generate_config(self, target: str, kwargs: Dict) -> str:
        """Generate ZAP baseline YAML config"""
        spider_time = kwargs.get("spider_time", 2)
        scan_time = kwargs.get("scan_time", 5)
        return f"""
env:
  contexts:
    - name: "baseline"
      urls:
        - "{target}"
  parameters:
    failOnError: false
    failOnWarning: false
    progressToStdout: true

jobs:
  - type: spider
    parameters:
      context: "baseline"
      maxDuration: {spider_time}
      maxDepth: 5

  - type: passiveScan
    parameters:
      context: "baseline"
      maxDuration: {scan_time}
      maxAlertsPerRule: 10

  - type: activeScan
    parameters:
      context: "baseline"
      policy: "Default Policy"
      maxDuration: 0
      maxRules: 0

  - type: report
    parameters:
      template: "traditional-json"
      reportDir: "."
      reportFile: "zap-report.json"
"""

    def parse_output(self, stdout: str, stderr: str, target: str) -> List[Dict[str, Any]]:
        """Parse ZAP JSON report"""
        findings = []

        # Try to find the report file
        import glob
        report_files = glob.glob("zap-report*.json")
        if not report_files:
            # Try current directory
            report_files = glob.glob("./zap-report*.json")

        for report_file in report_files:
            try:
                with open(report_file, "r") as f:
                    data = json.load(f)

                for site in data.get("site", []):
                    for alert in site.get("alerts", []):
                        findings.append({
                            "tool": "zap",
                            "name": alert.get("name", ""),
                            "risk": alert.get("riskdesc", "").lower(),
                            "confidence": alert.get("confidence", "").lower(),
                            "description": alert.get("desc", ""),
                            "solution": alert.get("solution", ""),
                            "reference": alert.get("ref", ""),
                            "cwe": alert.get("cweid", ""),
                            "wasc": alert.get("wascid", ""),
                            "url": alert.get("uri", ""),
                            "param": alert.get("param", ""),
                            "attack": alert.get("attack", ""),
                            "evidence": alert.get("evidence", ""),
                            "method": alert.get("method", ""),
                        })
            except Exception:
                continue

        return findings