#!/usr/bin/env bash
# check-scope.sh — Check if a target is in scope before testing
set -euo pipefail

TARGET="${1:?Usage: check-scope.sh <target>}"
PROJECT="${2:-}"
PROGRAMS_FILE="${3:-/root/.config/opencode/cyber/programs.json}"

if [[ ! -f "$PROGRAMS_FILE" ]]; then
  echo "⚠ programs.json not found. Cannot verify scope." >&2
  echo "Always confirm scope manually before testing." >&2
  exit 1
fi

echo "=== Scope Check: $TARGET ==="

python3 -c "
import json, sys
target = '$TARGET'
with open('$PROGRAMS_FILE') as f:
    programs = json.load(f)

for name, p in programs.items():
    for t in p.get('in_scope', []):
        scope_target = t['target']
        if target == scope_target or target.endswith('.' + scope_target) or '*' in scope_target:
            print(f'[IN SCOPE] {target} matches {scope_target} in project {name}')
            sys.exit(0)
    for t in p.get('out_of_scope', []):
        scope_target = t['target']
        if target == scope_target or target.endswith('.' + scope_target) or '*' in scope_target:
            print(f'[OUT OF SCOPE] {target} matches {scope_target} in project {name}')
            sys.exit(1)

print(f'[NOT FOUND] {target} not found in any scope file')
print('Only test targets explicitly confirmed in scope.')
sys.exit(1)
" || {
  echo ""
  echo "⚠ STOP — Target may be out of scope."
  echo "  Get explicit authorization before testing."
  exit 1
}
