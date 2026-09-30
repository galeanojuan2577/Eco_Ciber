#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Verify Ecosystem
# Valida la integridad del ECOSISTEMA DE CIBERSEGURIDAD LOCALMENTE
# ═══════════════════════════════════════════════════════════════

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ECC_DIR="$REPO_DIR/ecc"
OPENCODE_DIR="$REPO_DIR/opencode"
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

echo -e "${cyan}╔══════════════════════════════════════════════╗${nc}"
echo -e "${cyan}║  🔍 ECOSISTEMA DE CIBERSEGURIDAD - VERIF.    ║${nc}"
echo -e "${cyan}╚══════════════════════════════════════════════╝${nc}"

# ── Structure ──
echo -e "\n${bold}📁 Structure${nc}"
check "ECC root exists"   "test -d '$ECC_DIR'"
check "OpenCode exists"   "test -d '$OPENCODE_DIR'"
check "AGENTS.md exists"  "test -f '$REPO_DIR/AGENTS.md'"
check "install.sh exists" "test -f '$REPO_DIR/install.sh'"
check "CI workflow exists" "test -f '$REPO_DIR/.github/workflows/ci.yml'"
check "README.md exists"  "test -f '$REPO_DIR/README.md'"
check ".gitignore exists" "test -f '$REPO_DIR/.gitignore'"

# ── ECC Core Directories ──
echo -e "\n${bold}📂 ECC Core${nc}"
check "agents/ exists"      "test -d '$ECC_DIR/agents' && ls '$ECC_DIR/agents' | wc -l | xargs test 10 -le"
check "skills/ exists"      "test -d '$ECC_DIR/skills' && ls '$ECC_DIR/skills' | wc -l | xargs test 50 -le"
check "commands/ exists"    "test -d '$ECC_DIR/commands'"
check "hooks/ exists"       "test -d '$ECC_DIR/hooks'"
check "rules/ exists"       "test -d '$ECC_DIR/rules'"
check "scripts/ exists"     "test -d '$ECC_DIR/scripts'"
check "tests/ exists"       "test -d '$ECC_DIR/tests'"

# ── OpenCode Config ──
echo -e "\n${bold}⚙️  OpenCode Config${nc}"
check "opencode.json exists" "test -f '$OPENCODE_DIR/opencode.json'"
check "tools/ exists"        "test -d '$OPENCODE_DIR/tools'"
check "skills/ exists"       "test -d '$OPENCODE_DIR/skills'"
check "rules/ exists"        "test -d '$OPENCODE_DIR/rules'"
check "plugins/ exists"      "test -d '$OPENCODE_DIR/plugins'"

# ── Placeholder Validation ──
echo -e "\n${bold}🔤 Placeholder Integrity${nc}"
check "No /home/diego in opencode.json"     "! grep -q '/home/diego' '$OPENCODE_DIR/opencode.json'"
check "No /home/diego in AGENTS.md"         "! grep -q '/home/diego' '$REPO_DIR/AGENTS.md'"
check "No /home/diego in tools/"            "! grep -q '/home/diego' '$OPENCODE_DIR/tools/'*"
check "No /home/diego in rules/"            "! grep -q '/home/diego' '$OPENCODE_DIR/rules/'*.md"
check "No /home/diego in plugins/"          "! grep -q '/home/diego' '$OPENCODE_DIR/plugins/'*"
check "No /home/diego in commands/"         "! grep -q '/home/diego' '$OPENCODE_DIR/commands/'*.md"
check "No /home/diego in skills/"           "! grep -q '/home/diego' '$OPENCODE_DIR/skills/'*"
check "Placeholders present" "grep -q '__ECC_ROOT__\|__OPENCODE_ROOT__\|__HOME__\|__LOCAL_BIN__' '$OPENCODE_DIR/opencode.json'"

# ── Skills integrity ──
echo -e "\n${bold}🧠 Skills${nc}"
ECC_SKILLS=$(ls "$ECC_DIR/skills" 2>/dev/null | wc -l)
OPENCODE_SKILLS=$(ls "$OPENCODE_DIR/skills" 2>/dev/null | wc -l)
check "ECC skills >= 200" "test $ECC_SKILLS -ge 200"
check "OpenCode skills >= 5"  "test $OPENCODE_SKILLS -ge 5"

# ── Agents ──
echo -e "\n${bold}🤖 Agents${nc}"
AGENTS_COUNT=$(ls "$ECC_DIR/agents" 2>/dev/null | wc -l)
check "Agents >= 50" "test $AGENTS_COUNT -ge 50"

# ── Summary ──
echo ""
echo -e "${cyan}══════════════════════════════════════════════${nc}"
if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${green}✅ ALL $TOTAL CHECKS PASSED${nc}"
else
    echo -e "  ${red}❌ $FAIL/$TOTAL FAILED${nc}"
fi
echo -e "${cyan}══════════════════════════════════════════════${nc}"
exit $FAIL
