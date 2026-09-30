#!/bin/bash
# ECC Config Drift Checker + Self-Healer
# Compares filesystem agents/skills/commands against opencode.json registrations
# Auto-generates missing registrations

ECC_HOME="__ECC_ROOT__"
OC_CONFIG="$HOME/.config/opencode/opencode.json"
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'
FIX_MODE="${1:-check}"  # check, fix, or report

auto_register_agent() {
    local name="$1"
    local desc="$2"
    python3 -c "
import json
with open('$OC_CONFIG') as f:
    cfg = json.load(f)
if '$name' not in cfg.get('agent', {}):
    cfg.setdefault('agent', {})['$name'] = {
        'description': '$desc',
        'model': 'haiku',
        'subtask': True
    }
    with open('$OC_CONFIG', 'w') as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
    print('✅ Registered: $name')
else:
    print('⏹️ Already registered: $name')
"
}

auto_register_command() {
    local name="$1"
    local desc="$2"
    python3 -c "
import json
with open('$OC_CONFIG') as f:
    cfg = json.load(f)
if '$name' not in cfg.get('command', {}):
    cfg.setdefault('command', {})['$name'] = {
        'description': '$desc',
        'agent': 'build',
        'subtask': True
    }
    with open('$OC_CONFIG', 'w') as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
    print('✅ Registered: $name')
else:
    print('⏹️ Already registered: $name')
"
}

auto_update_soul() {
    local agents="$1" skills="$2" commands="$3"
    sed -i "s/[0-9]\+ agents/$agents agents/" "$ECC_HOME/SOUL.md"
    sed -i "s/[0-9]\+ skills/$skills skills/" "$ECC_HOME/SOUL.md"
    sed -i "s/[0-9]\+ commands/$commands commands/" "$ECC_HOME/SOUL.md"
    echo -e "  ${GREEN}🔧 SOUL.md updated: $agents agents, $skills skills, $commands commands${NC}"
}

echo -e "${CYAN}🔄 ECC Config Health Check${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# --- 1. AGENT REGISTRATION AUDIT ---
echo -e "\n${YELLOW}📋 Agent Registration Audit:${NC}"
MISSING_AGENTS=()
while IFS= read -r agent_file; do
    agent_name=$(basename "$agent_file" .md)
    if ! grep -q "\"$agent_name\"" "$OC_CONFIG" 2>/dev/null; then
        MISSING_AGENTS+=("$agent_name")
        echo -e "  ${RED}❌ Unregistered: $agent_name${NC}"
    fi
done < <(find "$ECC_HOME/agents" -maxdepth 1 -name "*.md" 2>/dev/null)

if [ ${#MISSING_AGENTS[@]} -eq 0 ]; then
    echo -e "  ${GREEN}✅ All agents registered${NC}"
elif [ "$FIX_MODE" = "fix" ]; then
    echo -e "  ${GREEN}🔧 Auto-registering missing agents...${NC}"
    for agent_name in "${MISSING_AGENTS[@]}"; do
        agent_file="$ECC_HOME/agents/$agent_name.md"
        if [ -f "$agent_file" ]; then
            desc=$(head -5 "$agent_file" | grep -oP '(?<=description: ").*(?=")' | head -1)
            desc="${desc:-$agent_name agent}"
            auto_register_agent "$agent_name" "$desc"
        fi
    done
    # Re-count
    MISSING_AGENTS=()
    while IFS= read -r agent_file; do
        agent_name=$(basename "$agent_file" .md)
        if ! grep -q "\"$agent_name\"" "$OC_CONFIG" 2>/dev/null; then
            MISSING_AGENTS+=("$agent_name")
        fi
    done < <(find "$ECC_HOME/agents" -maxdepth 1 -name "*.md" 2>/dev/null)
    if [ ${#MISSING_AGENTS[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✅ All agents now registered${NC}"
    fi
fi

# --- 2. SKILL HEALTH CHECK ---
echo -e "\n${YELLOW}📋 Skill Health Check:${NC}"
SKILL_COUNT=0
BROKEN_SKILLS=0
while IFS= read -r skill_dir; do
    if [ -f "$skill_dir/SKILL.md" ]; then
        SKILL_COUNT=$((SKILL_COUNT + 1))
    else
        echo -e "  ${RED}❌ Missing SKILL.md: $(basename $skill_dir)${NC}"
        BROKEN_SKILLS=$((BROKEN_SKILLS + 1))
    fi
done < <(find "$ECC_HOME/skills" "$HOME/.config/opencode/skills" -maxdepth 1 -type d 2>/dev/null)

echo -e "  ${GREEN}✅ Skills OK: $SKILL_COUNT (${RED}$BROKEN_SKILLS broken${NC})"

# --- 3. COMMAND REGISTRATION AUDIT ---
echo -e "\n${YELLOW}📋 Command Registration Audit:${NC}"
MISSING_COMMANDS=()
while IFS= read -r cmd_file; do
    cmd_name=$(basename "$cmd_file" .md)
    if ! grep -q "\"$cmd_name\"" "$OC_CONFIG" 2>/dev/null; then
        MISSING_COMMANDS+=("$cmd_name")
        echo -e "  ${YELLOW}⚠️  Unregistered: $cmd_name${NC}"
    fi
done < <(find "$ECC_HOME/commands" -maxdepth 1 -name "*.md" 2>/dev/null)

if [ ${#MISSING_COMMANDS[@]} -eq 0 ]; then
    echo -e "  ${GREEN}✅ All commands registered${NC}"
elif [ "$FIX_MODE" = "fix" ]; then
    echo -e "  ${GREEN}🔧 Auto-registering missing commands...${NC}"
    for cmd_name in "${MISSING_COMMANDS[@]}"; do
        cmd_file="$ECC_HOME/commands/$cmd_name.md"
        if [ -f "$cmd_file" ]; then
            desc=$(head -5 "$cmd_file" | grep -oP '(?<=description: ").*(?=")' | head -1)
            desc="${desc:-$cmd_name command}"
            auto_register_command "$cmd_name" "$desc"
        fi
    done
fi

# --- 4. SOUL.md ACCURACY CHECK ---
echo -e "\n${YELLOW}📋 SOUL.md Accuracy:${NC}"
if [ -f "$ECC_HOME/SOUL.md" ]; then
    SOUL_AGENTS=$(grep -oP '\d+ agents' "$ECC_HOME/SOUL.md" 2>/dev/null | grep -oP '\d+')
    SOUL_SKILLS=$(grep -oP '\d+ skills' "$ECC_HOME/SOUL.md" 2>/dev/null | grep -oP '\d+')
    SOUL_COMMANDS=$(grep -oP '\d+ commands' "$ECC_HOME/SOUL.md" 2>/dev/null | grep -oP '\d+')
    ACTUAL_AGENTS=$(find "$ECC_HOME/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
    ACTUAL_SKILLS=$(find "$ECC_HOME/skills" -maxdepth 1 -type d 2>/dev/null | wc -l)
    ACTUAL_COMMANDS=$(find "$ECC_HOME/commands" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
    
    echo -e "  SOUL.md claims: ${SOUL_AGENTS:-?} agents, ${SOUL_SKILLS:-?} skills, ${SOUL_COMMANDS:-?} commands"
    echo -e "  Actual:         ${ACTUAL_AGENTS} agents, ${ACTUAL_SKILLS} skills, ${ACTUAL_COMMANDS} commands"
    
    if [ "$SOUL_AGENTS" != "$ACTUAL_AGENTS" ] || [ "$SOUL_SKILLS" != "$ACTUAL_SKILLS" ]; then
        echo -e "  ${YELLOW}⚠️  SOUL.md needs update!${NC}"
        if [ "$FIX_MODE" = "fix" ]; then
            auto_update_soul "$ACTUAL_AGENTS" "$ACTUAL_SKILLS" "$ACTUAL_COMMANDS"
        fi
    else
        echo -e "  ${GREEN}✅ SOUL.md is accurate${NC}"
    fi
fi

# --- 5. LOADED INSTRUCTIONS AUDIT ---
echo -e "\n${YELLOW}📋 Loaded Instructions Size:${NC}"
TOTAL_KB=0
while IFS= read -r instr_file; do
    if [ -f "$instr_file" ]; then
        KB=$(wc -c < "$instr_file" 2>/dev/null)
        KB=$((KB / 1024))
        TOTAL_KB=$((TOTAL_KB + KB))
        echo -e "  ${CYAN}$instr_file${NC} (${KB}KB)"
    fi
done < <(grep '"instructions"' -A 20 "$OC_CONFIG" 2>/dev/null | grep '"' | grep -oP '"[^"]+\.(md|txt)"' | tr -d '"')

echo -e "  ${YELLOW}Total: ${TOTAL_KB}KB loaded at session start${NC}"

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ ${#MISSING_AGENTS[@]} -gt 0 ] || [ ${#MISSING_COMMANDS[@]} -gt 0 ] || [ $BROKEN_SKILLS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Issues found. Run with 'fix' to auto-remediate:${NC}"
    echo -e "  ${CYAN}$0 fix${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Ecosystem is healthy${NC}"
    exit 0
fi
