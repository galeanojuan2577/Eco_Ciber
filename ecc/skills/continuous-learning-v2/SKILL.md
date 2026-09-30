---
name: continuous-learning-v2
description: Instinct-based learning system that observes sessions via hooks, creates atomic
metadata:
  origin: ECC
version: 2.1.0
---

# Continuous Learning v2.1 - Instinct-Based Architecture

An advanced learning system that turns your Claude Code sessions into reusable knowledge through atomic "instincts" - small learned behaviors with confidence scoring.

**v2.1** adds **project-scoped instincts** — React patterns stay in your React project, Python conventions stay in your Python project, and universal patterns (like "always validate input") are shared globally.

## When to Activate

- Setting up automatic learning from Claude Code sessions
- Configuring instinct-based behavior extraction via hooks
- Tuning confidence thresholds for learned behaviors
- Reviewing, exporting, or importing instinct libraries
- Evolving instincts into full skills, commands, or agents
- Managing project-scoped vs global instincts

## The Instinct Model

An instinct is a small learned behavior:

```yaml
---
id: prefer-functional-style
trigger: "when writing new functions"
confidence: 0.7
domain: "code-style"
source: "session-observation"
scope: project
project_id: "a1b2c3d4e5f6"
---

# Prefer Functional Style
## Action
Use functional patterns over classes when appropriate.
## Evidence
- Observed 5 instances of functional pattern preference
```

**Properties:** Atomic (one trigger, one action), confidence-weighted (0.3-0.9), domain-tagged, evidence-backed, scope-aware (project/global).

## How It Works

```
Session Activity (hooks capture prompts + tool use)
  → projects/<project-hash>/observations.jsonl
  → Observer agent reads (background, Haiku)
  → PATTERN DETECTION (user corrections, errors, repeated workflows)
  → projects/<hash>/instincts/personal/*.yaml (project-scoped)
  → instincts/personal/*.yaml (global)
  → /evolve clusters → skills/commands/agents
```

## Quick Start

### 1. Enable Observation Hooks

**If installed as plugin** (recommended): No extra settings.json hook block required. Claude Code v2.1+ auto-loads plugin hooks.

**If installed manually** to `~/.claude/skills`, add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "*",
      "hooks": [{"type": "command", "command": "~/.claude/skills/continuous-learning-v2/hooks/observe.sh"}]
    }],
    "PostToolUse": [{
      "matcher": "*",
      "hooks": [{"type": "command", "command": "~/.claude/skills/continuous-learning-v2/hooks/observe.sh"}]
    }]
  }
}
```

### 2. Initialize Directory Structure

```bash
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/ecc-homunculus"/{instincts/{personal,inherited},evolved/{agents,skills,commands},projects}
```

### 3. Use the Commands

- `/instinct-status` — Show learned instincts (project + global)
- `/evolve` — Cluster related instincts into skills/commands
- `/instinct-export` — Export instincts to file
- `/instinct-import <file>` — Import instincts
- `/promote [id]` — Promote project instincts to global
- `/projects` — List all known projects

## Scope Decision Guide

| Pattern Type | Scope | Examples |
|---|---|---|
| Language/framework conventions | project | "Use React hooks", "Follow Django patterns" |
| File structure preferences | project | "Tests in `__tests__/`" |
| Code style | project | "Use functional style" |
| Security practices | global | "Validate user input" |
| General best practices | global | "Write tests first" |
| Tool workflow preferences | global | "Grep before Edit" |

## Confidence Scoring

| Score | Meaning | Behavior |
|---|---|---|
| 0.3 | Tentative | Suggested but not enforced |
| 0.5 | Moderate | Applied when relevant |
| 0.7 | Strong | Auto-approved for application |
| 0.9 | Near-certain | Core behavior |

**Increases** when: pattern repeatedly observed, user doesn't correct, similar instincts agree.
**Decreases** when: user corrects, pattern not observed for extended periods, contradicting evidence.

## Configuration

Edit `config.json` to control the background observer:

```json
{
  "version": "2.1",
  "observer": {
    "enabled": false,
    "run_interval_minutes": 5,
    "min_observations_to_analyze": 20
  }
}
```

## Data Directory

Continuous-learning-v2 stores observer data outside `~/.claude`:
1. `CLV2_HOMUNCULUS_DIR` env var (highest priority)
2. `$XDG_DATA_HOME/ecc-homunculus`
3. `$HOME/.local/share/ecc-homunculus`

## Project Detection

1. `CLAUDE_PROJECT_DIR` env var (highest priority)
2. `git remote get-url origin` — hashed to create portable project ID
3. `git rev-parse --show-toplevel` — fallback using repo path
4. Global fallback — no project detected → global scope

## File Structure

```
${XDG_DATA_HOME:-~/.local/share}/ecc-homunculus/
├── identity.json           # Your profile, technical level
├── projects.json           # Registry: project hash -> name/path/remote
├── observations.jsonl      # Global observations (fallback)
├── instincts/personal/     # Global auto-learned instincts
├── instincts/inherited/    # Global imported instincts
├── evolved/{agents,skills,commands}/
└── projects/<hash>/
    ├── project.json        # Per-project metadata
    ├── observations.jsonl
    ├── instincts/personal/ # Project-specific
    ├── instincts/inherited/
    └── evolved/{skills,commands,agents}/
```

## Promoting Instincts (Project → Global)

When the same instinct appears in 2+ projects with average confidence ≥ 0.8, it qualifies for global promotion:

```bash
python3 instinct-cli.py promote prefer-explicit-errors   # specific
python3 instinct-cli.py promote                          # auto-promote all
python3 instinct-cli.py promote --dry-run                # preview
```

## Why Hooks vs Skills for Observation?

Hooks fire **100% of the time**, deterministically. Skills fire ~50-80% based on Claude's judgment. Hooks ensure no patterns are missed.

## Privacy

- Observations stay **local** on your machine
- Project-scoped instincts are isolated per project
- Only **instincts** (patterns) can be exported — not raw observations
- No actual code or conversation content is shared

## Backward Compatibility

v2.1 is fully compatible with v2.0 and v1. Existing global instincts can be migrated with `scripts/migrate-homunculus.sh`.

## Related

- [ECC-Tools GitHub App](https://github.com/apps/ecc-tools) — Generate instincts from repo history
- Homunculus — Community project that inspired the v2 instinct-based architecture
- [The Longform Guide](https://x.com/affaanmustafa/status/2014040193557471352) — Continuous learning section
