#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# project-context.sh — Pin de sesión: proyecto activo del Ecosistema de Ciberseguridad
# Fija/consulta el proyecto activo escribiendo cyber/session.json (mismo formato
# que ya existe: updated, project, pinned, reason).
# Uso:
#   project-context.sh                  # get: proyecto activo + rutas
#   project-context.sh get              # ídem
#   project-context.sh set <proyecto>   # fijar el pin de sesión
#   project-context.sh unset            # quitar el pin
#   project-context.sh resolve          # imprimir solo el id (para pipes)
#   project-context.sh list             # listar proyectos (cyber/projects + __HOME__/BugBounty)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ROOT="${OPENCODE_ROOT:-$HOME/.config/opencode}"
CYBER_DIR="$ROOT/cyber"
SESSION_FILE="$CYBER_DIR/session.json"
PROJECTS_DIR="$CYBER_DIR/projects"
BUGBOUNTY_DIR="${BUGBOUNTY_ROOT:-$HOME/BugBounty}"

usage() {
  echo "Uso: project-context.sh {get|set <proyecto>|unset|resolve|list}" >&2
  exit 1
}

# Lee un campo del pin de sesión ("" si no existe fichero/campo)
session_field() {
  local field="$1"
  python3 - "$SESSION_FILE" "$field" <<'PY' 2>/dev/null || true
import json, sys
f, field = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(f))
except Exception:
    sys.exit(0)
v = d.get(field, "")
if isinstance(v, bool):
    v = "true" if v else "false"
print(v)
PY
}

case "${1:-get}" in
  set)
    name="${2:?Usage: project-context.sh set <proyecto>}"
    mkdir -p "$CYBER_DIR"
    python3 - "$SESSION_FILE" "$name" <<'PY'
import datetime, json, sys
f, name = sys.argv[1], sys.argv[2]
data = {
    "updated": datetime.datetime.now().isoformat(),
    "project": name,
    "pinned": True,
    "reason": "Fijado con project-context.sh set",
}
with open(f, "w") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
    echo "✓ Proyecto activo: $name"
    echo "  pin:   $SESSION_FILE"
    echo "  scope: $PROJECTS_DIR/$name/scope.json"
    echo "  datos: $BUGBOUNTY_DIR/$name"
    ;;
  get)
    project="$(session_field project)"
    if [[ -z "$project" ]]; then
      echo "(sin proyecto activo) — fijar pin: project-context.sh set <proyecto>"
      exit 1
    fi
    scope_file="$PROJECTS_DIR/$project/scope.json"
    scope_state="FALTA (crear con: authorize.sh init <url>)"
    [[ -f "$scope_file" ]] && scope_state="$scope_file"
    data_state="FALTA"
    [[ -d "$BUGBOUNTY_DIR/$project" ]] && data_state="$BUGBOUNTY_DIR/$project"
    echo "=== Contexto de sesión ==="
    echo "Proyecto activo: $project"
    echo "Fijado:          $(session_field pinned)"
    echo "Actualizado:     $(session_field updated)"
    echo "Razón:           $(session_field reason)"
    echo "Scope:           $scope_state"
    echo "Datos:           $data_state"
    ;;
  resolve)
    project="$(session_field project)"
    if [[ -z "$project" ]]; then
      echo "ERROR: sin proyecto activo — fijar pin: project-context.sh set <proyecto>" >&2
      exit 1
    fi
    echo "$project"
    ;;
  unset)
    if [[ -f "$SESSION_FILE" ]]; then
      rm -f "$SESSION_FILE"
      echo "✓ Pin de sesión eliminado (vuelve a detección por cwd/env)"
    else
      echo "(no había pin de sesión)"
    fi
    ;;
  list)
    active="$(session_field project)"
    echo "=== Proyectos en $PROJECTS_DIR ==="
    if [[ -d "$PROJECTS_DIR" ]]; then
      found=0
      for d in "$PROJECTS_DIR"/*/; do
        [[ -d "$d" ]] || continue
        found=1
        name="$(basename "$d")"
        mark=" "
        [[ "$name" == "$active" ]] && mark="*"
        scope_state="scope=FALTA"
        [[ -f "$d/scope.json" ]] && scope_state="scope=OK"
        data_state="datos=FALTA"
        [[ -d "$BUGBOUNTY_DIR/$name" ]] && data_state="datos=OK"
        extra=""
        [[ "$name" == "$active" ]] && extra="  (activo)"
        echo "  $mark $name  $scope_state  $data_state$extra"
      done
      [[ "$found" -eq 1 ]] || echo "  (ningún proyecto con scope registrado)"
    else
      echo "  (directorio inexistente)"
    fi
    echo ""
    echo "=== Datos en $BUGBOUNTY_DIR ==="
    if [[ -d "$BUGBOUNTY_DIR" ]]; then
      found=0
      for d in "$BUGBOUNTY_DIR"/*/; do
        [[ -d "$d" ]] || continue
        found=1
        name="$(basename "$d")"
        mark=" "
        [[ "$name" == "$active" ]] && mark="*"
        state=""
        [[ -f "$d/SESSION-STATE.md" ]] && state="  SESSION-STATE.md OK"
        echo "  $mark $name$state"
      done
      [[ "$found" -eq 1 ]] || echo "  (ningún proyecto en disco)"
    else
      echo "  (directorio inexistente)"
    fi
    ;;
  *)
    usage
    ;;
esac
