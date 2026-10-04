#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# authorize.sh — Gestión de alcance (SoW) del Ecosistema de Ciberseguridad
# Registra targets autorizados para pruebas ofensivas (hacking ético).
#
# Uso:
#   authorize.sh status                    # ver estado y path
#   authorize.sh list [--all] [--json]     # listar targets autorizados
#   authorize.sh init <programa_url>       # crear scope.json del proyecto activo
#   authorize.sh add <target> <tipo> [duración] [nota]
#   authorize.sh remove <target>
#   authorize.sh archive <proyecto>        # archivar proyecto finalizado
#
# tipo      : recon|scan|enumerate|exploit|post-exploit|dos|phishing|all
# duración  : 30m / 2h / 7d / 30d (texto libre = sin vencimiento)
# ═══════════════════════════════════════════════════════════════════
set -uo pipefail

root="${OPENCODE_ROOT:-}"
if [ -z "$root" ]; then
  case "__OPENCODE_ROOT__" in
    /*) root="__OPENCODE_ROOT__" ;;
    *)  root="${XDG_CONFIG_HOME:-$HOME/.config}/opencode" ;;
  esac
fi
export _AZ_ROOT="$root"

CYBER_DIR="$root/cyber"
PROJ_DIR="$CYBER_DIR/projects"
mkdir -p "$CYBER_DIR" "$PROJ_DIR"

# ── proyecto activo (mismo contrato que project-context.sh) ──────────
active_project() {
  if [ -n "${CYBER_PROJECT:-}" ]; then echo "$CYBER_PROJECT"; return; fi
  python3 -c '
import json,sys
try:
    d=json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
print((d.get("project") or "").strip())
' "$CYBER_DIR/session.json" 2>/dev/null || true
}

PROJECT="$(active_project)"

# scope.json donde se escribe: proyecto activo si existe, si no el global
target_scope_file() {
  if [ -n "$PROJECT" ]; then echo "$PROJ_DIR/$PROJECT/scope.json"; else echo "$CYBER_DIR/scope.json"; fi
}

now() { date '+%Y-%m-%dT%H:%M:%S'; }

case "${1:-}" in
  status)
    echo "Root:             $root"
    echo "Proyecto activo:  ${PROJECT:-(ninguno)}"
    if [ -n "$PROJECT" ]; then
      echo "Scope file:       $PROJ_DIR/$PROJECT/scope.json"
      [ -f "$PROJ_DIR/$PROJECT/scope.json" ] || echo "  ⚠ no existe todavía → authorize.sh init <url>"
    else
      echo "Scope file:       $CYBER_DIR/scope.json"
    fi
    echo "Proyectos:        $(ls -1 "$PROJ_DIR" 2>/dev/null | tr '\n' ' ')"
    echo
    if [ -n "$PROJECT" ] && [ -f "$PROJ_DIR/$PROJECT/scope.json" ]; then
      cat "$PROJ_DIR/$PROJECT/scope.json"
    elif [ -f "$CYBER_DIR/scope.json" ]; then
      cat "$CYBER_DIR/scope.json"
    else
      echo "(no scope registrado aún)"
    fi
    ;;

  list)
    exec bash "$root/tools/scope.sh" ${2:-}
    ;;

  init)
    url="${2:?uso: authorize.sh init <programa_url>}"
    if [ -z "$PROJECT" ]; then
      echo "✗ No hay proyecto activo. Fija el pin primero:" >&2
      echo "    project-context.sh set <proyecto>" >&2
      exit 1
    fi
    SCOPE="$PROJ_DIR/$PROJECT/scope.json"
    mkdir -p "$(dirname "$SCOPE")"
    if [ -f "$SCOPE" ]; then
      echo "⚠ Ya existía: $SCOPE (no se sobrescribe)"
    else
      python3 - "$SCOPE" "$url" "$PROJECT" <<'PY'
import datetime, json, sys
path, url, project = sys.argv[1:4]
data = {
    "updated": datetime.datetime.now().isoformat(timespec="seconds"),
    "project": project,
    "program": url,
    "note": "Creado con authorize.sh init. REGISTRAR TARGETS ANTES DE ATACAR.",
    "targets": [],
}
json.dump(data, open(path, "w"), indent=2, ensure_ascii=False)
print("✓ Creado:", path)
PY
    fi
    echo "✓ Proyecto: $PROJECT"
    ;;

  add)
    target="${2:?target requerido}"
    tipo="${3:-all}"
    duracion="${4:-}"
    note="${5:-autorizado por usuario}"
    SCOPE="$(target_scope_file)"
    mkdir -p "$(dirname "$SCOPE")"
    ts="$(now)"
    python3 - "$SCOPE" "$target" "$tipo" "$duracion" "$ts" "$note" <<'PY'
import datetime, json, os, sys
path, target, tipo, dur, ts, note = sys.argv[1:]
d = {"updated": ts, "targets": []}
if os.path.exists(path):
    try:
        d = json.load(open(path))
    except Exception:
        d = {"updated": ts, "targets": []}
d.setdefault("targets", [])
for t in d["targets"]:
    if t.get("target") == target:
        t.update({"type": tipo, "since": ts, "until": dur, "note": note})
        break
else:
    d["targets"].append({"target": target, "type": tipo,
                         "since": ts, "until": dur, "note": note})
d["updated"] = datetime.datetime.now().isoformat(timespec="seconds")
json.dump(d, open(path, "w"), indent=2, ensure_ascii=False)
PY
    echo "✓ Autorizado: $target (tipo=$tipo, hasta=${duracion:-∞}) → $SCOPE"
    ;;

  remove)
    target="${2:?target requerido}"
    SCOPE="$(target_scope_file)"
    python3 - "$SCOPE" "$target" <<'PY'
import datetime, json, os, sys
path, target = sys.argv[1:]
if not os.path.exists(path):
    print("✗ No existe el fichero de scope:", path); sys.exit(1)
d = json.load(open(path))
before = len(d.get("targets", []))
d["targets"] = [t for t in d.get("targets", []) if t.get("target") != target]
d["updated"] = datetime.datetime.now().isoformat(timespec="seconds")
json.dump(d, open(path, "w"), indent=2, ensure_ascii=False)
print("✓ Eliminado" if len(d["targets"]) < before else "⚠ No estaba registrado")
PY
    ;;

  archive)
    p="${2:?proyecto requerido}"
    SRC="$PROJ_DIR/$p/scope.json"
    if [ ! -f "$SRC" ]; then
      echo "✗ No existe scope de '$p': $SRC" >&2
      exit 1
    fi
    mkdir -p "$CYBER_DIR/archived"
    DEST="$CYBER_DIR/archived/$p-scope.json"
    [ -e "$DEST" ] && DEST="$CYBER_DIR/archived/$p-scope.$(date +%Y%m%d%H%M%S).json"
    mv "$SRC" "$DEST"
    rmdir "$PROJ_DIR/$p" 2>/dev/null || true
    python3 - "$CYBER_DIR/session.json" "$p" <<'PY'
import json, os, sys
path, gone = sys.argv[1:]
try:
    d = json.load(open(path))
except Exception:
    sys.exit(0)
if d.get("project") == gone:
    d.pop("project", None); d.pop("pinned", None)
    d["reason"] = f"Proyecto '{gone}' archivado"
    json.dump(d, open(path, "w"), indent=2, ensure_ascii=False)
PY
    echo "✓ Archivado: $SRC → $DEST (historial de aprendizaje)"
    ;;

  *)
    echo "Uso: authorize.sh {status|list [--all]|init <url>|add <target> <tipo> [duración] [nota]|remove <target>|archive <proyecto>}"
    exit 1
    ;;
esac
