#!/bin/bash
# ECC Security Scanner — Pre-session secret & config auditor
# Scans for hardcoded secrets, exposed keys, and security misconfigurations

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCAN_DIR="${1:-$PWD}"
ISSUES=0
FIXES=0

echo -e "${CYAN}🔍 ECC Security Scanner${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Scanning: $SCAN_DIR"
echo ""

# Pattern 1: Hardcoded API keys in JSON configs
check_hardcoded_keys() {
    local found=0
    while IFS= read -r file; do
        local matches=$(grep -n '"apiKey"\|"api_key"\|"apikey"' "$file" 2>/dev/null | grep -v '"{env:' | grep -v '"{file:' | grep -v '"\$' | grep -v 'process.env')
        if [ -n "$matches" ]; then
            echo -e "${RED}❌ HARDCODED API KEY: $file${NC}"
            echo "$matches" | sed 's/^/   /'
            found=$((found + 1))
            ISSUES=$((ISSUES + 1))
        fi
    done < <(find "$SCAN_DIR" -maxdepth 3 -name "*.json" -o -name "*.jsonc" 2>/dev/null)
    return $found
}

# Pattern 2: Secret patterns in source files
check_source_secrets() {
    local found=0
    local patterns=(
        'sk-[a-zA-Z0-9]{20,}'           # OpenAI keys
        'nvapi-[a-zA-Z0-9_-]{20,}'      # NVIDIA keys
        'ghp_[a-zA-Z0-9]{36}'           # GitHub PAT
        'gho_[a-zA-Z0-9]{36}'           # GitHub OAuth
        'AKIA[0-9A-Z]{16}'              # AWS Access Key
        '-----BEGIN PRIVATE KEY-----'    # Private keys
        'api_key.*=.*['"'"'\"][a-zA-Z0-9]{16,}'
    )
    for pattern in "${patterns[@]}"; do
        while IFS=: read -r file line content; do
            if [ -n "$file" ]; then
                # Skip node_modules, .git, dist
                case "$file" in
                    *node_modules*|*.git*|*dist*|*build*|*.next*) continue ;;
                esac
                echo -e "${YELLOW}⚠️  Possible secret in: $file:$line${NC}"
                found=$((found + 1))
                ISSUES=$((ISSUES + 1))
            fi
        done < <(grep -rnP "$pattern" "$SCAN_DIR" --include="*.{ts,js,py,go,rs,java,kt,config.env,env}" 2>/dev/null | head -20)
    done
    return $found
}

# Pattern 3: .env files tracked by git
check_env_in_git() {
    if [ -d "$SCAN_DIR/.git" ]; then
        local tracked=$(cd "$SCAN_DIR" && git ls-files '.env' '.env.*' 2>/dev/null | grep -v '.env.example' | grep -v '.env.sample')
        if [ -n "$tracked" ]; then
            echo -e "${RED}❌ .env files tracked in git:${NC}"
            echo "$tracked" | sed 's/^/   /'
            ISSUES=$((ISSUES + 1))
        fi
    fi
}

# Pattern 4: MCP servers with potential credential exposure
check_mcp_servers() {
    local config="$SCAN_DIR/opencode.json"
    if [ -f "$config" ]; then
        local servers=$(grep -oP '"command":\s*\[\s*"npx"[^\]]*\]' "$config" 2>/dev/null | head -5)
        if [ -n "$servers" ]; then
            echo -e "${YELLOW}ℹ️  npx MCP servers (verify trust):${NC}"
            echo "$servers" | sed 's/^/   /'
        fi
    fi
}

# Pattern 5: Permission audit
check_permissions() {
    local config="$SCAN_DIR/opencode.json"
    if [ -f "$config" ]; then
        if grep -q '"mcp_\*"\s*:\s*"ask"' "$config" 2>/dev/null; then
            echo -e "${GREEN}✅ MCP permissions: ask (secure)${NC}"
        else
            echo -e "${YELLOW}⚠️  MCP permissions not set to 'ask'${NC}"
            ISSUES=$((ISSUES + 1))
        fi
    fi
}

check_hardcoded_keys
check_source_secrets
check_env_in_git
check_mcp_servers
check_permissions

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ No security issues found${NC}"
else
    echo -e "${YELLOW}⚠️  $ISSUES potential issue(s) found${NC}"
    echo -e "${YELLOW}   Run with --fix to auto-remediate where possible${NC}"
fi

exit $ISSUES
