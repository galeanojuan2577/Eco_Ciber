#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# check-scope.sh — Gate de autorización previa a CUALQUIER acción ofensiva.
#
# Uso:
#   check-scope.sh <target> [tipo_test] [--force] [--json]
#
#   tipo_test : recon | scan | enumerate | exploit | post-exploit |
#               dos | phishing | all            (opcional)
#   --force   : el usuario YA confirmó manualmente que es legal/consentida.
#               Sólo degrada el código 1 a 0. NUNCA degrada el 2.
#   --json    : salida en JSON para consumo programático.
#
# Contrato de salida (rules/cyber/authorization.md):
#   0  IN SCOPE      → procede y queda registrado en audit.log
#   1  NEEDS CONFIRM → fuera de scope / autorización vencida /
#                      tipo no autorizado / sólo en scope global
#                      → el agente DEBE preguntar al usuario antes de actuar
#   2  HARD DENY     → el target pertenece a OTRO proyecto (aislamiento):
#                      rechazo duro, no se fuerza. Cambiar de proyecto.
#   3  USAGE ERROR   → sin argumentos o sin ningún fichero de scope
# ═══════════════════════════════════════════════════════════════════
set -uo pipefail

# ── raíz de la instalación ───────────────────────────────────────────
# El placeholder __OPENCODE_ROOT__ se resuelve en la instalación. Si el
# script se ejecuta tal cual desde el repo, cae al directorio por defecto.
root="${OPENCODE_ROOT:-}"
if [ -z "$root" ]; then
  case "__OPENCODE_ROOT__" in
    /*) root="__OPENCODE_ROOT__" ;;
    *)  root="${XDG_CONFIG_HOME:-$HOME/.config}/opencode" ;;
  esac
fi
export _CS_ROOT="$root"

target="${1:-}"
if [ -z "$target" ]; then
  echo "Uso: check-scope.sh <target> [tipo_test] [--force] [--json]" >&2
  exit 3
fi
shift

tipo=""
force=0
json=0
for a in "$@"; do
  case "$a" in
    --force) force=1 ;;
    --json)  json=1 ;;
    -*)      echo "Flag desconocida: $a" >&2; exit 3 ;;
    *)       if [ -z "$tipo" ]; then tipo="$a"; fi ;;
  esac
done

out="$(python3 - "$target" "$tipo" "$force" "$json" <<'PY'
import datetime, glob, json, os, re, sys

target, tipo, force, want_json = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4] == "1"
root = os.environ["_CS_ROOT"]
cyber = os.path.join(root, "cyber")

# ── utilidades ───────────────────────────────────────────────────────
def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None

def norm(value):
    v = (value or "").strip().lower().rstrip(".")
    if "://" in v:
        v = v.split("://", 1)[1]
    return v.split("/", 1)[0]

def split_hp(value):
    v = norm(value)
    if v.count(":") == 1:
        h, p = v.split(":")
        return h, p
    return v, None

def matches(entry, tgt):
    """Exacto, subdominio, wildcard *.base y host:puerto estricto."""
    eh, ep = split_hp(entry)
    th, tp = split_hp(tgt)
    if ep is not None and ep != tp:
        return False
    if eh.startswith("*."):
        base = eh[2:]
        return th == base or th.endswith("." + base)
    if eh == th:
        return True
    return th.endswith("." + eh)

DUR = re.compile(r"^(\d+)\s*([smhdw])$", re.I)
UNITS = {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800}

def expiry(entry):
    """Devuelve (datetime|None, etiqueta). Texto libre => sin vencimiento."""
    until = str(entry.get("until") or "").strip()
    m = DUR.match(until)
    if not m:
        return None, until or "∞"
    try:
        since = datetime.datetime.fromisoformat(str(entry.get("since")))
    except Exception:
        return None, until
    dt = since + datetime.timedelta(seconds=int(m.group(1)) * UNITS[m.group(2).lower()])
    return dt, until

def entries(path):
    data = load(path)
    if not isinstance(data, dict):
        return []
    return data.get("targets") or []

def find(path, tgt):
    for e in entries(path):
        if matches(e.get("target", ""), tgt):
            return e
    return None

# ── proyecto activo (mismo contrato que project-context.sh) ──────────
project = (os.environ.get("CYBER_PROJECT") or "").strip()
pinned = False
if not project:
    s = load(os.path.join(cyber, "session.json"))
    if isinstance(s, dict):
        project = (s.get("project") or "").strip()
        pinned = bool(s.get("pinned"))

proj_dir = os.path.join(cyber, "projects")
all_projects = sorted(
    os.path.basename(os.path.dirname(p))
    for p in glob.glob(os.path.join(proj_dir, "*", "scope.json"))
)
if not project and all_projects:
    # sin pin: sólo hay alcance global, no se infiere proyecto
    pass

active_file = os.path.join(proj_dir, project, "scope.json") if project else ""
global_file = os.path.join(cyber, "scope.json")

allow_files, allow_labels = [], []
if active_file and os.path.isfile(active_file):
    allow_files.append(active_file)
    allow_labels.append(f"project:{project}")
elif os.path.isfile(global_file):
    allow_files.append(global_file)
    allow_labels.append("global")

other = [(f, f"project:{os.path.basename(os.path.dirname(f))}")
         for f in glob.glob(os.path.join(proj_dir, "*", "scope.json"))
         if os.path.abspath(f) != os.path.abspath(active_file or "")]

# ── evaluación ───────────────────────────────────────────────────────
code, reason, detail, matched, src = 1, "", "", None, ""

if not allow_files and not os.path.isfile(global_file):
    code, reason = 3, "no hay ningún fichero de scope: registra autorización con authorize.sh add"
else:
    now = datetime.datetime.now()
    # 1) en scope del proyecto activo (o global si no hay proyecto)
    for path, label in zip(allow_files, allow_labels):
        e = find(path, target)
        if not e:
            continue
        exp, label_until = expiry(e)
        if exp is not None and exp < now:
            reason = f"autorización VENCIDA el {exp.isoformat(timespec='seconds')} (until={label_until})"
            matched, src = e, label
            break
        allowed_type = str(e.get("type") or "all").lower()
        if tipo and allowed_type not in ("all", tipo):
            reason = (f"target en scope pero sólo autorizado para tipo "
                      f"'{allowed_type}'; se pidió '{tipo}'")
            matched, src = e, label
            break
        code, reason, matched, src = 0, f"coincide con '{e.get('target')}' en {label}", e, label
        break

    # 2) ¿está en el scope de OTRO proyecto?  -> rechazo duro (aislamiento)
    if code != 0:
        for path, label in other:
            e = find(path, target)
            if e:
                code, reason, matched, src = 2, f"pertenece al scope de {label}", e, label
                break

    # 3) sólo registrado en el scope global con un proyecto activo
    if code != 0 and code != 2 and active_file and os.path.isfile(global_file):
        e = find(global_file, target)
        if e:
            code, reason, matched, src = 1, "registrado sólo en el scope global, no en el proyecto activo", e, "global"

    # 4) nada
    if code != 0 and not reason:
        reason = "target no registrado en ningún scope"

# ── --force sólo degrada el 1 ────────────────────────────────────────
forced = False
if force and code == 1 and reason != "":
    forced = True
    code = 0

status = {0: "IN SCOPE", 1: "NEEDS CONFIRM", 2: "HARD DENY", 3: "USAGE ERROR"}[code]

# ── salida ───────────────────────────────────────────────────────────
if want_json:
    print(json.dumps({
        "target": target, "type": tipo or None, "status": status,
        "exit": code, "reason": reason, "scope": src or None,
        "matched": (matched or {}).get("target"), "forced": forced,
        "project": project or None, "pinned": pinned,
    }, ensure_ascii=False, indent=2))
else:
    print(f"=== Scope Check: {target} ===")
    print(f"  proyecto activo : {project or '(ninguno)'}{' [pin]' if pinned else ''}")
    if tipo:
        print(f"  tipo de test    : {tipo}")
    print(f"  fichero consultado: {src or 'ninguno'}")
    print(f"[{status}] {reason}")
    if code == 0:
        print("  → Acción AUTORIZADA. Registra la acción con audit-log.sh.")
    elif code == 1:
        print("  → STOP. Pregunta al usuario si es legal/consentida antes de actuar.")
        print("    Si el usuario confirma, repite con --force y regístralo.")
    elif code == 2:
        print("  → STOP (rechazo duro). Es el scope de OTRO proyecto.")
        print("    Cambia de proyecto con: project-context.sh set <proyecto>")
    else:
        print("  → Registra la autorización con: authorize.sh add <target> <tipo> [duración]")

sys.exit(code)
PY
)"
rc=$?

printf '%s\n' "$out"

# ── trazabilidad: todo chequeo queda en el audit log ─────────────────
if [ -x "$root/tools/audit-log.sh" ] || [ -f "$root/tools/audit-log.sh" ]; then
  bash "$root/tools/audit-log.sh" "check-scope target=$target tipo=${tipo:-none} exit=$rc" \
    >/dev/null 2>&1 || true
fi

exit "$rc"
