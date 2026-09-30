#!/usr/bin/env bash
# scope.sh — Parse bug bounty scope from programs.json
set -euo pipefail

PROJECT="${1:?Usage: scope.sh <project-name>}"
PROGRAMS_FILE="${2:-/root/.config/opencode/cyber/programs.json}"

if [[ ! -f "$PROGRAMS_FILE" ]]; then
  echo "Error: programs.json not found at $PROGRAMS_FILE" >&2
  exit 1
fi

python3 -c "
import json, sys
with open('$PROGRAMS_FILE') as f:
    programs = json.load(f)
if '$PROJECT' not in programs:
    print(f'Project not found. Available: {list(programs.keys())}', file=sys.stderr)
    sys.exit(1)
p = programs['$PROJECT']
print(f\"=== Scope for {$PROJECT} ===\")
print(f\"Platform: {p.get('platform','?')}\")
print(f\"URL: {p.get('url','?')}\")
print()
for t in p.get('in_scope', []):
    print(f\"  [IN]  {t['type']}: {t['target']}\")
for t in p.get('out_of_scope', []):
    print(f\"  [OUT] {t['type']}: {t['target']}\")
"
