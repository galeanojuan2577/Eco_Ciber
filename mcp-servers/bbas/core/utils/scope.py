"""Scope Checking Utility - Integrates with check-scope.sh"""
import subprocess
import os
import json
from pathlib import Path
from typing import Optional, List, Dict, Any
from functools import lru_cache


def check_scope(target: str, test_type: str = "recon", project: str = None, force: bool = False,
                bbas_project: str = None) -> bool:
    """
    Gate de scope con doble capa:
      1) Si bbas_project → scope_rules del proyecto BBAS (wildcards/OOS).
      2) Fallback: check-scope.sh del ecosistema ECC (proyecto pineado).
    """
    phase = UNIT_PHASE.get(test_type, test_type)

    # Capa 1: proyecto BBAS explícito
    if bbas_project:
        if check_scope_bbas(target, phase, bbas_project):
            return True
        # Si el proyecto BBAS tiene reglas, su veredicto es definitivo
        from ..models.database import Database
        db = Database()
        n = db.fetchone("SELECT COUNT(*) c FROM scope_rules WHERE project_id = ?", (bbas_project,))
        if n and n["c"] > 0:
            return False

    # Capa 2: ecosistema ECC
    check_scope_path = "/root/.config/opencode/tools/check-scope.sh"

    if not os.path.exists(check_scope_path):
        return _check_local_scope(target, test_type, project)
    
    try:
        cmd = [check_scope_path, target, test_type]
        if force:
            cmd.append("--force")
        if project:
            cmd.extend(["--project", project])
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        # Exit codes: 0 = authorized, 1 = needs confirmation, 2 = hard reject
        return result.returncode == 0
        
    except Exception:
        # Fallback to local check
        return _check_local_scope(target, test_type, project)


def _check_local_scope(target: str, test_type: str, project: str = None) -> bool:
    """Fallback scope check using local scope.json"""
    # Try to find project
    if not project:
        project = _get_active_project()
    
    if not project:
        return False  # No project = no authorization
    
    scope_file = Path(f"/root/.config/opencode/cyber/projects/{project}/scope.json")
    if not scope_file.exists():
        return False
    
    try:
        with open(scope_file) as f:
            scope = json.load(f)
        
        # Check excluded first
        for excluded in scope.get("excluded", []):
            if _match_pattern(excluded, target):
                return False
        
        # Check authorized targets
        for t in scope.get("targets", []):
            if _match_pattern(t.get("target", ""), target):
                allowed_type = t.get("type", "all")
                if allowed_type == "all" or allowed_type == test_type or test_type == "all":
                    return True
        
        return False
        
    except Exception:
        return False


def _match_pattern(pattern: str, target: str) -> bool:
    """Match target against pattern (supports wildcards)"""
    if pattern == target:
        return True
    if pattern.startswith("*."):
        suffix = pattern[1:]
        return target == suffix[1:] or target.endswith(suffix)
    return False

# Unidad de trabajo → fase de scope (recon/scan/enumerate/all)
UNIT_PHASE = {
    "subfinder": "recon", "amass": "recon", "httpx": "recon",
    "nmap": "recon", "dnsrecon": "recon", "theharvester": "recon",
    "nuclei": "scan", "zap": "scan", "nikto": "scan",
    "gobuster": "enumerate", "ffuf": "enumerate", "enum4linux": "enumerate",
}


def check_scope_bbas(target: str, phase: str, project_id: str) -> bool:
    """Valida target contra las scope_rules del proyecto BBAS.

    Prioridad: excluded (rechazo duro) > wildcards/exactos in-scope.
    Reglas type='all' autorizan cualquier fase.
    """
    if not project_id:
        return False
    try:
        from ..models.database import Database
        db = Database()
        rows = db.fetchall(
            "SELECT target, type, excluded FROM scope_rules WHERE project_id = ?",
            (project_id,)
        )
    except Exception:
        return False

    for r in rows:
        if r["excluded"] and _match_pattern(r["target"], target):
            return False
    for r in rows:
        if r["excluded"]:
            continue
        rtype = (r["type"] or "all").lower()
        if _match_pattern(r["target"], target) and (rtype == "all" or rtype == phase):
            return True
    return False



def _get_active_project() -> Optional[str]:
    """Get active project from session"""
    session_file = Path("/root/.config/opencode/cyber/session.json")
    if session_file.exists():
        try:
            with open(session_file) as f:
                data = json.load(f)
                return data.get("project")
        except Exception:
            pass
    
    # Try CYBER_PROJECT env var
    import os
    return os.environ.get("CYBER_PROJECT")


def load_scope(project: str = None) -> Dict[str, Any]:
    """Load scope.json for a project"""
    if not project:
        project = _get_active_project()
    
    if not project:
        return {"targets": [], "excluded": []}
    
    scope_file = Path(f"/root/.config/opencode/cyber/projects/{project}/scope.json")
    if not scope_file.exists():
        return {"targets": [], "excluded": []}
    
    try:
        with open(scope_file) as f:
            return json.load(f)
    except Exception:
        return {"targets": [], "excluded": []}


class ScopeChecker:
    """Cached scope checker for performance"""
    
    def __init__(self, project: str = None):
        self.project = project or _get_active_project()
        self._scope_cache: Optional[Dict] = None
        self._cache_time = 0
    
    def _get_scope(self) -> Dict[str, Any]:
        """Get scope with caching"""
        import time
        if self._scope_cache is None or time.time() - self._cache_time > 60:
            self._scope_cache = load_scope(self.project)
            self._cache_time = time.time()
        return self._scope_cache
    
    def is_authorized(self, target: str, test_type: str = "recon") -> bool:
        """Check if target is authorized"""
        if not self.project:
            return False
        
        scope = self._get_scope()
        
        # Check excluded
        for excluded in scope.get("excluded", []):
            if _match_pattern(excluded, target):
                return False
        
        # Check authorized
        for t in scope.get("targets", []):
            if _match_pattern(t.get("target", ""), target):
                allowed_type = t.get("type", "all")
                if allowed_type == "all" or allowed_type == test_type or test_type == "all":
                    return True
        
        return False
    
    def get_authorized_targets(self, test_type: str = "recon") -> List[str]:
        """Get all targets authorized for test_type"""
        scope = self._get_scope()
        targets = []
        for t in scope.get("targets", []):
            allowed_type = t.get("type", "all")
            if allowed_type == "all" or allowed_type == test_type or test_type == "all":
                targets.append(t.get("target", ""))
        return targets
    
    def invalidate_cache(self):
        """Invalidate scope cache"""
        self._scope_cache = None
        self._cache_time = 0