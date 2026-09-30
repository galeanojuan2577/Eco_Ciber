#!/usr/bin/env python3
"""BBAS Daemon Entry Point"""
import sys
import os
import signal
import argparse
from pathlib import Path

# Add core to path
sys.path.insert(0, str(Path(__file__).parent))

import uvicorn
from core.api.main import create_app
from core.utils.config import load_config
from core.utils.logger import setup_logging, get_logger


logger = get_logger(__name__)


def get_port_from_env() -> int:
    """Get port from environment variable BBAS_PORT, fallback to config default"""
    port_env = os.environ.get("BBAS_PORT")
    if port_env:
        try:
            return int(port_env)
        except ValueError:
            logger.warning(f"Invalid BBAS_PORT value: {port_env}, ignoring")
    return None


def main():
    parser = argparse.ArgumentParser(description="BBAS Daemon - Bug Bounty Analysis System")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind")
    parser.add_argument("--port", type=int, default=None, help="Port to bind (overrides config/env)")
    parser.add_argument("--config", help="Config file path")
    parser.add_argument("--log-level", default="INFO", help="Log level")
    parser.add_argument("--log-file", help="Log file path")
    parser.add_argument("--workers", type=int, help="Number of worker processes")
    parser.add_argument("--reload", action="store_true", help="Enable auto-reload")
    args = parser.parse_args()

    # Setup logging
    setup_logging(args.log_level, args.log_file)

    # Load config
    config = load_config(args.config)

    # Determine port with priority: CLI > ENV > Config > Default(9000)
    port = args.port
    if port is None:
        port = get_port_from_env()
    if port is None:
        port = config.daemon.get("port", 9000)

    # Override config with determined values
    config.daemon["host"] = args.host or config.daemon.get("host", "127.0.0.1")
    config.daemon["port"] = port
    if args.workers:
        config.daemon["workers"] = args.workers

    # Create app
    app = create_app(config)

    # Run server
    logger.info(f"Starting BBAS daemon on {config.daemon['host']}:{config.daemon['port']}")
    
    uvicorn.run(
        app,
        host=config.daemon["host"],
        port=config.daemon["port"],
        log_level=args.log_level.lower(),
        reload=args.reload,
        workers=1,  # Use 1 process, workers are managed internally
    )


if __name__ == "__main__":
    main()