#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# audit-log.sh — Registro de auditoría del Ecosistema de Ciberseguridad
# Añade una entrada timestamped al audit log (evidencia de autorización).
# Uso: audit-log.sh "<descripción de la acción>"
# ═══════════════════════════════════════════════════════════════════
set -uo pipefail

root="${OPENCODE_ROOT:-}"
if [ -z "$root" ]; then
  case "__OPENCODE_ROOT__" in
    /*) root="__OPENCODE_ROOT__" ;;
    *)  root="${XDG_CONFIG_HOME:-$HOME/.config}/opencode" ;;
  esac
fi

CYBER_DIR="$root/cyber"
AUDIT_FILE="$CYBER_DIR/audit.log"

mkdir -p "$CYBER_DIR" 2>/dev/null || true

ts="$(date '+%Y-%m-%d %H:%M:%S')"
user="${USER:-$(whoami)}"
# etiqueta con el proyecto activo (mismo contrato que project-context.sh)
proj="${CYBER_PROJECT:-}"
if [ -z "$proj" ] && [ -f "$CYBER_DIR/session.json" ]; then
  proj="$(python3 -c '
import json,sys
try: print((json.load(open(sys.argv[1])).get("project") or "").strip())
except Exception: pass
' "$CYBER_DIR/session.json" 2>/dev/null || true)"
fi

if ! { echo "[$ts] user=$user :: [proyecto=${proj:-sin-proyecto}] $*" >> "$AUDIT_FILE"; } 2>/dev/null; then
  echo "⚠ no se pudo escribir el audit log en $AUDIT_FILE" >&2
  exit 0
fi
echo "✓ auditado: $*"
