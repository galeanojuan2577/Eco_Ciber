#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# recon-triage.sh — Agrega, deduplica y prioriza la salida de un recon
# Entrada: directorio de recon (01_pasivo/ 02_activo/ 03_enumeracion/
#          04_vulnerabilidades/) o un fichero plano de hosts (--domains).
# Salida:  <dir>/triage/{hosts.txt,urls.txt,ranked.txt,summary.txt}
# Uso:
#   recon-triage.sh <dir> [--json] [--topN N] [--cap N] [--project <id>]
#   recon-triage.sh --domains <fichero_plano> [--json] [--consent]
#   --topN N   candidatos del resumen (default 10)
#   --cap N    líneas máximas por fichero de salida (0 = sin límite)
#   --json     emitir JSON en stdout en lugar del resumen humano
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

ROOT="${OPENCODE_ROOT:-$HOME/.config/opencode}"
SESSION_FILE="$ROOT/cyber/session.json"

FIRST="${1:?Usage: recon-triage.sh <dir> [--json] [--domains <file>]}"
DIR=""
if [[ "$FIRST" == -* ]]; then
  DIR=""
else
  DIR="$FIRST"
  shift
fi

DOMAINS="" JSON=0 TOPN=10 CAP=0 PROJECT="" CONSENT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)     JSON=1; shift ;;
    --domains)  DOMAINS="${2:?Usage: recon-triage.sh --domains <file>}"; shift 2 ;;
    --project)  PROJECT="${2:?Usage: recon-triage.sh --project <id>}"; shift 2 ;;
    --topN)     TOPN="${2:?Usage: recon-triage.sh --topN <N>}"; shift 2 ;;
    --cap)      CAP="${2:?Usage: recon-triage.sh --cap <N>}"; shift 2 ;;
    --consent)  CONSENT=1; shift ;;   # marcador de consentimiento (compat bbas-cli)
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "Argumento desconocido: $1" >&2
      echo "Usage: recon-triage.sh <dir> [--json] [--domains <file>]" >&2
      exit 1 ;;
  esac
done

if [[ -n "$DOMAINS" ]]; then
  [[ -f "$DOMAINS" ]] || { echo "ERROR: no existe el fichero: $DOMAINS" >&2; exit 1; }
  MODE="file" SRC="$DOMAINS"
  OUT_DIR="$(cd "$(dirname "$DOMAINS")" && pwd)/triage"
elif [[ -n "$DIR" ]]; then
  [[ -d "$DIR" ]] || { echo "ERROR: no existe el directorio: $DIR" >&2; exit 1; }
  MODE="dir" SRC="$DIR" OUT_DIR="$DIR/triage"
else
  echo "Usage: recon-triage.sh <dir> [--json] [--domains <file>]" >&2
  exit 1
fi

# Proyecto activo (pin de sesión) si no se indicó --project
if [[ -z "$PROJECT" && -f "$SESSION_FILE" ]]; then
  PROJECT="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("project",""))
except Exception: print("")' "$SESSION_FILE" 2>/dev/null || true)"
fi

mkdir -p "$OUT_DIR"

python3 - "$MODE" "$SRC" "$OUT_DIR" "$TOPN" "$CAP" "$PROJECT" "$JSON" "$CONSENT" <<'PY'
import json, os, re, sys

mode, src, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
topn, cap = int(sys.argv[4]), int(sys.argv[5])
project, as_json, consent = sys.argv[6], sys.argv[7] == "1", sys.argv[8] == "1"

PHASES = ("01_pasivo", "02_activo", "03_enumeracion", "04_vulnerabilidades")
SEV_ORDER = ["critical", "high", "medium", "low", "info"]
SEV_RANK = {s: i for i, s in enumerate(reversed(SEV_ORDER))}  # critical=4 ... info=0

URL_RE = re.compile(r"https?://[^\s\"'<>)\[\]{}]+", re.I)
HOST_RE = re.compile(
    r"^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}(?::\d{1,5})?$"
    r"|^(?:\d{1,3}\.){3}\d{1,3}(?::\d{1,5})?$"
    r"|^\[[0-9a-f:]+\](?::\d+)?$", re.I)
JUNK_TLD = {
    "txt", "json", "md", "log", "csv", "html", "htm", "js", "css", "png", "jpg",
    "jpeg", "gif", "svg", "gz", "zip", "xml", "yaml", "yml", "sh", "py", "conf",
    "ini", "pdf", "db", "sql", "bak",
}
NUCLEI_RE = re.compile(r"^\[(critical|high|medium|low|info)\]\s+(\S+)", re.I)


def host_of(url):
    m = re.match(r"^https?://([^/?#]+)", url, re.I)
    return m.group(1) if m else ""


def clean_host(h):
    h = h.strip().lower().rstrip(".")
    if h.count(":") == 1:  # quitar puerto
        h = h.split(":")[0]
    return h


def junk(h):
    base = h.split(":")[0]
    return "." not in base or base.rsplit(".", 1)[-1] in JUNK_TLD


# ── 1. recolectar ficheros ──────────────────────────────────────
files = []
if mode == "file":
    files = [src]
else:
    for root, dirs, names in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d != "triage")
        rel = os.path.relpath(root, src)
        top = rel.split(os.sep)[0]
        if top in PHASES or rel == ".":
            files += [os.path.join(root, n) for n in sorted(names)]
    if not files:  # directorio genérico: tomar todo lo que haya (sin triage/)
        for root, dirs, names in os.walk(src):
            dirs[:] = sorted(d for d in dirs if d != "triage")
            files += [os.path.join(root, n) for n in sorted(names)]

# ── 2. extraer hosts, URLs y hallazgos de nuclei ────────────────
hosts, urls = {}, {}
sev_counts = {s: 0 for s in SEV_ORDER}
host_sev, host_hits = {}, {}
findings = 0

for path in files:
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except Exception:
        continue
    for raw in URL_RE.findall(text):
        u = raw.rstrip(".,;:'\"")
        urls.setdefault(u, None)
        h = clean_host(host_of(u))
        if h and not junk(h):
            hosts.setdefault(h, None)
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = NUCLEI_RE.match(line)
        if m:
            sev = m.group(1).lower()
            h = clean_host(host_of(m.group(2)) or m.group(2))
        elif '"severity"' in line and line.startswith("{"):
            try:
                d = json.loads(line)
            except Exception:
                d = None
            if not d:
                continue
            info = d.get("info") or {}
            sev = str(d.get("severity") or info.get("severity") or "").lower()
            target = d.get("matched-at") or d.get("url") or d.get("host") or ""
            h = clean_host(host_of(str(target)) or str(target))
        else:
            token = line.split()[0].rstrip(".,;:")
            if HOST_RE.match(token) and not junk(token):
                hosts.setdefault(clean_host(token), None)
            continue
        if sev not in sev_counts:
            continue
        sev_counts[sev] += 1
        findings += 1
        if h and not junk(h):
            hosts.setdefault(h, None)
            host_hits[h] = host_hits.get(h, 0) + 1
            rank = SEV_RANK[sev]
            if rank > host_sev.get(h, -1):
                host_sev[h] = rank

# ── 3. ranking por severidad ────────────────────────────────────
def sort_key(h):
    return (-host_sev.get(h, -1), -host_hits.get(h, 0), h)

ranked = sorted(hosts, key=sort_key)


def sev_name(h):
    return SEV_ORDER[4 - host_sev[h]] if h in host_sev else "none"


host_list = sorted(hosts)
url_list = sorted(urls)
top = [{"host": h, "severity": sev_name(h), "findings": host_hits.get(h, 0)}
       for h in ranked[:topn]]

# ── 4. escribir ficheros limpios en <dir>/triage/ ───────────────
def dump(name, rows):
    if cap > 0:
        rows = rows[:cap]
    with open(os.path.join(out_dir, name), "w", encoding="utf-8") as fh:
        for r in rows:
            fh.write(r + "\n")


dump("hosts.txt", host_list)
dump("urls.txt", url_list)
dump("ranked.txt", ["%-9s %s" % (sev_name(h).upper(), h) for h in ranked])

summary_lines = [
    "recon-triage — fuente: %s" % src,
    "proyecto:    %s" % (project or "(sin pin de sesión)"),
    "consent:     %s" % ("sí" if consent else "no indicado"),
    "ficheros:    %d" % len(files),
    "hosts:       %d" % len(host_list),
    "urls:        %d" % len(url_list),
    "nuclei:      " + " ".join("%s=%d" % (s, sev_counts[s]) for s in SEV_ORDER),
    "hallazgos:   %d" % findings,
    "",
    "top %d por severidad:" % topn,
]
summary_lines += ["  [%s] %s (%d)" % (t["severity"].upper(), t["host"], t["findings"])
                  for t in top]
dump("summary.txt", summary_lines)

# ── 5. salida ───────────────────────────────────────────────────
if as_json:
    print(json.dumps({
        "source": src,
        "project": project or None,
        "consent": consent,
        "files": len(files),
        "hosts": len(host_list),
        "urls": len(url_list),
        "severity": sev_counts,
        "findings": findings,
        "top": top,
        "output_dir": out_dir,
    }, indent=2, ensure_ascii=False))
    sys.exit(0)
print("=== recon-triage: %s ===" % src)
for line in summary_lines:
    print(line)
print("")
print("triage escrito en: %s/" % out_dir)
PY

if [[ "$JSON" -eq 0 ]]; then
  echo "✓ triage completado → $OUT_DIR"
fi
