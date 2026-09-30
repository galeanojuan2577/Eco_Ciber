#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# ECC INIT — ARRANQUE AUTOMÁTICO DEL ECOSISTEMA
# Se ejecuta SIEMPRE al inicio de cada sesión.
# NO SALTARSE. NO OPCIONAL. NO SKIP.
# ═══════════════════════════════════════════════════════════════

ECOSYSTEM_ROOT="__ECC_ROOT__"
CONFIG_DIR="__OPENCODE_ROOT__"
LEARNINGS_DIR="$CONFIG_DIR/_data/learnings"
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     🧬 ECC ECOSYSTEM — INIT SEQUENCE           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ─── Step 1: Security Scan ─────────────────────────────
echo -e "${BOLD}[1/5] 🔍 Security Scan${NC}"
bash "$CONFIG_DIR/tools/security-scanner.sh" "$CONFIG_DIR"
SECURITY_EXIT=$?
echo ""

# ─── Step 2: Project Detection ─────────────────────────
echo -e "${BOLD}[2/5] 📋 Project Detection${NC}"
bash "$CONFIG_DIR/tools/project-detect.sh" "$PWD"
echo ""

# ─── Step 3: Backup Config ──────────────────────────
echo -e "${BOLD}[3/5] 💾 Backup Config${NC}"
"$CONFIG_DIR/tools/backup-config.sh"
echo ""

# ─── Step 4: Load Mistakes Log ─────────────────────────
echo -e "${BOLD}[4/5] 📖 Loading Previous Learnings${NC}"
if [ -f "$LEARNINGS_DIR/mistakes-log.md" ]; then
    MISTAKES=$(grep -c "^### \[2" "$LEARNINGS_DIR/mistakes-log.md" 2>/dev/null || true)
    echo -e "  📕 Mistakes logged: $MISTAKES"
    echo -e "  📗 Patterns logged: $(grep -c "^### \[2" "$LEARNINGS_DIR/patterns-log.md" 2>/dev/null || true)"
fi
echo ""

# ─── Step 5: Config Health ─────────────────────────────
echo -e "${BOLD}[5/5] 🩺 Config Health${NC}"
"$CONFIG_DIR/tools/config-healer.sh" check 2>&1 | tail -5
echo ""

# ─── FINAL: MANDATORY INSTRUCTIONS FOR THE AI ──────────
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ⚡ INSTRUCCIONES OBLIGATORIAS — LEER AHORA    ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}1. CARGAR SKILLS:${NC}"
echo "   Usa el tool 'skill' para cargar CADA UNA de las skills listadas arriba en SKILLS_TO_LOAD."
echo "   No continúes sin cargarlas."
echo ""
echo -e "${BOLD}2. LEER APRENDIZAJES:${NC}"
echo "   Lee ambos archivos antes de cualquier tarea:"
echo "   - $LEARNINGS_DIR/mistakes-log.md"
echo "   - $LEARNINGS_DIR/patterns-log.md"
echo ""
echo -e "${BOLD}3. AUTO-EVALUACIÓN POST-TAREA:${NC}"
echo "   Después de CADA tarea no-trivial, ejecuta session-review y auto-evalúate."
echo "   Si cometiste un error → REGISTRALO en mistakes-log.md."
echo "   Si descubriste un patrón → REGISTRALO en patterns-log.md."
echo ""
echo -e "${BOLD}4. NUNCA SALTAR ESTOS PASOS.${NC}"
echo "   Son obligatorios. El ecosistema mejora con cada sesión."
echo ""

if [ $SECURITY_EXIT -ne 0 ]; then
    echo -e "${RED}⚠️  Security scan encontró issues. Reportarlos al usuario.${NC}"
fi
