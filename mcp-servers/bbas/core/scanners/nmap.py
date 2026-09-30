"""Nmap Scanner - Port scanning and service detection"""
import xml.etree.ElementTree as ET
import tempfile
import os
from typing import List, Dict, Any
from .base import Scanner, ScanResult, run_command


class NmapScanner(Scanner):
    """Nmap for port scanning and service detection"""

    def build_command(self, target: str, **kwargs) -> List[str]:
        scan_type = kwargs.get("scan_type", "service")  # quick, service, vuln, full

        cmd = [self.tool_path]

        if scan_type == "quick":
            cmd.extend(["-F", "-T4"])
        elif scan_type == "service":
            cmd.extend(["-sV", "-sC", "-T4"])
        elif scan_type == "vuln":
            cmd.extend(["-sV", "--script=vuln", "-T4"])
        elif scan_type == "full":
            cmd.extend(["-p-", "-sV", "-sC", "-T4"])

        if kwargs.get("ports"):
            cmd.extend(["-p", kwargs["ports"]])
        if kwargs.get("exclude_ports"):
            cmd.extend(["--exclude-ports", kwargs["exclude_ports"]])
        if kwargs.get("rate"):
            cmd.extend(["--min-rate", str(kwargs["rate"])])
        if kwargs.get("timeout"):
            cmd.extend(["--host-timeout", f"{kwargs['timeout']}s"])

        # Output formats
        with tempfile.NamedTemporaryFile(mode="w", suffix=".xml", delete=False) as f:
            xml_file = f.name
        cmd.extend(["-oX", xml_file])

        cmd.append(target)
        return cmd

    def run(self, target: str, timeout: int = 600, **kwargs) -> ScanResult:
        """Run Nmap with XML output"""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".xml", delete=False) as f:
            xml_file = f.name

        try:
            cmd = self.build_command(target, **kwargs)
            # Replace the last temp file with our controlled one
            for i, arg in enumerate(cmd):
                if arg == "-oX":
                    cmd[i + 1] = xml_file
                    break

            result = run_command(cmd, timeout=timeout)
            parsed = self.parse_output(xml_file)
            result.parsed_data = parsed
            return result

        finally:
            if os.path.exists(xml_file):
                os.unlink(xml_file)

    def parse_output(self, xml_file: str) -> List[Dict[str, Any]]:
        """Parse Nmap XML output"""
        findings = []
        if not os.path.exists(xml_file):
            return findings

        try:
            tree = ET.parse(xml_file)
            root = tree.getroot()

            for host in root.findall("host"):
                host_data = {"tool": "nmap", "host": "", "ports": [], "os": []}

                # Get IP
                for addr in host.findall("address"):
                    if addr.get("addrtype") == "ipv4":
                        host_data["host"] = addr.get("addr", "")
                        break

                # Get ports
                for port in host.findall(".//port"):
                    port_id = port.get("portid", "")
                    protocol = port.get("protocol", "")
                    state = port.find("state")
                    state_val = state.get("state", "") if state is not None else ""

                    service = port.find("service")
                    service_data = {}
                    if service is not None:
                        service_data = {
                            "name": service.get("name", ""),
                            "product": service.get("product", ""),
                            "version": service.get("version", ""),
                            "extrainfo": service.get("extrainfo", ""),
                            "ostype": service.get("ostype", ""),
                            "method": service.get("method", ""),
                            "conf": service.get("conf", ""),
                        }

                    # Scripts
                    scripts = []
                    for script in port.findall("script"):
                        scripts.append({
                            "id": script.get("id", ""),
                            "output": script.get("output", ""),
                        })

                    host_data["ports"].append({
                        "port": int(port_id) if port_id.isdigit() else port_id,
                        "protocol": protocol,
                        "state": state_val,
                        "service": service_data,
                        "scripts": scripts,
                    })

                # OS detection
                for osmatch in host.findall(".//osmatch"):
                    host_data["os"].append({
                        "name": osmatch.get("name", ""),
                        "accuracy": osmatch.get("accuracy", ""),
                    })

                if host_data["host"]:
                    findings.append(host_data)

        except ET.ParseError:
            pass

        return findings