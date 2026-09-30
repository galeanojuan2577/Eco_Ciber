#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# ECOSISTEMA DE CIBERSEGURIDAD - TEST SUITE
# Valida TODO el ecosistema de un tirón
# ═══════════════════════════════════════════════════════════════

CONFIG_DIR="__OPENCODE_ROOT__"
ECC_HOME="__ECC_ROOT__"
OC_CONFIG="$CONFIG_DIR/opencode.json"
PASS=0
FAIL=0
TOTAL=0

red='\033[0;31m'; green='\033[0;32m'; cyan='\033[0;36m'; bold='\033[1m'; nc='\033[0m'

check() {
    TOTAL=$((TOTAL + 1))
    local name="$1" cmd="$2"
    echo -ne "  [..] $name"
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "\r  ${green}[PASS]${nc} $name"
        PASS=$((PASS + 1))
    else
        echo -e "\r  ${red}[FAIL]${nc} $name"
        FAIL=$((FAIL + 1))
    fi
}

echo -e "${cyan}╔══════════════════════════════════════════════════╗${nc}"
echo -e "${cyan}║  🧪 ECOSISTEMA DE CIBERSEGURIDAD TEST SUITE     ║${nc}"
echo -e "${cyan}╚══════════════════════════════════════════════════╝${nc}"
echo ""

echo -e "${bold}1. ESTRUCTURA BÁSICA${nc}"
check "opencode.json existe y es válido" \
    "python3 -c \"import json; json.load(open('$OC_CONFIG'))\""
check "Directorio de herramientas tools/ existe" \
    "[ -d '$CONFIG_DIR/tools' ]"
check "Directorio de skills locales existe" \
    "[ -d '$CONFIG_DIR/skills' ]"
check "Directorio de learnings existe" \
    "[ -d '$CONFIG_DIR/_data/learnings' ]"

echo ""
echo -e "${bold}2. AGENTES${nc}"
check "Carpeta agents/ tiene archivos" \
    "[ \$(find '$ECC_HOME/agents' -name '*.md' | wc -l) -gt 60 ]"
check "Cada agente en config tiene su archivo" \
    "python3 -c \"
import json, os
cfg = json.load(open('$OC_CONFIG'))
ok = True
for a in cfg.get('agent', {}):
    if a != 'build' and not os.path.exists('$ECC_HOME/agents/'+a+'.md'):
        ok = False
print(ok)
\""

echo ""
echo -e "${bold}3. SKILLS${nc}"
check "Skills ECC tienen SKILL.md" \
    "[ \$(find '$ECC_HOME/skills' -maxdepth 2 -name 'SKILL.md' | wc -l) -gt 250 ]"
check "Skills locales tienen SKILL.md" \
    "[ \$(find '$CONFIG_DIR/skills' -maxdepth 2 -name 'SKILL.md' | wc -l) -ge 10 ]"
check "Sin skills rotas (directorio sin SKILL.md)" \
    "python3 -c \"
import os
bad = [d for d in os.listdir('$ECC_HOME/skills') if os.path.isdir('$ECC_HOME/skills/'+d) and not os.path.exists('$ECC_HOME/skills/'+d+'/SKILL.md')]
print(len(bad) == 0)
\""

echo ""
echo -e "${bold}4. COMANDOS${nc}"
check "Comandos registrados en config" \
    "[ \$(python3 -c \"import json; c=json.load(open('$OC_CONFIG')); print(len(c.get('command',{})))\") -ge 90 ]"

echo ""
echo -e "${bold}5. INSTRUCCIONES${nc}"
check "Todas las instrucciones existen" \
    "python3 -c \"
import json, os
cfg = json.load(open('$OC_CONFIG'))
for i in cfg.get('instructions', []):
    if isinstance(i, str) and not os.path.exists(i):
        raise SystemExit(1)
print('ok')
\""
check "Tamaño total < 100KB" \
    "python3 -c \"
import json, os
cfg = json.load(open('$OC_CONFIG'))
total = sum(os.path.getsize(i)//1024 for i in cfg.get('instructions', []) if isinstance(i, str) and os.path.exists(i))
print(total < 100)
\""

echo ""
echo -e "${bold}6. MCP SERVERS${nc}"
check "5 MCP servers enabled" \
    "[ \$(python3 -c \"import json; c=json.load(open('$OC_CONFIG')); print(sum(1 for v in c.get('mcp',{}).values() if v.get('enabled')))\") -ge 5 ]"

echo ""
echo -e "${bold}7. HERRAMIENTAS CUSTOM${nc}"
for tool in ecc-init.sh security-scanner.sh project-detect.sh config-healer.sh ecosystem-evolve.sh session-review.sh ecc-test.sh; do
    check "Herramienta $tool ejecutable" "[ -x '$CONFIG_DIR/tools/$tool' ]"
done

echo ""
echo -e "${bold}8. SECURITY${nc}"
check "Sin secrets en config dir" \
    "bash '$CONFIG_DIR/tools/security-scanner.sh' '$CONFIG_DIR' 2>&1 | grep -q 'No security issues found'"

echo ""
echo -e "${bold}9. ECOSYSTEM HEALTH${nc}"
check "Health score 100%" \
    "bash '$CONFIG_DIR/tools/ecosystem-evolve.sh' 2>&1 | grep -q 'Health Score: 100%'"

echo ""
echo -e "${bold}10. PERSISTENCIA${nc}"
check "mistakes-log.md existe" \
    "[ -f '$CONFIG_DIR/_data/learnings/mistakes-log.md' ]"
check "patterns-log.md existe" \
    "[ -f '$CONFIG_DIR/_data/learnings/patterns-log.md' ]"
check "Backup config existe" \
    "[ -f '$CONFIG_DIR/opencode.json.bak' ]"

echo ""
echo "═══════════════════════════════════════════════"
echo -e "  ${bold}Resultados:${nc} ${green}$PASS passed${nc}, ${red}$FAIL failed${nc}, $TOTAL total"
if [ $FAIL -eq 0 ]; then
    echo -e "  ${green}✅ ALL TESTS PASSED${nc}"
else
    echo -e "  ${red}❌ $FAIL TEST(S) FAILED${nc}"
fi
echo "═══════════════════════════════════════════════"
exit $FAIL
