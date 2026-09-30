#!/usr/bin/env bash
# recon.sh — Run recon on a target (subdomains, ports, tech fingerprint)
set -euo pipefail

TARGET="${1:?Usage: recon.sh <target>}"
OUTPUT_DIR="${2:-/tmp/recon-$TARGET}"
mkdir -p "$OUTPUT_DIR"

echo "=== Recon on $TARGET ==="

# Subdomain enumeration
if command -v subfinder &>/dev/null; then
  echo "[*] subfinder..."
  subfinder -d "$TARGET" -silent -o "$OUTPUT_DIR/subdomains.txt" 2>/dev/null || true
fi

# DNS resolution
if command -v dnsx &>/dev/null && [[ -f "$OUTPUT_DIR/subdomains.txt" ]]; then
  echo "[*] dnsx..."
  dnsx -l "$OUTPUT_DIR/subdomains.txt" -silent -o "$OUTPUT_DIR/resolved.txt" 2>/dev/null || true
fi

# Port scanning (top ports only)
if command -v nmap &>/dev/null; then
  echo "[*] nmap..."
  nmap -sV --top-ports 1000 -oN "$OUTPUT_DIR/nmap.txt" "$TARGET" 2>/dev/null || true
fi

# Technology fingerprint
if command -v whatweb &>/dev/null; then
  echo "[*] whatweb..."
  whatweb --color=never "$TARGET" > "$OUTPUT_DIR/whatweb.txt" 2>&1 || true
fi

# HTTP probing
if command -v httpx &>/dev/null && [[ -f "$OUTPUT_DIR/resolved.txt" ]]; then
  echo "[*] httpx..."
  httpx -l "$OUTPUT_DIR/resolved.txt" -silent -o "$OUTPUT_DIR/httpx.txt" 2>/dev/null || true
fi

echo "[+] Recon complete. Results in $OUTPUT_DIR"
ls -la "$OUTPUT_DIR"
