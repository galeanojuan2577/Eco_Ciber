#!/usr/bin/env bash
# scan.sh — Run vulnerability scanning against a target
set -euo pipefail

TARGET="${1:?Usage: scan.sh <target> [type]}"
SCAN_TYPE="${2:-quick}"
OUTPUT_DIR="/tmp/scan-${TARGET}-$(date +%s)"
mkdir -p "$OUTPUT_DIR"

echo "=== Scan on $TARGET (type: $SCAN_TYPE) ==="

case "$SCAN_TYPE" in
  quick)
    if command -v nuclei &>/dev/null; then
      echo "[*] nuclei (quick)..."
      echo "$TARGET" | nuclei -severity medium,high,critical -o "$OUTPUT_DIR/nuclei.txt" 2>/dev/null || true
    fi
    if command -v nmap &>/dev/null; then
      echo "[*] nmap vuln scripts..."
      nmap -sV --script vuln -p 80,443,8080,8443 "$TARGET" -oN "$OUTPUT_DIR/nmap-vuln.txt" 2>/dev/null || true
    fi
    ;;
  full)
    if command -v nuclei &>/dev/null; then
      echo "[*] nuclei (full)..."
      echo "$TARGET" | nuclei -o "$OUTPUT_DIR/nuclei-full.txt" 2>/dev/null || true
    fi
    if command -v nikto &>/dev/null; then
      echo "[*] nikto..."
      nikto -h "$TARGET" -o "$OUTPUT_DIR/nikto.txt" -Format txt 2>/dev/null || true
    fi
    ;;
  web)
    if command -v nuclei &>/dev/null; then
      echo "[*] nuclei (web templates)..."
      echo "$TARGET" | nuclei -t http/ -severity medium,high,critical -o "$OUTPUT_DIR/nuclei-web.txt" 2>/dev/null || true
    fi
    if command -v sqlmap &>/dev/null; then
      echo "[*] sqlmap (check mode)..."
      sqlmap -u "https://$TARGET" --batch --level 1 --risk 1 --output-dir="$OUTPUT_DIR/sqlmap" 2>/dev/null || true
    fi
    ;;
esac

echo "[+] Scan complete. Results in $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"
