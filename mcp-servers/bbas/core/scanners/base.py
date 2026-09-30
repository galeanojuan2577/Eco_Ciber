"""Base Scanner Classes"""
import subprocess
import time
import shlex
from dataclasses import dataclass, field
from typing import Dict, Any, List, Optional
from abc import ABC, abstractmethod


@dataclass
class ScanResult:
    """Result of a scanner execution"""
    success: bool
    stdout: str = ""
    stderr: str = ""
    exit_code: int = 0
    duration_ms: int = 0
    parsed_data: Any = None
    error: str = ""


class Scanner(ABC):
    """Base class for all scanners"""

    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        self.tool_name = self.__class__.__name__.replace("Scanner", "").lower()
        cfg_path = self.config.get("tools", {}).get(self.tool_name)
        if cfg_path:
            self.tool_path = cfg_path
        else:
            import shutil
            alt = {"httpx": ["httpx-pd", "httpx"]}.get(self.tool_name, [self.tool_name])
            self.tool_path = next((a for a in alt if shutil.which(a)), self.tool_name)

    @abstractmethod
    def build_command(self, target: str, **kwargs) -> List[str]:
        """Build command for the target"""
        pass

    @abstractmethod
    def parse_output(self, stdout: str, stderr: str, target: str) -> Any:
        """Parse tool output into structured data"""
        pass

    def run(self, target: str, timeout: int = 300, **kwargs) -> ScanResult:
        """Execute scanner on target"""
        cmd = self.build_command(target, **kwargs)
        start = time.time()

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
                shell=False
            )
            duration = int((time.time() - start) * 1000)

            parsed = self.parse_output(result.stdout, result.stderr, target)

            return ScanResult(
                success=result.returncode == 0,
                stdout=result.stdout,
                stderr=result.stderr,
                exit_code=result.returncode,
                duration_ms=duration,
                parsed_data=parsed
            )

        except subprocess.TimeoutExpired:
            duration = int((time.time() - start) * 1000)
            return ScanResult(
                success=False,
                stdout="",
                stderr=f"Timeout after {timeout}s",
                exit_code=-1,
                duration_ms=duration,
                error=f"Timeout after {timeout}s"
            )
        except FileNotFoundError:
            return ScanResult(
                success=False,
                stdout="",
                stderr=f"Tool not found: {self.tool_path}",
                exit_code=-1,
                duration_ms=0,
                error=f"Tool not found: {self.tool_path}"
            )
        except Exception as e:
            duration = int((time.time() - start) * 1000)
            return ScanResult(
                success=False,
                stdout="",
                stderr=str(e),
                exit_code=-1,
                duration_ms=duration,
                error=str(e)
            )

    def is_available(self) -> bool:
        """Check if tool is available"""
        try:
            subprocess.run([self.tool_path, "--version"], capture_output=True, timeout=5)
            return True
        except Exception:
            return False


def run_command(cmd: List[str], timeout: int = 300) -> ScanResult:
    """Helper to run a command and return ScanResult"""
    start = time.time()
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return ScanResult(
            success=result.returncode == 0,
            stdout=result.stdout,
            stderr=result.stderr,
            exit_code=result.returncode,
            duration_ms=int((time.time() - start) * 1000)
        )
    except subprocess.TimeoutExpired:
        return ScanResult(success=False, stderr=f"Timeout after {timeout}s", exit_code=-1,
                          duration_ms=int((time.time() - start) * 1000),
                          error=f"Timeout after {timeout}s")
    except FileNotFoundError:
        return ScanResult(success=False, stderr=f"Command not found: {cmd[0]}", exit_code=-1,
                          error=f"Command not found: {cmd[0]}")
    except Exception as e:
        return ScanResult(success=False, stderr=str(e), exit_code=-1,
                          duration_ms=int((time.time() - start) * 1000), error=str(e))