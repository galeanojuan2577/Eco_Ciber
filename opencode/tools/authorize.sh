#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# authorize.sh — Gestión de alcance (SoW) del Ecosistema de Ciberseguridad
# Registra targets autorizados para pruebas ofensivas (hacking ético).
# Uso:
#   authorize.sh status                # ver estado y path
#   authorize.sh list                  # listar targets autorizados
#   authorize.sh add <target> <tipo> [duracion]   # añadir (tipo: recon|scan|enumerate|exploit|post-exploit|dos|phishing)
#   authorize.sh remove <target>       # eliminar target
# ═══════════════════════════════════════════════════════════════

CYBER_DIR="__OPENCODE_ROOT__/cyber"
SCOPE_FILE="$CYBER_DIR/scope.json"

mkdir -p "$CYBER_DIR"

now() { date '+%Y-%m-%dT%H:%M:%S'; }

case "${1:-}" in
  status)
    echo "Scope file: $SCOPE_FILE"
    [ -f "$SCOPE_FILE" ] && cat "$SCOPE_FILE" || echo "(no scope registrado aún)"
    ;;
  list)
    python3 - "$SCOPE_FILE" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("(sin targets autorizados)")
    sys.exit(0)
for t in d.get("targets", []):
    print(f"  {t['target']:<30} tipo={t.get('type','?'):<12} desde={t.get('since','?'):<20} hasta={t.get('until','') or '∞':<22} {t.get('note','')}")
PY
    ;;
  add)
    target="${2:?target requerido}"
    tipo="${3:-all}"
    duracion="${4:-}"
    note="${5:-autorizado por usuario}"
    ts="$(now)"
    # Si existe, refundir
    python3 - "$SCOPE_FILE" "$target" "$tipo" "$duracion" "$ts" "$note" <<'PY'
import json, sys, os
f, target, tipo, dur, ts, note = sys.argv[1:]
d = {"updated": ts, "targets": []}
if os.path.exists(f):
    try:
        d = json.load(open(f))
    except Exception:
        d = {"updated": ts, "targets": []}
for t in d.setdefault("targets", []):
    if t["target"] == target:
        t["type"] = tipo
        t["until"] = dur
        t["note"] = note
        break
else:
    d["targets"].append({"target": target, "type": tipo, "since": ts, "until": dur, "note": note})
json.dump(d, open(f, "w"), indent=2)
PY
    echo "✓ Autorizado: $target (tipo=$tipo) → registrado en scope.json"
    ;;
  remove)
    target="${2:?target requerido}"
    python3 - "$SCOPE_FILE" "$target" <<'PY'
import json, sys, os
f, target = sys.argv[1:]
if os.path.exists(f):
    d = json.load(open(f))
    d["targets"] = [t for t in d.get("targets", []) if t["target"] != target]
    d["updated"] = __import__("datetime").datetime.now().isoformat()
    json.dump(d, open(f, "w"), indent=2)
PY
    echo "✓ Eliminado del scope: $target"
    ;;
  *)
    echo "Uso: authorize.sh {status|list|add <target> <tipo> [duracion]|remove <target>}"
    exit 1
    ;;
esac