#!/usr/bin/env bash
# cleanup.sh — Clean up temporary files and tools
set -euo pipefail

TARGET="${1:-}"
echo "=== Cleanup ==="

if [[ -n "$TARGET" ]]; then
  echo "Cleaning recon data for $TARGET..."
  rm -rf "/tmp/recon-$TARGET"* "/tmp/scan-$TARGET"*
  echo "[+] Cleaned for $TARGET"
else
  echo "Cleaning all temporary recon/scan data..."
  rm -rf /tmp/recon-* /tmp/scan-* /tmp/findings /tmp/report-*.md
  echo "[+] All temp data cleaned"
fi
