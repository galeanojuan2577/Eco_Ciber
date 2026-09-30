#!/usr/bin/env bash
# report.sh — Generate a bug bounty report from findings
set -euo pipefail

PROJECT="${1:?Usage: report.sh <project-name>}"
FINDINGS_DIR="${2:-/tmp/findings}"
OUTPUT="${3:-/tmp/report-${PROJECT}.md}"

cat > "$OUTPUT" << EOF
# Bug Bounty Report: $PROJECT

**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Tester:** opencode
**Status:** Draft

---

## Executive Summary

TODO: Summarize findings and overall risk posture.

## Scope

| Asset | Type | Status |
|-------|------|--------|
| TODO | TODO | In Scope |

## Findings

EOF

if [[ -d "$FINDINGS_DIR" ]]; then
  for f in "$FINDINGS_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    cat "$f" >> "$OUTPUT"
    echo -e "\n---\n" >> "$OUTPUT"
  done
else
  echo "No findings directory at $FINDINGS_DIR" >> "$OUTPUT"
fi

cat >> "$OUTPUT" << 'EOF'
## Remediation Summary

| # | Finding | Severity | Remediation |
|---|---------|----------|-------------|
| TODO | TODO | TODO | TODO |

## Appendix

### Tools Used
- opencode bug bounty framework

### References
- TODO
EOF

echo "[+] Report generated: $OUTPUT"
