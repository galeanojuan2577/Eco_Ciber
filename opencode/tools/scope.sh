#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# scope.sh — Muestra el alcance autorizado.
#
# Uso:
#   scope.sh                     # proyecto activo (o scope global)
#   scope.sh <proyecto>          # scope de un proyecto concreto
#   scope.sh --all               # resumen de todos los proyectos
#   scope.sh --json              # salida JSON
# ═══════════════════════════════════════════════════════════════════
set -uo pipefail

root="${OPENCODE_ROOT:-}"
if [ -z "$root" ]; then
  case "__OPENCODE_ROOT__" in
    /*) root="__OPENCODE_ROOT__" ;;
    *)  root="${XDG_CONFIG_HOME:-$HOME/.config}/opencode" ;;
  esac
fi
export _SC_ROOT="$root"

project=""
all=0
want_json=0
for a in "$@"; do
  case "$a" in
    --all)  all=1 ;;
    --json) want_json=1 ;;
    -*)     echo "Flag desconocida: $a" >&2; exit 3 ;;
    *)      project="$a" ;;
  esac
done

python3 - "$project" "$all" "$want_json" <<'PY'
import datetime, glob, json, os, re, sys

project, all_mode, want_json = sys.argv[1], sys.argv[2] == "1", sys.argv[3] == "1"
root = os.environ["_SC_ROOT"]
cyber = os.path.join(root, "cyber")
proj_dir = os.path.join(cyber, "projects")

def load(p):
    try:
        with open(p, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None

DUR = re.compile(r"^(\d+)\s*([smhdw])$", re.I)
UNIT = {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800}

def state(entry):
    until = str(entry.get("until") or "").strip()
    m = DUR.match(until)
    if not m:
        return "activa", until or "∞"
    try:
        since = datetime.datetime.fromisoformat(str(entry.get("since")))
    except Exception:
        return "activa", until
    exp = since + datetime.timedelta(seconds=int(m.group(1)) * {"s":1,"m":60,"h":3600,"d":86400,"w":604800}[m.group(2).lower()])
    if exp < datetime.datetime.now():
        return "VENCIDA", f"{until} -> {exp.isoformat(timespec='seconds')}"
    return "activa", until

def files_for(project):
    if project:
        p = os.path.join(proj_dir, project, "scope.json")
        return [(p, f"project:{project}")] if os.path.isfile(p) else []
    out = []
    s = load(os.path.join(cyber, "session.json"))
    active = ((s or {}).get("project") or "").strip() if isinstance(s, dict) else ""
    if active:
        p = os.path.join(proj_dir, active, "scope.json")
        if os.path.isfile(p):
            out.append((p, f"project:{active}"))
    g = os.path.join(cyber, "scope.json")
    if os.path.isfile(g):
        out.append((g, "global"))
    return out

if all_mode:
    rows = []
    for p in sorted(glob.glob(os.path.join(proj_dir, "*", "scope.json"))):
        rows.append((p, f"project:{os.path.basename(os.path.dirname(p))}"))
    g = os.path.join(cyber, "scope.json")
    if os.path.isfile(g):
        rows.append((g, "global"))
else:
    rows = files_for(project)

if want_json:
    result = []
    for path, label in rows:
        data = load(path) or {}
        result.append({
            "source": label, "file": path, "updated": data.get("updated"),
            "targets": [
                {**t, "state": state(t)[0]} for t in (data.get("targets") or [])
            ],
        })
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0)

if not rows:
    print("No hay scope registrado. Usa: authorize.sh init <url> && authorize.sh add <target> <tipo>")
    sys.exit(1)

for path, label in rows:
    data = load(path) or {}
    targets = data.get("targets") or []
    print(f"=== Scope [{label}] ===")
    print(f"  fichero : {path}")
    print(f"  actualizado: {data.get('updated','?')}")
    if not targets:
        print("  (sin targets registrados)")
    for t in targets:
        st, until = state(t)
        mark = "✓" if st == "activa" else "✗"
        print(f"  {mark} {str(t.get('target','')):<28} tipo={str(t.get('type','?')):<12} "
              f"estado={st:<9} hasta={until:<24} {t.get('note','')}")
    print()
PY
