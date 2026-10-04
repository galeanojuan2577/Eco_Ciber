#!/usr/bin/env bash
# session-review.sh — Post-session review and learning capture
set -euo pipefail

REVIEW_DIR="__OPENCODE_ROOT__/cyber/learnings"
mkdir -p "$REVIEW_DIR"

DATE=$(date +"%Y-%m-%d")
SESSION_FILE="$REVIEW_DIR/session-$DATE.md"

cat > "$SESSION_FILE" << EOF
# Session Review: $DATE

## What was done
<!-- Describe activities -->

## What worked
<!-- Patterns to reuse -->

## What failed
<!-- Mistakes to avoid -->

## Lessons learned
<!-- New insights -->

## Improvements for next time
<!-- Actionable changes -->
EOF

echo "[+] Session review template created: $SESSION_FILE"
echo "Edit it to capture your session learnings."
