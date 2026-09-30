#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# ECC Backup Automation
# Crea backup timestamped de opencode.json antes de cambios
# ═══════════════════════════════════════════════════════════════

CONFIG="__OPENCODE_ROOT__/opencode.json"
BACKUP_DIR="__OPENCODE_ROOT__/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

if [ -f "$CONFIG" ]; then
    cp "$CONFIG" "$BACKUP_DIR/opencode.$TIMESTAMP.json"
    # Keep last 10 backups, delete oldest
    ls -t "$BACKUP_DIR"/opencode.*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null
    echo "✅ Backup: opencode.$TIMESTAMP.json ($(wc -c < "$CONFIG") bytes)"
else
    echo "❌ Config not found: $CONFIG"
    exit 1
fi
