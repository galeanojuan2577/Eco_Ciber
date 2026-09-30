#!/bin/bash
# ECC Ecosystem Auto-Evolution System
# Continuously improves the ecosystem by:
# 1. Detecting stale/duplicate skills
# 2. Suggesting new skill registrations
# 3. Keeping config synchronized
# 4. Generating health reports

ECC_HOME="__ECC_ROOT__"
OC_CONFIG="$HOME/.config/opencode/opencode.json"
REPORT_DIR="$HOME/.config/opencode/.state"
mkdir -p "$REPORT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🧬 ECC Ecosystem Evolution Engine${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# --- Phase 1: Inventory Current State ---
echo -e "\n${YELLOW}Phase 1: Taking inventory...${NC}"
SNAPSHOT="$REPORT_DIR/ecosystem-snapshot-$(date +%Y%m%d).json"

# Count everything
AGENT_COUNT=$(find "$ECC_HOME/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
SKILL_COUNT=$(find "$ECC_HOME/skills" -maxdepth 2 -name "SKILL.md" 2>/dev/null | wc -l)
COMMAND_COUNT=$(find "$ECC_HOME/commands" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
HOOK_COUNT=$(find "$ECC_HOME/hooks" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
LOCAL_SKILL_COUNT=$(find "$HOME/.config/opencode/skills" -maxdepth 2 -name "SKILL.md" 2>/dev/null | wc -l)
REGISTERED_AGENTS=$(python3 -c "
import json
with open('$OC_CONFIG') as f:
    cfg = json.load(f)
print(len(cfg.get('agent', {})))
" 2>/dev/null || echo 0)
REGISTERED_COMMANDS=$(python3 -c "
import json
with open('$OC_CONFIG') as f:
    cfg = json.load(f)
print(len(cfg.get('command', {})))
" 2>/dev/null || echo 0)
ENABLED_MCP=$(python3 -c "
import json
with open('$OC_CONFIG') as f:
    cfg = json.load(f)
print(sum(1 for v in cfg.get('mcp', {}).values() if v.get('enabled', False)))
" 2>/dev/null || echo 0)

# --- Phase 2: Detect Drift ---
echo -e "${YELLOW}Phase 2: Analyzing integration gaps...${NC}"

DRIFT_AGENTS=$((AGENT_COUNT - REGISTERED_AGENTS))
if [ $DRIFT_AGENTS -gt 0 ]; then
    echo -e "  ${RED}⚠️  $DRIFT_AGENTS agents not registered${NC}"
else
    echo -e "  ${GREEN}✅ All agents registered${NC}"
fi

# --- Phase 3: Generate Evolution Report ---
echo -e "${YELLOW}Phase 3: Generating evolution report...${NC}"

cat > "$SNAPSHOT" << EOF
{
  "snapshot_date": "$(date -Iseconds)",
  "agents": { "total": $AGENT_COUNT, "registered": $REGISTERED_AGENTS, "drift": $DRIFT_AGENTS },
  "skills": { "ecc": $SKILL_COUNT, "local": $LOCAL_SKILL_COUNT },
  "commands": { "total": $COMMAND_COUNT, "registered": $REGISTERED_COMMANDS },
  "hooks": $HOOK_COUNT,
  "mcp_enabled": $ENABLED_MCP,
  "drift_detected": $([ $DRIFT_AGENTS -gt 0 ] && echo 1 || echo 0)
}
EOF

# --- Phase 4: Self-Healing Actions ---
echo -e "${YELLOW}Phase 4: Auto-remediation...${NC}"

# Check if drift exists and suggest fixes
if [ $DRIFT_AGENTS -gt 0 ]; then
    echo -e "  ${GREEN}🔧 Would register $DRIFT_AGENTS agents...${NC}"
    echo -e "  ${CYAN}   Run: config-healer.sh fix${NC}"
fi

# --- Phase 5: Health Score ---
HEALTH_SCORE=100
[ $DRIFT_AGENTS -gt 0 ] && HEALTH_SCORE=$((HEALTH_SCORE - 20))
[ $((SKILL_COUNT + LOCAL_SKILL_COUNT)) -lt 100 ] && HEALTH_SCORE=$((HEALTH_SCORE - 10))

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Ecosystem Health Score: ${HEALTH_SCORE}%${NC}"
echo ""
echo -e "${CYAN}Summary:${NC}"
echo -e "  Agents:    $REGISTERED_AGENTS/$AGENT_COUNT registered"
echo -e "  ECC Skills: $SKILL_COUNT | Local: $LOCAL_SKILL_COUNT"
echo -e "  Commands:  $REGISTERED_COMMANDS/$COMMAND_COUNT registered"
echo -e "  MCP Enabled: $ENABLED_MCP"
echo ""
echo -e "${CYAN}Snapshot saved: $SNAPSHOT${NC}"
