#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# verify-ecosystem.sh — Ecosistema Eco_Ciber · OpenCode V2
#
# Valida el REPO (con placeholders, sin rutas de la máquina) y, con
# --instalado, también la instalación viva en ~/.config/opencode.
#
# Uso:
#   ./verify-ecosystem.sh              # sólo el repo
#   ./verify-ecosystem.sh --instalado  # repo + instalación viva
# ═══════════════════════════════════════════════════════════════════
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ECC_DIR="$REPO_DIR/ecc"
OPENCODE_DIR="$REPO_DIR/opencode"
INSTALLED=0
[ "${1:-}" = "--instalado" ] && INSTALLED=1

PASS=0; FAIL=0; TOTAL=0
red='\033[0;31m'; green='\033[0;32m'; cyan='\033[0;36m'; bold='\033[1m'; nc='\033[0m'

check() {
    TOTAL=$((TOTAL + 1))
    local name="$1" cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        printf '\r  %b[PASS]%b %s\n' "$green" "$nc" "$name"
        PASS=$((PASS + 1))
    else
        printf '\r  %b[FAIL]%b %s\n' "$red" "$nc" "$name"
        FAIL=$((FAIL + 1))
    fi
}

# conteo -> comprueba que es >= a un mínimo
count_check() {
    local name="$1" min="$2" got="$3"
    if [ "$got" -ge "$min" ] 2>/dev/null; then
        check "$name ($got >= $min)" "true"
    else
        check "$name ($got >= $min)" "false"
    fi
}

echo -e "${cyan}╔══════════════════════════════════════════════╗${nc}"
echo -e "${cyan}║  Ecosistema Eco_Ciber · OpenCode V2 · verify ║${nc}"
echo -e "${cyan}╚══════════════════════════════════════════════╝${nc}"
echo "  repo: $REPO_DIR"

# ── 1. Estructura del repo ────────────────────────────────────────────
echo -e "\n${bold}📁 Estructura del repo${nc}"
check "AGENTS.md existe"          "test -f '$REPO_DIR/AGENTS.md'"
check "README.md existe"          "test -f '$REPO_DIR/README.md'"
check ".gitignore existe"         "test -f '$REPO_DIR/.gitignore'"
check "eco-install.sh existe"     "test -f '$REPO_DIR/eco-install.sh'"
check "verify-ecosystem.sh existe" "test -f '$REPO_DIR/verify-ecosystem.sh'"
check "CI workflow existe"        "test -f '$REPO_DIR/.github/workflows/ci.yml'"
check "opencode/opencode.json"    "test -f '$OPENCODE_DIR/opencode.json'"
check "opencode/agents/"          "test -d '$OPENCODE_DIR/agents'"
check "opencode/skills/"          "test -d '$OPENCODE_DIR/skills'"
check "opencode/commands/"        "test -d '$OPENCODE_DIR/commands'"
check "opencode/tools/"           "test -d '$OPENCODE_DIR/tools'"
check "opencode/rules/cyber/"     "test -d '$OPENCODE_DIR/rules/cyber'"
check "opencode/templates/"       "test -d '$OPENCODE_DIR/templates'"
check "ecc/skills/ (upstream)"    "test -d '$ECC_DIR/skills'"
check "recon/ (motor de recon)"   "test -f '$REPO_DIR/recon/recon_pro.sh' && test -f '$REPO_DIR/recon/bbrecon.sh'"

# ── 2. Cobertura V2 (cifras que declara AGENTS.md) ────────────────────
echo -e "\n${bold}📊 Cobertura${nc}"
N_AGENTS=$(find "$OPENCODE_DIR/agents"    -maxdepth 1 -name '*.md' 2>/dev/null | wc -l)
N_SKILL=$(find "$OPENCODE_DIR/skills"      -maxdepth 2 -name 'SKILL.md' 2>/dev/null | wc -l)
N_ECC=$(find "$ECC_DIR/skills"           -maxdepth 2 -name 'SKILL.md' 2>/dev/null | wc -l)
N_CMD=$(find "$OPENCODE_DIR/commands"     -name '*.md' 2>/dev/null | wc -l)
N_TOOLS=$(find "$OPENCODE_DIR/tools"      -maxdepth 1 -type f 2>/dev/null | wc -l)
N_SH=$(find "$OPENCODE_DIR/tools"         -maxdepth 1 -name '*.sh' 2>/dev/null | wc -l)
N_RULES=$(find "$OPENCODE_DIR/rules/cyber" -name '*.md' 2>/dev/null | wc -l)
N_TPL=$(find "$OPENCODE_DIR/templates"    -name '*.md' 2>/dev/null | wc -l)

count_check "agentes"      81 "$N_AGENTS"
count_check "skills ciber" 166 "$N_SKILL"
count_check "skills ecc"   271 "$N_ECC"
count_check "comandos /pentest/*" 11 "$N_CMD"
count_check "tools"        26 "$N_TOOLS"
count_check "tools .sh"    20 "$N_SH"
count_check "reglas permanentes (rules/cyber)" 7 "$N_RULES"
count_check "plantillas de informe" 6 "$N_TPL"

# ── 3. Config V2 ──────────────────────────────────────────────────────
echo -e "\n${bold}⚙️  opencode.json (V2)${nc}"
check "JSON válido" "python3 -c \"import json,sys; json.load(open(sys.argv[1]))\" '$OPENCODE_DIR/opencode.json'"
check "sin claves V1 (permissions / providers, ignoradas por V2)" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));sys.exit(1 if (\"permissions\" in d or \"providers\" in d) else 0)' '$OPENCODE_DIR/opencode.json'"
check "clave provider (singular)" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if \"provider\" in d else 1)' '$OPENCODE_DIR/opencode.json'"
check "clave permission (singular)" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if d.get(\"permission\") else 1)' '$OPENCODE_DIR/opencode.json'"
check "permission: catch-all ask (herramientas MCP protegidas)" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));p=d.get(\"permission\");sys.exit(0 if p==\"ask\" or (isinstance(p,dict) and p.get(\"*\") in (\"ask\",\"deny\")) else 1)' '$OPENCODE_DIR/opencode.json'"
check "clave model" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if d.get(\"model\") else 1)' '$OPENCODE_DIR/opencode.json'"
check "skills es objeto con paths (2 rutas)" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));s=d.get(\"skills\");p=(s or {}).get(\"paths\") if isinstance(s,dict) else None;sys.exit(0 if p and len(p)==2 and any(\"skills-ecc\" in x for x in p) else 1)' '$OPENCODE_DIR/opencode.json'"
check "mcp en forma plana (schema, sin wrapper servers)" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));m=d.get(\"mcp\") or {};sys.exit(0 if m and \"servers\" not in m else 1)' '$OPENCODE_DIR/opencode.json'"
check "7 MCPs declarados" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));m=d.get(\"mcp\") or {};sys.exit(0 if len(m)==7 else 1)' '$OPENCODE_DIR/opencode.json'"
check "los 7 MCPs esperados" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));m=set(d.get(\"mcp\") or {});e={\"sequential-thinking\",\"memory\",\"filesystem\",\"playwright\",\"agent-browser\",\"chrome-devtools\",\"context7\"};sys.exit(0 if m==e else 1)' '$OPENCODE_DIR/opencode.json'"
check "3 MCPs de contexto desactivados (agent-browser, chrome-devtools, filesystem)" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));m=d.get(\"mcp\") or {};e={\"agent-browser\",\"chrome-devtools\",\"filesystem\"};sys.exit(0 if all(m.get(k,{}).get(\"enabled\") is False for k in e) else 1)' '$OPENCODE_DIR/opencode.json'"
check "4 MCPs activos (playwright, memory, sequential-thinking, context7)" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));m=d.get(\"mcp\") or {};e={\"playwright\",\"memory\",\"sequential-thinking\",\"context7\"};sys.exit(0 if all(m.get(k,{}).get(\"enabled\", True) is True for k in e) else 1)' '$OPENCODE_DIR/opencode.json'"
check "compaction+tool_output activos (auto/prune/tail_turns/max_bytes)" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));c=d.get(\"compaction\") or {};t=d.get(\"tool_output\") or {};sys.exit(0 if c.get(\"auto\") is True and c.get(\"prune\") is True and c.get(\"tail_turns\")==4 and t.get(\"max_lines\")==800 and t.get(\"max_bytes\")==20000 else 1)' '$OPENCODE_DIR/opencode.json'"
check "ninguna description de skill >200 car" \
  "python3 '$REPO_DIR/verify-descriptions.py' skill '$OPENCODE_DIR/skills' '$OPENCODE_DIR/skills-ecc' '$REPO_DIR/ecc/skills'"
check "ninguna description de agente >150 car" \
  "python3 '$REPO_DIR/verify-descriptions.py' agent '$OPENCODE_DIR/agents'"
check "todas las claves raíz existen en el esquema V2" \
  "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));k={\"agent\",\"attachment\",\"autoshare\",\"autoupdate\",\"command\",\"compaction\",\"default_agent\",\"disabled_providers\",\"enabled_providers\",\"enterprise\",\"experimental\",\"formatter\",\"instructions\",\"layout\",\"logLevel\",\"lsp\",\"mcp\",\"mode\",\"model\",\"permission\",\"plugin\",\"provider\",\"reference\",\"references\",\"server\",\"share\",\"shell\",\"skills\",\"small_model\",\"snapshot\",\"subagent_depth\",\"tool_output\",\"tools\",\"username\",\"watcher\"};k.add(chr(36)+\"schema\");x=set(d)-k;sys.exit(0 if not x else 1)' '$OPENCODE_DIR/opencode.json'"


# ── 4. Frontmatter de agentes y comandos ──────────────────────────────
echo -e "\n${bold}📝 Frontmatter${nc}"
check "los 81 agentes tienen frontmatter y mode" \
  "python3 -c \"
import pathlib,sys,re
d=pathlib.Path(sys.argv[1]); bad=[]
for p in sorted(d.glob('*.md')):
    t=p.read_text(encoding='utf-8',errors='replace')
    if not t.startswith('---'): bad.append(p.name+':sin---'); continue
    fm=t.split('---',2)[1]
    if not re.search(r'^mode:\s*\S', fm, re.M): bad.append(p.name+':sin-mode')
    if not re.search(r'^description:\s*\S', fm, re.M): bad.append(p.name+':sin-desc')
print(bad); sys.exit(0 if not bad else 1)\" '$OPENCODE_DIR/agents'"
check "los 11 comandos tienen frontmatter válido" \
  "python3 -c \"
import pathlib,sys
d=pathlib.Path(sys.argv[1]); bad=[]
for p in sorted(d.rglob('*.md')):
    t=p.read_text(encoding='utf-8',errors='replace')
    if not t.startswith('---'): bad.append(str(p)); continue
    try:
        import yaml
        yaml.safe_load(t.split('---',2)[1])
    except ImportError:
        pass
    except Exception as e:
        bad.append(f'{p}:{e}')
print(bad); sys.exit(0 if not bad else 1)\" '$OPENCODE_DIR/commands'"
# OpenCode descubre los skills por frontmatter: sin `name`/`description` el
# skill existe en disco pero NUNCA aparece listado (así se detectaron 3 de
# ciberseguridad que daban 434/437 descubribles).
check "los 437 skills tienen frontmatter (name + description)" \
  "python3 -c \"
import pathlib,sys,re
bad=[]
for tree in sys.argv[1:]:
    d=pathlib.Path(tree)
    if not d.is_dir(): continue
    for p in sorted(d.rglob('SKILL.md')):
        t=p.read_text(encoding='utf-8',errors='replace')
        fm=t.split('---',2)[1] if t.startswith('---') and t.count('---',2)>=1 else ''
        if not (re.search(r'^name:\s*\S',fm,re.M) and re.search(r'^description:\s*\S',fm,re.M)):
            bad.append(p.parent.name)
print(bad); sys.exit(0 if not bad else 1)\" '$OPENCODE_DIR/skills' '$REPO_DIR/ecc/skills'"

# ── 5. Integridad de placeholders ─────────────────────────────────────
echo -e "\n${bold}🔤 Placeholders${nc}"
# Superficie instalable: todo lo que eco-install.sh copia o ejecuta.
# Se excluye la propia frase de AGENTS.md que prohíbe usar /home/diego,
# y ecc/ (fork de upstream) que arrastra sus propias rutas heredadas.
INST="$REPO_DIR/AGENTS.md $OPENCODE_DIR/opencode.json $OPENCODE_DIR/agents $OPENCODE_DIR/commands $OPENCODE_DIR/rules $OPENCODE_DIR/skills $REPO_DIR/recon"
check "sin /home/diego en la superficie instalable" \
  "! grep -rn '/home/diego' $INST 2>/dev/null | grep -v 'escribas rutas'"
check "sin /root/.config en la superficie instalable" \
  "! grep -rn '/root/.config' $INST 2>/dev/null"
check "sin typo Bugbonty en la superficie instalable" \
  "! grep -rn 'Bugbonty' $INST 2>/dev/null"
# Informativo: BBAS (mcp-servers/bbas) NO se instala y arrastra rutas
# heredadas de su upstream (/root/Bugbonty). Se documenta, no se toca.
check "mcp-servers/bbas excluido del alcance (no se instala)" \
  "test -d '$REPO_DIR/mcp-servers/bbas' && ! grep -q 'bbas' '$OPENCODE_DIR/opencode.json'"
check "placeholders presentes en opencode.json" \
  "grep -q '__OPENCODE_ROOT__' '$OPENCODE_DIR/opencode.json'"
check "placeholders presentes en AGENTS.md" \
  "grep -q '__OPENCODE_ROOT__' '$REPO_DIR/AGENTS.md' && grep -q '__HOME__' '$REPO_DIR/AGENTS.md'"
check "skills-ecc referenciado en AGENTS.md §12" \
  "grep -q '__OPENCODE_ROOT__/skills-ecc' '$REPO_DIR/AGENTS.md'"
check "sin referencias vivas al clon en AGENTS.md" \
  "! grep -q '__ECC_ROOT__/skills' '$REPO_DIR/AGENTS.md'"
# Todo recurso citado en AGENTS.md / skills / rules / commands que apunte a
# __OPENCODE_ROOT__ debe existir de verdad en el repo. Sin esto, un skill puede
# invocar un tool que nadie instaló (así se detectó el caso de
# cyber-tools-installed.sh, citado por pentest-flow-detail pero ausente).
check "sin referencias cruzadas rotas a tools/rules/skills" \
  "python3 -c 'import pathlib,re,sys;r=pathlib.Path(sys.argv[1]);o=pathlib.Path(sys.argv[2]);P=(\"tools/\",\"rules/\",\"commands/\",\"skills/\",\"skills-ecc/\");fs=[r/\"AGENTS.md\"]+list((o/\"skills\").rglob(\"*.md\"))+list((o/\"rules\").rglob(\"*.md\"))+list((o/\"commands\").rglob(\"*.md\"));B=sorted({rel for p in fs if p.is_file() for rel in re.findall(r\"__OPENCODE_ROOT__/([A-Za-z0-9._/-]+\.(?:sh|md|json|ts|py))\",p.read_text(encoding=\"utf-8\",errors=\"replace\")) if rel.startswith(P) and not (o/rel).exists()});print(\"   rotas:\",B or \"ninguna\");sys.exit(1 if B else 0)' '$REPO_DIR' '$OPENCODE_DIR'"

# ── 6. Sintaxis de todos los scripts ──────────────────────────────────
echo -e "\n${bold}🧪 Sintaxis de los scripts${nc}"
BAD_SCRIPTS=""
while IFS= read -r f; do
    bash -n "$f" 2>/dev/null || BAD_SCRIPTS="$BAD_SCRIPTS ${f#$REPO_DIR/}"
done < <(find "$OPENCODE_DIR/tools" "$REPO_DIR/recon" -maxdepth 1 -name '*.sh' -type f 2>/dev/null)
bash -n "$REPO_DIR/eco-install.sh" 2>/dev/null || BAD_SCRIPTS="$BAD_SCRIPTS eco-install.sh"
bash -n "$REPO_DIR/verify-ecosystem.sh" 2>/dev/null || BAD_SCRIPTS="$BAD_SCRIPTS verify-ecosystem.sh"
if [ -z "$BAD_SCRIPTS" ]; then
    check "todos los .sh pasan bash -n ($((N_SH + 2)) scripts)" "true"
else
    check "todos los .sh pasan bash -n -> rotos:$BAD_SCRIPTS" "false"
fi

# ── 7. Gate de autorización ───────────────────────────────────────────
echo -e "\n${bold}🔒 Gate de autorización${nc}"
for t in check-scope.sh scope.sh authorize.sh audit-log.sh project-context.sh; do
    check "tools/$t existe" "test -f '$OPENCODE_DIR/tools/$t'"
done
check "check-scope.sh sin args -> exit 3" \
  "bash '$OPENCODE_DIR/tools/check-scope.sh' >/dev/null 2>&1; [ \$? -eq 3 ]"
check "check-scope.sh -h responde" \
  "bash '$OPENCODE_DIR/tools/check-scope.sh' -h >/dev/null 2>&1 || true"

# ── 8. Instalación viva (opcional) ────────────────────────────────────
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
if [ "$INSTALLED" -eq 1 ]; then
    echo -e "\n${bold}🏠 Instalación viva ($DEST)${nc}"
    check "opencode.json instalado" "test -f '$DEST/opencode.json'"
    check "sin placeholders sin resolver" \
      "! grep -rq '__OPENCODE_ROOT__\|__ECC_ROOT__\|__LOCAL_BIN__' '$DEST/opencode.json' '$DEST/AGENTS.md' 2>/dev/null"
    check "service.json existe (nunca se toca)" "test -f '$DEST/service.json'"
    D_AG=$(find "$DEST/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l)
    D_SK=$(find "$DEST/skills" -maxdepth 2 -name 'SKILL.md' 2>/dev/null | wc -l)
    D_EC=$(find "$DEST/skills-ecc" -maxdepth 2 -name 'SKILL.md' 2>/dev/null | wc -l)
    D_CM=$(find "$DEST/commands" -name '*.md' 2>/dev/null | wc -l)
    count_check "instalado: agentes" 81 "$D_AG"
    count_check "instalado: skills ciber" 166 "$D_SK"
    count_check "instalado: skills ecc" 271 "$D_EC"
    count_check "instalado: comandos" 11 "$D_CM"
    check "instalado: recon ejecutable" "test -x '$HOME/.local/bin/recon'"
    check "instalado: bbrecon ejecutable" "test -x '$HOME/.local/bin/bbrecon'"
    check "instalado: ~/.local/bin/recon sin placeholders" \
      "! grep -q '__OPENCODE_ROOT__\|__HOME__\|Bugbonty' '$HOME/.local/bin/recon' 2>/dev/null"
    check "instalado: espacio ~/BugBounty" "test -d '$HOME/BugBounty'"
    check "instalado: opencode.json válido" \
      "python3 -c \"import json,sys; json.load(open(sys.argv[1]))\" '$DEST/opencode.json'"
    check "instalado: sin claves V1 (permissions / providers)" \
      "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));sys.exit(1 if (\"permissions\" in d or \"providers\" in d) else 0)' '$DEST/opencode.json'"
    check "instalado: permission con catch-all ask" \
      "python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));p=d.get(\"permission\");sys.exit(0 if p==\"ask\" or (isinstance(p,dict) and p.get(\"*\") in (\"ask\",\"deny\")) else 1)' '$DEST/opencode.json'"
    check "instalado: skills.paths -> 2 rutas resueltas" \
      "python3 -c 'import json,sys,os;d=json.load(open(sys.argv[1]));p=(d.get(\"skills\") or {}).get(\"paths\") or [];sys.exit(0 if len(p)==2 and all(os.path.isdir(os.path.expanduser(x)) for x in p) else 1)' '$DEST/opencode.json'"
fi

# ── Resumen ───────────────────────────────────────────────────────────
echo ""
echo -e "${cyan}══════════════════════════════════════════════════${nc}"
if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${green}✅ TODAS LAS $TOTAL COMPROBACIONES OK${nc}"
else
    echo -e "  ${red}❌ $FAIL/$TOTAL FALLAN${nc}"
fi
echo -e "  agentes=$N_AGENTS · skills=$N_SKILL+$N_ECC · comandos=$N_CMD · tools=$N_TOOLS · reglas=$N_RULES · plantillas=$N_TPL"
echo -e "${cyan}══════════════════════════════════════════════════${nc}"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
