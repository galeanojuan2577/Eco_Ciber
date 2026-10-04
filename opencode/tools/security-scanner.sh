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

# La configuración de OpenCode NO suele estar en el directorio escaneado
# (OpenCode usa ~/.config/opencode/opencode.json como config global). Sin esta
# resolución, los chequeos 4 y 5 se saltaban en silencio por no encontrar
# el fichero y reportaban "0 issues" sin haber mirado nada.
CONFIG="$SCAN_DIR/opencode.json"
if [ ! -f "$CONFIG" ]; then
    CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json"
fi
[ -f "$CONFIG" ] || CONFIG=""

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
    local config="$CONFIG"
    [ -n "$config" ] || return 0
    if [ -f "$config" ]; then
        local servers=$(grep -oP '"command":\s*\[\s*"npx"[^\]]*\]' "$config" 2>/dev/null | head -5)
        if [ -n "$servers" ]; then
            echo -e "${YELLOW}ℹ️  npx MCP servers (verify trust):${NC}"
            echo "$servers" | sed 's/^/   /'
        fi
    fi
}

# Pattern 5: Permission audit (OpenCode V2)
# En V2 la clave correcta es `permission` (singular); `permissions` (plural)
# es sintaxis V1 que el runtime IGNORA en silencio. Un MCP quedaría sin
# restricción alguna, asi que se comprueba la clave Y su contenido.
# El catch-all `"*": "ask"` cubre tambien las herramientas MCP, cuyos nombres
# reales varian segun el servidor.
check_permissions() {
    local config="$CONFIG"
    if [ -z "$config" ]; then
        echo -e "${YELLOW}⚠️  No se encontró opencode.json (ni en $SCAN_DIR ni global)${NC}"
        ISSUES=$((ISSUES + 1))
        return 0
    fi
    echo -e "${CYAN}ℹ️  Auditoría de permisos sobre: $config${NC}"
    if grep -q '"permissions"\s*:' "$config" 2>/dev/null; then
        echo -e "${RED}❌ 'permissions' (V1) presente: el runtime V2 lo IGNORA${NC}"
        ISSUES=$((ISSUES + 1))
        return 0
    fi
    if python3 - "$config" <<'PYPERM'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
p = d.get("permission")
if p is None:
    sys.exit(1)
if p == "ask":
    sys.exit(0)
if isinstance(p, dict) and p.get("*") in ("ask", "deny"):
    sys.exit(0)
# acepta tambien MCP declarados uno a uno
mcp = d.get("mcp") or {}
servers = mcp.get("servers", mcp)
if isinstance(p, dict) and servers and all(p.get(s) in ("ask", "deny") for s in servers):
    sys.exit(0)
sys.exit(1)
PYPERM
    then
        echo -e "${GREEN}✅ permission: MCP bajo 'ask' (V2, efectivo)${NC}"
    else
        echo -e "${YELLOW}⚠️  permission sin cobertura 'ask' para MCP (o clave V1)${NC}"
        ISSUES=$((ISSUES + 1))
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
