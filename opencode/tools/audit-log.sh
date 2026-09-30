#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# audit-log.sh — Registro de auditoría del Ecosistema de Ciberseguridad
# Añade una entrada timestamped al audit log (evidencia de autorización/trazabilidad).
# Uso: audit-log.sh "<descripción de la acción>"
# ═══════════════════════════════════════════════════════════════

CYBER_DIR="__OPENCODE_ROOT__/cyber"
AUDIT_FILE="$CYBER_DIR/audit.log"

mkdir -p "$CYBER_DIR"
ts="$(date '+%Y-%m-%d %H:%M:%S')"
user="${USER:-$(whoami)}"
echo "[$ts] user=$user :: $*" >> "$AUDIT_FILE"
echo "✓ auditado: $*"