#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# ECC Ecosystem + OpenCode - Installer
# Resuelve placeholders __ECC_ROOT__, __OPENCODE_ROOT__, etc.
# ═══════════════════════════════════════════════════════════════

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ECC_SRC="$REPO_DIR/ecc"
OPENCODE_SRC="$REPO_DIR/opencode"
AGENTS_SRC="$REPO_DIR/AGENTS.md"
TARGET_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

echo "═══════════════════════════════════════════════"
echo "  ECC Ecosystem Installer"
echo "═══════════════════════════════════════════════"
echo "  Repo dir : $REPO_DIR"
echo "  ECC src  : $ECC_SRC"
echo "  Config   : $TARGET_CONFIG"
echo "═══════════════════════════════════════════════"

# ── 1. Verificar estructura ──
for d in "$ECC_SRC" "$OPENCODE_SRC"; do
    if [ ! -d "$d" ]; then
        echo "ERROR: $d not found. Run from the Eco_program root."
        exit 1
    fi
done

# ── 2. Backup config existente ──
if [ -d "$TARGET_CONFIG" ] && [ ! -L "$TARGET_CONFIG" ]; then
    BACKUP="${TARGET_CONFIG}.backup.$(date +%s)"
    echo "  Backup: $TARGET_CONFIG → $BACKUP"
    mv "$TARGET_CONFIG" "$BACKUP"
fi

if [ -L "$TARGET_CONFIG" ]; then
    echo "  Removing old symlink: $TARGET_CONFIG"
    rm "$TARGET_CONFIG"
fi

# ── 3. Crear directorio padre y copiar ──
mkdir -p "$(dirname "$TARGET_CONFIG")"
echo "  Copying: $OPENCODE_SRC → $TARGET_CONFIG"
rm -rf "$TARGET_CONFIG"
cp -r "$OPENCODE_SRC" "$TARGET_CONFIG"

# ── 4. Resolver placeholders ──
resolve_placeholders() {
    local file="$1"
    sed -i \
        -e "s|__ECC_ROOT__|$ECC_SRC|g" \
        -e "s|__OPENCODE_ROOT__|$TARGET_CONFIG|g" \
        -e "s|__HOME__|$HOME|g" \
        -e "s|__LOCAL_BIN__|$HOME/.local/bin|g" \
        "$file"
}

echo "  Resolving placeholders..."
# opencode.json
resolve_placeholders "$TARGET_CONFIG/opencode.json"

# tools
for script in "$TARGET_CONFIG/tools/"*.sh; do
    [ -f "$script" ] && resolve_placeholders "$script"
done

# rules
for rule in "$TARGET_CONFIG/rules/"*.md "$TARGET_CONFIG/rules/"*/*.md; do
    [ -f "$rule" ] && resolve_placeholders "$rule"
done

# hookify config
[ -f "$TARGET_CONFIG/hookify.ecc-config.local.md" ] && resolve_placeholders "$TARGET_CONFIG/hookify.ecc-config.local.md"

# ts files in tools
for f in "$TARGET_CONFIG/tools/"*.ts "$TARGET_CONFIG/tools/"*.py; do
    [ -f "$f" ] && resolve_placeholders "$f"
done

# plugins
for f in "$TARGET_CONFIG/plugins/"*/*.py "$TARGET_CONFIG/plugins/"*/*.md "$TARGET_CONFIG/plugins/"*/*.json; do
    [ -f "$f" ] && resolve_placeholders "$f"
done

# commands
for f in "$TARGET_CONFIG/commands/"*.md; do
    [ -f "$f" ] && resolve_placeholders "$f"
done

# skills
for f in "$TARGET_CONFIG/skills/"*/SKILL.md "$TARGET_CONFIG/skills/"*/config.json; do
    [ -f "$f" ] && resolve_placeholders "$f"
done

# ── Blanket cleanup: replace any remaining user-specific paths ──
echo "  Scanning for leftover /home paths..."
grep -rl '/home/' "$TARGET_CONFIG" "$HOME/AGENTS.md" 2>/dev/null | while read -r f; do
    # Only proceed if this user has a different name
    CURRENT_USER=$(whoami)
    sed -i "s|/home/[^/]*/ecc|$ECC_SRC|g; s|/home/[^/]*/\.config/opencode|$TARGET_CONFIG|g; s|/home/[^/]*/\.local/bin|$HOME/.local/bin|g" "$f" 2>/dev/null || true
done

echo "  ✓ Placeholders resolved"

# ── 5. Instalar AGENTS.md ──
if [ -f "$AGENTS_SRC" ]; then
    echo "  Installing AGENTS.md → $HOME/AGENTS.md"
    cp "$AGENTS_SRC" "$HOME/AGENTS.md"
    resolve_placeholders "$HOME/AGENTS.md"
fi

echo "═══════════════════════════════════════════════"
echo "  ✓ ECC Ecosystem installed!"
echo "═══════════════════════════════════════════════"
echo "  Config: $TARGET_CONFIG/opencode.json"
echo "  Next : restart OpenCode session"
echo "═══════════════════════════════════════════════"
