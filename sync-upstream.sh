#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Sync Upstream ECC
# Trae los últimos cambios del ECC upstream (affaan-m/ECC)
# y actualiza ecc/ en este repo preservando nuestras personalizaciones
# ═══════════════════════════════════════════════════════════════

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ECC_DIR="$REPO_DIR/ecc"
TMP_DIR="/tmp/ecc-upstream-$$"
UPSTREAM_REPO="https://github.com/affaan-m/ECC.git"

echo "═══════════════════════════════════════════════"
echo "  Sync Upstream ECC"
echo "═══════════════════════════════════════════════"

# ── 1. Clonar upstream ──
echo "  Cloning upstream: $UPSTREAM_REPO"
git clone --depth 1 "$UPSTREAM_REPO" "$TMP_DIR" 2>&1 | tail -1
echo "  ✓ Cloned"

# ── 2. Sync files (excluyendo .git y node_modules) ──
echo "  Syncing ecc/..."
rsync -a --delete \
    --exclude=.git \
    --exclude=node_modules \
    "$TMP_DIR/" "$ECC_DIR/"

echo "  ✓ ecc/ synced"

# ── 3. Re-aplicar placeholders en archivos synced ──
# (porque upstream no usa placeholders)
echo "  Re-applying placeholders..."
for f in $(find "$ECC_DIR" -name "*.md" -o -name "*.json" -o -name "*.sh" 2>/dev/null); do
    # Solo si tiene paths absolutos de upstream
    if grep -q "/home/" "$f" 2>/dev/null; then
        sed -i \
            -e 's|/home/diego/ecc|__ECC_ROOT__|g' \
            -e 's|/home/[^/]*/ecc|__ECC_ROOT__|g' \
            -e 's|/home/diego/ecc-plus|__ECC_PLUS__|g' \
            -e 's|/home/[^/]*/ecc-plus|__ECC_PLUS__|g' \
            "$f" 2>/dev/null || true
    fi
done
echo "  ✓ Placeholders re-applied"

# ── 4. Limpiar ──
rm -rf "$TMP_DIR"

echo "═══════════════════════════════════════════════"
echo "  ✓ Sync complete!"
echo "  Now review changes, then commit:"
echo "    git diff --stat"
echo "    git add -A"
echo "    git commit -m 'sync: upstream ECC changes'"
echo "═══════════════════════════════════════════════"
