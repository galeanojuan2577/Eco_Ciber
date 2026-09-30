# BBAS - Bug Bounty Analysis System

A comprehensive bug bounty assistance system with **unlimited scope scanning**, **real-time web UI**, **MCP integration**, and **auto-maintenance**.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        BBAS System                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   WEB UI     │    │  MCP SERVER  │    │    CLI       │      │
│  │  (React +    │    │  (opencode   │    │  (bbas-cli)  │      │
│  │   Tailwind)  │    │   integration)│    │              │      │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘      │
│         │                   │                   │               │
│         ▼                   ▼                   ▼               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    BBAS DAEMON                            │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐         │   │
│  │  │ Task Queue  │ │ Workers     │ │ SQLite      │         │   │
│  │  │ (SQLite)    │ │ (Recon/Scan)│ │ (State/Findings)        │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘         │   │
│  └──────────────────────────────────────────────────────────┘   │
│         │                   │                   │               │
│         ▼                   ▼                   ▼               │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              EXTERNAL TOOLS & ECOSYSTEM                   │   │
│  │  subfinder, httpx, nuclei, zaproxy, nikto, gobuster,      │   │
│  │  amass, nmap, dnsrecon, check-scope.sh, authorize.sh      │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Web UI (React + TypeScript + Tailwind)
- **Dashboard** - Overview of targets, findings, attack paths, sessions
- **Recon** - Launch scans with real-time progress
- **Findings** - Prioritized vulnerability findings with filters
- **Attack Paths** - Map exploitation chains
- **Targets** - Discovered targets with scoring
- **Sessions** - Scan session history with work unit details
- **Settings** - Project management, scope configuration, tool verification

### 2. Daemon (Python FastAPI)
- **Task Queue** - SQLite-based with checkpointing and recovery
- **Worker Pool** - Configurable concurrent workers (Recon/Scan/Enum)
- **Rate Limiting** - Per-domain adaptive rate limiting
- **Scope Enforcement** - Integrates with `check-scope.sh` for every action
- **Auto-Update** - Weekly updates for nuclei templates, tools, wordlists
- **Health Monitor** - Disk space, tool availability, queue stuck detection

### 3. MCP Server (opencode Integration)
- `bbas_list_projects` - List all projects
- `bbas_create_project` - Create new project
- `bbas_get_scope` / `bbas_add_scope_target` - Scope management
- `bbas_start_scan` - Launch scans
- `bbas_get_findings` / `bbas_add_finding` - Findings management
- `bbas_get_attack_paths` - Attack path analysis
- `bbas_get_sessions` / `bbas_get_targets` - Session & target data
- `bbas_get_stats` - System statistics

### 4. CLI (bbas-cli)
```bash
# Project management
bbas project create "acme-corp" --program-url https://hackerone.com/acme
bbas project list

# Scope management
bbas scope add "*.acme.com" --type recon,scan
bbas scope list
bbas scope check "api.acme.com" --type scan

# Scanning
bbas scan recon "api.acme.com" "web.acme.com" --deep
bbas scan vuln "api.acme.com"
bbas scan enum "api.acme.com"

# Findings
bbas findings list --min-severity high --tech react
bbas findings add --target api.acme.com --type vuln --severity high --title "IDOR" --description "..."

# Attack paths
bbas paths list
bbas paths create --name "IDOR → ATO" --steps '[{"title":"Exploit IDOR","technique":"idor"}]'

# Sessions
bbas session list
bbas session show 123

# Workers
bbas worker start --workers 10 --types recon,scan

# Recon triage (hunting mode)
bbas triage example.com,test.example.com --consent
```

## Quick Start

### 1. Install Dependencies
```bash
# System tools (Kali/Ubuntu)
sudo apt install subfinder httpx nuclei zaproxy nikto gobuster amass nmap dnsrecon

# Python dependencies
pip install -r requirements.txt

# Web UI
cd ~/.config/bbas/web-ui && npm install && npm run build
```

### 2. Configure Project
```bash
# Set active project
export CYBER_PROJECT=acme-corp

# Or use CLI
bbas project create "acme-corp" --program-url https://hackerone.com/acme
bbas scope add "*.acme.com" --type all
```

### 3. Start Daemon
```bash
# Development
python ~/.config/bbas/bbas-daemon.py --reload --log-level DEBUG

# Production (systemd)
sudo systemctl start bbas-daemon
```

### 4. Access Web UI
Open http://localhost:8080

### 5. Configure opencode MCP
Add to `~/.config/opencode/opencode.json`:
```json
{
  "mcp": {
    "bbas": {
      "type": "local",
      "command": ["python", "-m", "bbas_mcp"],
      "enabled": true,
      "timeout": 300000
    }
  }
}
```

## Key Features

### Unlimited Scope Scanning
- No hardcoded caps (50 subdomains, 100 nuclei hosts, etc.)
- Streaming/chunking for massive scopes
- Backpressure handling with disk spillover
- Resumable scans with SQLite checkpoints

### Real-Time Web UI
- Live scan progress via Server-Sent Events
- Interactive attack path graphs
- Findings table with inline editing
- Target scoring with false alarm detection

### Auto-Maintenance
- Weekly nuclei template updates
- Tool version updates (subfinder, nuclei, httpx, etc.)
- Wordlist updates from SecLists/Assetnote
- Health monitoring with alerts

### Ecosystem Integration
- `check-scope.sh` enforced on EVERY work unit
- `authorize.sh` for scope management
- `audit-log.sh` for complete traceability
- `project-context.sh` for project isolation
- `recon-triage.sh` for pre-engagement hunting
- Compatible with existing ECC agents (recon-agent, scanner-agent, etc.)

## Project Structure
```
~/.config/bbas/
├── bbas-config.yaml          # Main configuration
├── bbas.db                   # SQLite database
├── bbas-daemon.py            # Daemon entry point
├── bbas-cli.py               # CLI entry point
├── web-ui/                   # React frontend (built)
├── core/                     # Python core
│   ├── api/                  # FastAPI routes
│   ├── models/               # Database models
│   ├── queue/                # Task queue
│   ├── workers/              # Worker implementations
│   ├── scanners/             # Tool wrappers
│   └── utils/                # Config, scope, logging
├── mcp/                      # MCP server
│   └── server.py
├── plugins/                  # Custom plugins
├── wordlists/                # Cached wordlists
├── nuclei-templates/         # Cached nuclei templates
└── logs/                     # Log files
```

## Requirements
- Python 3.10+
- Node.js 18+ (for web UI build)
- System tools: subfinder, httpx, nuclei, zaproxy, nikto, gobuster, amass, nmap, dnsrecon
- SQLite (included with Python)
- Redis (optional, for distributed queue)

## License
MIT