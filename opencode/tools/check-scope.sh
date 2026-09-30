#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# check-scope.sh — Gate de autorización FLEXIBLE del Ecosistema de Ciberseguridad
# Verifica si un target está autorizado para un tipo de test ofensivo.
#
# Exit codes:
#   0 → target autorizado en scope (proceder)
#   1 → target NO en scope → REQUIERE confirmación del usuario (gate flexible)
#   2 → target fuera de alcance permanente / ilegal → rechazado
#
# Uso: check-scope.sh <target> <tipo> [--force]
#   --force → override manual del usuario (consentimiento registrado); procede
# ═══════════════════════════════════════════════════════════════

CYBER_DIR="__OPENCODE_ROOT__/cyber"
SCOPE_FILE="$CYBER_DIR/scope.json"

target="${1:-}"
tipo="${2:-all}"
force="${3:-}"

if [ -z "$target" ]; then
    echo "Uso: check-scope.sh <target> <tipo:recon|scan|enumerate|exploit|post-exploit|dos|phishing> [--force]"
    exit 2
fi

authorized=0
if [ -f "$SCOPE_FILE" ]; then
    authorized=$(python3 - "$SCOPE_FILE" "$target" "$tipo" <<'PY'
import json, sys
f, target, tipo = sys.argv[1:]
try:
    d = json.load(open(f))
except Exception:
    print(0); sys.exit()
found = 0
for t in d.get("targets", []):
    if t["target"] == target and (t["type"] == "all" or t["type"] == tipo or tipo == "all"):
        found = 1; break
print(found)
PY
)
fi

if [ "$authorized" = "1" ]; then
    echo "🟢 Autorizado en scope (target=$target, tipo=$tipo). Procediendo..."
    bash "$CYBER_DIR/../tools/audit-log.sh" "check-scope OK: $target ($tipo)"
    exit 0
fi

if [ "$force" = "--force" ]; then
    echo "🟡 Override del usuario (consentimiento): registrando y procediendo con $target ($tipo)"
    bash "$CYBER_DIR/../tools/audit-log.sh" "check-scope FORCE-OVERRIDE usuario: $target ($tipo)"
    exit 0
fi

echo "🔴 $target NO está en el scope autorizado (tipo=$tipo)."
echo "   Gate FLEXIBLE: ¿el usuario confirma que esta acción es LEGAL y con CONSENTIMIENTO?"
echo "   → SI: responder sí con --force, o registrar con: authorize.sh add $target $tipo"
echo "   → NO: abortar la acción."
exit 1