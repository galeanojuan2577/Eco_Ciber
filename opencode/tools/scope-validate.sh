#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# scope-validate.sh — Gate de alcance corregido (versión autoritativa)
# Valida un target contra cyber/scope.json (global) y cyber/projects/*/scope.json
# (el fichero real que mantiene authorize.sh, clave "targets[]").
# (Sustituye a check-scope.sh, que lee cyber/programs.json — fichero inexistente.)
# Uso: scope-validate.sh <target>
# Salida: [IN SCOPE] exit 0 | [OUT OF SCOPE] exit 1 | [NOT FOUND] exit 1
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

TARGET="${1:?Usage: scope-validate.sh <target>}"

ROOT="${OPENCODE_ROOT:-$HOME/.config/opencode}"
CYBER_DIR="$ROOT/cyber"
GLOBAL_SCOPE="$CYBER_DIR/scope.json"

files=()
if [[ -f "$GLOBAL_SCOPE" ]]; then
  files+=("$GLOBAL_SCOPE")
fi
if [[ -d "$CYBER_DIR/projects" ]]; then
  for f in "$CYBER_DIR"/projects/*/scope.json; do
    if [[ -f "$f" ]]; then
      files+=("$f")
    fi
  done
fi

if [[ "${#files[@]}" -eq 0 ]]; then
  echo "[NOT FOUND] no hay ningún scope.json bajo $CYBER_DIR"
  echo "Registra targets antes de testear: authorize.sh add <target> <tipo>"
  exit 1
fi

echo "=== Scope Check: $TARGET ==="
echo "    ficheros consultados: ${#files[@]}"

set +e
python3 - "$TARGET" "${files[@]}" <<'PY'
import json, re, sys
from urllib.parse import urlparse

target_raw = (sys.argv[1] or "").strip().lower()
files = sys.argv[2:]


def host_of(value):
    """Host de un target/entrada ('https://a.b/c' -> 'a.b', 'a.b:8080' -> 'a.b:8080')."""
    v = (value or "").strip().lower()
    if not v:
        return ""
    if "://" in v:
        v = urlparse(v).netloc or v
    return v.split("/")[0]


def norm_entry(entry):
    if isinstance(entry, dict):
        entry = entry.get("target") or entry.get("host") or entry.get("domain") or ""
    return str(entry).strip().lower()


target_host = host_of(target_raw)
target_path = target_raw
if "://" in target_path:
    target_path = re.sub(r"^https?://", "", target_path)
target_path = target_path.rstrip("/")

# niveles: 0 = nada, 1 = coincidencia exacta (explícita), 2 = coincidencia wildcard


def level(entry, t_host, t_path):
    e = norm_entry(entry)
    if not e:
        return 0
    if e.startswith("*."):
        base = e[2:]
        if base and t_host.endswith("." + base):
            return 2
        if t_path == base or t_path.startswith(base + "/"):
            return 2
        return 0
    if "/" in e:  # entrada con path (ej. github.com/org)
        if t_path == e or t_path.startswith(e + "/") or t_path.startswith(e + "?"):
            return 1
        return 0
    if t_host == e:
        return 1
    return 0


def entries_of(data, keys):
    out = []
    for key in keys:
        val = data.get(key)
        if isinstance(val, list):
            out.extend(val)
        elif isinstance(val, str):
            out.append(val)
    return out


in_exact = in_wild = out_exact = out_wild = 0
src_in_exact = src_in_wild = src_out_exact = src_out_wild = None
skipped = 0

for path in files:
    try:
        data = json.load(open(path))
    except Exception:
        continue
    if data.get("excluded") is True:  # proyecto huérfano/legacy: no es fuente de verdad
        skipped += 1
        continue

    project = data.get("project") or path
    targets = entries_of(data, ("targets", "in_scope"))
    excluded = entries_of(data, ("out_of_scope", "excluded", "outOfScope"))

    for e in targets:
        lv = level(e, target_host, target_path)
        if lv == 1 and not in_exact:
            in_exact, src_in_exact = 1, (path, norm_entry(e), project)
        elif lv == 2 and not in_wild:
            in_wild, src_in_wild = 1, (path, norm_entry(e), project)
    for e in excluded:
        lv = level(e, target_host, target_path)
        if lv == 1 and not out_exact:
            out_exact, src_out_exact = 1, (path, norm_entry(e), project)
        elif lv == 2 and not out_wild:
            out_wild, src_out_wild = 1, (path, norm_entry(e), project)


def rel(path):
    m = re.search(r"/cyber/(.*)$", path)
    return "cyber/" + m.group(1) if m else path


if skipped:
    print(f"    (omitidos {skipped} scope.json con excluded=true)")

# Escalera de precedencia: lo EXPLÍCITO gana a lo wildcard, y un exclusión
# explícita gana a un wildcard de inclusión (p. ej. excluded vs *.dominio).
if in_exact:
    path, entry, project = src_in_exact
    print(f"[IN SCOPE] {target_raw} coincide exactamente con '{entry}' → {rel(path)}")
    sys.exit(0)
if out_exact:
    path, entry, project = src_out_exact
    print(f"[OUT OF SCOPE] {target_raw} excluido exactamente por '{entry}' → {rel(path)}")
    print("  Obtén autorización explícita del usuario antes de continuar.")
    sys.exit(1)
if in_wild:
    path, entry, project = src_in_wild
    print(f"[IN SCOPE] {target_raw} coincide con wildcard '{entry}' → {rel(path)}")
    sys.exit(0)
if out_wild:
    path, entry, project = src_out_wild
    print(f"[OUT OF SCOPE] {target_raw} excluido por wildcard '{entry}' → {rel(path)}")
    print("  Obtén autorización explícita del usuario antes de continuar.")
    sys.exit(1)

print(f"[NOT FOUND] {target_raw} no aparece en ningún scope.json")
print("  Solo testear targets confirmados manualmente en scope.")
print("  Registrarlo (con consentimiento): authorize.sh add <target> <tipo>")
sys.exit(1)
PY
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  echo ""
  echo "⚠ STOP — target fuera de alcance o sin registrar."
  echo "  Requiere confirmación/autorización explícita del usuario."
fi
exit "$rc"
