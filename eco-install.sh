#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# eco-install.sh — Instalador del ecosistema Eco_Ciber para OpenCode V2
#
# Sustituye a `install.sh` del propio Eco_Ciber, que:
#   * hace `rm -rf` sobre ~/.config/opencode (se comería service.json,
#     que guarda la contraseña de servicio), y
#   * asume rutas /root/... de la máquina original.
#
# Este instalador:
#   * JAMÁS borra ~/.config/opencode; sólo escribe por encima.
#   * Preserva `service.json` byte a byte (se respalda y se restaura).
#   * Nunca sobrescribe el estado local de cyber/ (scope, session, audit).
#   * Resuelve los placeholders por fichero, sólo en DESTINO (el repo
#     conserva los placeholders: verify-ecosystem.sh lo comprueba).
#   * Es idempotente: se puede ejecutar tantas veces como se quiera.
#
# Uso:
#   eco-install.sh [--src DIR] [--dest DIR] [--dry-run] [--no-verify]
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

SRC="${SRC:-$HOME/Eco_Ciber}"
DEST="${DEST:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
DRY=0
VERIFY=1

while [ $# -gt 0 ]; do
  case "$1" in
    --src)     SRC="$2"; shift 2 ;;
    --dest)    DEST="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --no-verify) VERIFY=0; shift ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "Flag desconocida: $1 (usa --help)" >&2; exit 3 ;;
  esac
done

say()  { printf '%s\n' "$*"; }
step() { printf '\n\033[1m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$*"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

# ── 0. validación de la fuente ───────────────────────────────────────
step "Validando la fuente"
[ -d "$SRC" ]                       || { err "No existe el repo: $SRC (usa --src)"; exit 1; }
[ -f "$SRC/opencode/opencode.json" ]|| { err "Falta $SRC/opencode/opencode.json"; exit 1; }
[ -f "$SRC/AGENTS.md" ]             || { err "Falta $SRC/AGENTS.md"; exit 1; }
ok "repo: $SRC"
ok "destino: $DEST"

# ── 1. preservar service.json byte a byte ────────────────────────────
step "Respaldo de service.json (contraseña de servicio)"
SVC="$DEST/service.json"
SVC_B64=""
if [ -f "$SVC" ]; then
  SVC_B64="$(base64 -w0 < "$SVC")"
  ok "service.json respaldado en memoria ($(stat -c%s "$SVC") B, sha256=$(sha256sum < "$SVC" | cut -c1-16))"
else
  warn "service.json no existe todavía en $DEST"
fi

restore_service() {
  if [ -n "$SVC_B64" ]; then
    if [ -f "$SVC" ] && [ "$(base64 -w0 < "$SVC")" = "$SVC_B64" ]; then
      return 0
    fi
    mkdir -p "$DEST"
    printf '%s' "$SVC_B64" | base64 -d > "$SVC"
    ok "service.json restaurado byte a byte (sha256=$(sha256sum < "$SVC" | cut -c1-16))"
  fi
}
trap restore_service EXIT

# ── 2. copia + resolución de placeholders ────────────────────────────
step "Copia de ficheros"
export _EI_SRC="$SRC" _EI_DEST="$DEST" _EI_HOME="$HOME" _EI_DRY="$DRY"
export _EI_BIN="${XDG_BIN_HOME:-$HOME/.local/bin}"

python3 - <<'PY'
import os, pathlib, shutil, sys

SRC   = pathlib.Path(os.environ["_EI_SRC"])
DEST  = pathlib.Path(os.environ["_EI_DEST"])
HOME  = os.environ["_EI_HOME"]
BIN   = os.environ["_EI_BIN"]
DRY   = os.environ["_EI_DRY"] == "1"

# directorios instalados tal cual (con placeholders resueltos)
FULL = ["agents", "commands", "rules", "tools", "templates", "plugins", "_data"]
# directorios con datos locales: se SIEMBRAN, jamás se sobrescriben
SEED = ["cyber"]
# árboles de skills: el del repo + el ECC completo
SKILLS = [(SRC / "opencode" / "skills", DEST / "skills"),
          (SRC / "ecc" / "skills",      DEST / "skills-ecc")]
FILES = [(SRC / "opencode" / "opencode.json", DEST / "opencode.json"),
         (SRC / "AGENTS.md",                  DEST / "AGENTS.md")]

SKIP_NAMES = {".git", "node_modules", "__pycache__", ".env"}
SUBS = [("__OPENCODE_ROOT__", str(DEST)),
        ("__ECC_ROOT__",      str(SRC / "ecc")),
        ("__LOCAL_BIN__",     BIN),
        ("__HOME__",          HOME)]

# nunca se tocan aunque estén dentro de un dir copiado
PRESERVE = {"service.json", "audit.log"}

stats = {"files": 0, "dirs": 0, "skipped": 0, "binary": 0}

def transform(data: bytes) -> bytes:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        stats["binary"] += 1
        return data
    changed = False
    for old, new in SUBS:
        if old in text:
            text = text.replace(old, new)
            changed = True
    return text.encode("utf-8") if changed else data

def emit(src: pathlib.Path, dst: pathlib.Path, seed: bool):
    if dst.name in PRESERVE:
        stats["skipped"] += 1
        return
    if seed and dst.exists():
        stats["skipped"] += 1
        return
    stats["files"] += 1
    if DRY:
        print(f"    [dry] {src} -> {dst}")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(transform(src.read_bytes()))

def walk(src_dir: pathlib.Path, dst_dir: pathlib.Path, seed: bool):
    if not src_dir.is_dir():
        print(f"    ⚠ falta {src_dir}"); return
    for root, dirs, files in os.walk(src_dir):
        dirs[:] = [d for d in dirs if d not in SKIP_NAMES]
        rel = pathlib.Path(root).relative_to(src_dir)
        out = dst_dir / rel
        if not DRY:
            out.mkdir(parents=True, exist_ok=True)
            stats["dirs"] += 1
        for f in sorted(files):
            if f in SKIP_NAMES:
                continue
            emit(pathlib.Path(root) / f, out / f, seed)

DEST.mkdir(parents=True, exist_ok=True)
for name in FULL:
    walk(SRC / "opencode" / name, DEST / name, seed=False)
for name in SEED:
    walk(SRC / "opencode" / name, DEST / name, seed=True)
for s, d in SKILLS:
    walk(s, d, seed=False)
for s, d in FILES:
    emit(s, d, seed=False)

print(f"  ficheros: {stats['files']}  dirs: {stats['dirs']}  "
      f"preservados: {stats['skipped']}  binarios intactos: {stats['binary']}")
PY

# ── 3. permisos de ejecución en los tools ────────────────────────────
if [ "$DRY" -eq 0 ]; then
  step "Permisos de ejecución"
  n=0
  while IFS= read -r f; do chmod +x "$f"; n=$((n+1)); done < <(find "$DEST/tools" -name '*.sh' -type f 2>/dev/null)
  ok "$n scripts marcados como ejecutables"
fi

# ── 3b. motor de recon + espacio de trabajo ──────────────────────────
if [ "$DRY" -eq 0 ]; then
  step "Motor de reconocimiento"
  BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
  DOC_DIR="${DOC_DIR:-$HOME/.local/share/recon-pro}"
  mkdir -p "$BIN_DIR" "$DOC_DIR"
  if [ -d "$SRC/recon" ]; then
    python3 - "$SRC/recon" "$BIN_DIR" "$DOC_DIR" "$DEST" "$SRC" <<'PYRECON'
import pathlib, sys, os, stat
srcdir, bindir, docdir, dest, src = sys.argv[1:6]
srcdir = pathlib.Path(srcdir); bindir = pathlib.Path(bindir)
docdir = pathlib.Path(docdir); dest = pathlib.Path(dest)
home = pathlib.Path(os.environ["HOME"])
SUBS = [("__LOCAL_BIN__", str(bindir)), ("__OPENCODE_ROOT__", str(dest)),
        ("__HOME__", str(home)), ("__ECC_ROOT__", str(pathlib.Path(src) / "ecc"))]
left_all = []
for name, out in (("recon_pro.sh", bindir / "recon"), ("bbrecon.sh", bindir / "bbrecon")):
    p = srcdir / name
    if not p.is_file():
        continue
    t = p.read_text(encoding="utf-8")
    for a, b in SUBS:
        t = t.replace(a, b)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(t, encoding="utf-8")
    out.chmod(out.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    left = [x for x in ("__HOME__", "__OPENCODE_ROOT__", "__LOCAL_BIN__",
                        "__ECC_ROOT__", "Bugbonty") if x in t]
    left_all += left
    print(f"  {'\u2713' if not left else '\u2717'} {out} "
          f"({out.stat().st_size} B)" + (f" PLACEHOLDERS SIN RESOLVER: {left}" if left else ""))
rd = srcdir / "RECON_PRO_README.md"
if rd.is_file():
    t = rd.read_text(encoding="utf-8")
    for a, b in SUBS:
        t = t.replace(a, b)
    (docdir / "README.md").write_text(t, encoding="utf-8")
    print(f"  \u2713 {docdir}/README.md")
sys.exit(1 if left_all else 0)
PYRECON
    ok "recon + bbrecon en $BIN_DIR"
  else
    warn "no existe $SRC/recon (motor de recon no instalado)"
  fi

  step "Espacio de trabajo BugBounty"
  WSP="${WSP:-$HOME/BugBounty}"
  mkdir -p "$WSP/templates" "$WSP/.repo"
  if [ -d "$DEST/templates" ]; then
    cp -n "$DEST/templates/"*.md "$WSP/templates/" 2>/dev/null || true
  fi
  ok "$WSP (templates: $(ls -1 "$WSP/templates" 2>/dev/null | wc -l))"
fi

# ── 4. verificación local (sin tocar la config real) ─────────────────
if [ "$VERIFY" -eq 1 ] && [ "$DRY" -eq 0 ] && command -v opencode >/dev/null 2>&1; then
  step "Verificación con el binario de OpenCode"
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$DEST/opencode.json" 2>/dev/null; then
    ok "opencode.json es JSON válido"
  else
    err "opencode.json NO es JSON válido"
    exit 1
  fi

  # agentes descubiertos
  # Se comprueba desde $HOME: es el directorio de trabajo habitual, así que el
  # servicio lo resuelve a la primera. Al terminar esta misma instalación el
  # servicio REINDEXA los ficheros recién escritos y `opencode debug agents`
  # devuelve 0 durante unos segundos — se da un tiempo de calentamiento y se
  # reintenta hasta 10 veces. En un directorio nuevo el patrón es 0 → 7 → 88.
  if ! python3 - "$DEST" <<'PYAGENTS'
import json, os, pathlib, subprocess, sys, time

dest = pathlib.Path(sys.argv[1])
home = os.environ["HOME"]
expected = {p.stem for p in (dest / "agents").glob("*.md")}
d, err = [], ""
time.sleep(2)                      # calentamiento: deja terminar el reindexado
for attempt in range(1, 11):
    try:
        r = subprocess.run(["opencode", "debug", "agents"], cwd=home,
                           capture_output=True, text=True, timeout=60)
    except Exception as e:
        err = str(e); time.sleep(3); continue
    try:
        d = json.loads(r.stdout)
    except Exception as e:
        err = f"JSON inválido: {e}"; time.sleep(3); continue
    if expected <= {a.get("id") for a in d}:
        break
    err = (f"sólo {len(d)} agentes, faltan "
           f"{len(expected - {a.get('id') for a in d})} (intento {attempt}/10)")
    time.sleep(3)

ids = {a.get("id") for a in d}
missing = sorted(expected - ids)
mine = [a for a in d if a.get("id") in expected]
nocfg = sorted(a["id"] for a in mine if not (a.get("system") or "").strip())
factory = len(d) - len(mine)
print(f"  agentes descubiertos: {len(d)} · propios: {len(mine)}/{len(expected)} · "
      f"fábrica: {factory}")
if missing:
    print(f"  ✗ NO descubiertos ({len(missing)}): {missing[:8]}")
    if err:
        print(f"    ({err})")
else:
    print(f"  ✓ los {len(expected)} agentes propios se descubren")
if nocfg:
    print(f"  ✗ sin system prompt: {nocfg[:5]}")
else:
    print("  ✓ todos con system prompt")
if factory < 6:
    print(f"  ⚠ sólo {factory} agentes de fábrica (esperaba 7)")
sys.exit(1 if (missing or nocfg) else 0)
PYAGENTS
  then
    err "validación de agentes fallida"
    exit 1
  fi

  if out="$(opencode debug config 2>/dev/null)"; then
    printf '%s' "$out" | python3 -c "
import json,sys
d=json.load(sys.stdin)
docs=[x for x in d if x.get('type')=='document']
print(f'  fuentes de config: {len(d)} ({len(docs)} documentos)')
" 2>/dev/null || true
  fi
fi

step "Resumen"
say "  destino      : $DEST"
say "  agentes      : $(find "$DEST/agents" -name '*.md' 2>/dev/null | wc -l)"
say "  skills       : $(find "$DEST/skills" -name 'SKILL.md' 2>/dev/null | wc -l) (ciber) + $(find "$DEST/skills-ecc" -name 'SKILL.md' 2>/dev/null | wc -l) (ecc)"
say "  comandos     : $(find "$DEST/commands" -name '*.md' 2>/dev/null | wc -l)"
say "  tools        : $(find "$DEST/tools" -type f 2>/dev/null | wc -l)"
say "  reglas       : $(find "$DEST/rules" -name '*.md' 2>/dev/null | wc -l)"
say "  plantillas   : $(find "$DEST/templates" -name '*.md' 2>/dev/null | wc -l)"
_BIN="${BIN_DIR:-$HOME/.local/bin}"
say "  recon        : $([ -x "$_BIN/recon" ] && echo "✓ $_BIN/recon" || echo "✗ no instalado")"
say "  bbrecon      : $([ -x "$_BIN/bbrecon" ] && echo "✓ $_BIN/bbrecon" || echo "✗ no instalado")"
say "  workspace    : $([ -d "$HOME/BugBounty" ] && echo "✓ $HOME/BugBounty" || echo "✗ no creado")"
if [ -f "$SVC" ]; then
  ok "service.json intacto (sha256=$(sha256sum < "$SVC" | cut -c1-16))"
fi
say ""
say "Siguiente: abre OpenCode y comprueba con:"
say "  opencode debug agents   # 88 = 7 fábrica + 81 tuyos"
say "  opencode mcp list       # 7 MCPs"
