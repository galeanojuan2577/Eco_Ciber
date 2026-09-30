#!/usr/bin/env bash
# attack-path.sh — Map attack paths from recon data
set -euo pipefail

TARGET="${1:?Usage: attack-path.sh <target>}"
RECON_DIR="${2:-/tmp/recon-$TARGET}"

echo "=== Attack Path Analysis for $TARGET ==="

if [[ ! -d "$RECON_DIR" ]]; then
  echo "No recon data found at $RECON_DIR. Run recon.sh first." >&2
  exit 1
fi

echo "## Discovered Assets"
[[ -f "$RECON_DIR/subdomains.txt" ]] && echo "Subdomains: $(wc -l < "$RECON_DIR/subdomains.txt")"
[[ -f "$RECON_DIR/resolved.txt" ]] && echo "Resolved: $(wc -l < "$RECON_DIR/resolved.txt")"
[[ -f "$RECON_DIR/httpx.txt" ]] && echo "HTTP services: $(wc -l < "$RECON_DIR/httpx.txt")"
[[ -f "$RECON_DIR/nmap.txt" ]] && echo "Open ports scanned"

echo ""
echo "## Potential Attack Paths"

# Check for common interesting services
if [[ -f "$RECON_DIR/nmap.txt" ]]; then
  echo "### Exposed Services"
  grep -E "(22|ssh|http|https|mysql|ftp|smb|rdp|vnc)" "$RECON_DIR/nmap.txt" 2>/dev/null || echo "  None detected"
fi

# Check for subdomains worth testing
if [[ -f "$RECON_DIR/subdomains.txt" ]]; then
  echo ""
  echo "### High-Value Subdomains"
  grep -iE "(admin|api|dev|staging|test|internal|vpn|mail|git|jenkins|jira)" "$RECON_DIR/subdomains.txt" 2>/dev/null || echo "  None detected"
fi

echo ""
echo "[+] Attack path analysis complete"
