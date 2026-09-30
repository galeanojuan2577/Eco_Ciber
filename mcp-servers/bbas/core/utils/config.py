"""Configuration Loader"""
import yaml
import os
from pathlib import Path
from typing import Dict, Any, Optional
from dataclasses import dataclass, field


@dataclass
class Config:
    """BBAS Configuration"""
    daemon: Dict[str, Any] = field(default_factory=dict)
    queue: Dict[str, Any] = field(default_factory=dict)
    scanner: Dict[str, Any] = field(default_factory=dict)
    auto_update: Dict[str, Any] = field(default_factory=dict)
    health_monitor: Dict[str, Any] = field(default_factory=dict)
    plugins: Dict[str, Any] = field(default_factory=dict)
    attack_patterns: Dict[str, Any] = field(default_factory=dict)
    mcp: Dict[str, Any] = field(default_factory=dict)
    web_ui: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Config":
        return cls(
            daemon=data.get("daemon", {}),
            queue=data.get("queue", {}),
            scanner=data.get("scanner", {}),
            auto_update=data.get("auto_update", {}),
            health_monitor=data.get("health_monitor", {}),
            plugins=data.get("plugins", {}),
            attack_patterns=data.get("attack_patterns", {}),
            mcp=data.get("mcp", {}),
            web_ui=data.get("web_ui", {}),
        )

    def get(self, key: str, default: Any = None) -> Any:
        """Get nested config value using dot notation"""
        keys = key.split(".")
        value = self.__dict__
        for k in keys:
            if isinstance(value, dict):
                value = value.get(k)
            else:
                return default
            if value is None:
                return default
        return value


def load_config(config_path: str = None) -> Config:
    """Load configuration from YAML file"""
    if config_path is None:
        config_path = os.path.expanduser("~/.config/bbas/bbas-config.yaml")
    
    # Default config
    default_config = Config()
    
    if not os.path.exists(config_path):
        return default_config
    
    try:
        with open(config_path, "r") as f:
            data = yaml.safe_load(f)
        
        if data:
            return Config.from_dict(data)
    except Exception as e:
        print(f"Warning: Failed to load config from {config_path}: {e}")
    
    return default_config


def save_config(config: Config, config_path: str = None):
    """Save configuration to YAML file"""
    if config_path is None:
        config_path = os.path.expanduser("~/.config/bbas/bbas-config.yaml")
    
    Path(config_path).parent.mkdir(parents=True, exist_ok=True)
    
    data = {
        "daemon": config.daemon,
        "queue": config.queue,
        "scanner": config.scanner,
        "auto_update": config.auto_update,
        "health_monitor": config.health_monitor,
        "plugins": config.plugins,
        "attack_patterns": config.attack_patterns,
        "mcp": config.mcp,
        "web_ui": config.web_ui,
    }
    
    with open(config_path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)