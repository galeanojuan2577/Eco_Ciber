#!/usr/bin/env bash
# test-offsite-backoff.sh — regresión del backoff de obsidian-offsite.sh
#
# Valida con rclone SIMULADO que la copia offsite se auto-sanita ante el
# 403 RATE_LIMIT_EXCEEDED del client_id compartido de rclone:
#   Test A: rclone falla 2 veces y al 3º → [ok], exit 0, SIN notificación
#   Test B: rclone falla siempre → 3 intentos, [FALLO], notificación
#           "tras 3 intentos", exit 1
#
# Uso: bash test-offsite-backoff.sh   (exit 0 = todo OK)
# Overrides: OFFSITE_SCRIPT (ruta al script bajo test)
set -uo pipefail

SCRIPT="${OFFSITE_SCRIPT:-$HOME/.local/share/bin/obsidian-offsite.sh}"
[[ -f "$SCRIPT" ]] || { echo "no existe: $SCRIPT"; exit 2; }

WORK=$(mktemp -d)                # estado, logs y binarios falsos (auto-limpieza)
trap 'rm -rf "$WORK"' EXIT
FAKE="$WORK/fakebin"; STATE="$WORK/state"
mkdir -p "$FAKE" "$STATE"

# rclone simulado: cuenta corridas; A falla 2× y luego OK, B falla siempre
cat >"$FAKE/rclone" <<'EOS'
#!/usr/bin/env bash
S="${FAKE_STATE:?}"
n=$(cat "$S/count" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" >"$S/count"
mode=$(cat "$S/mode" 2>/dev/null || echo A)
[[ $mode == A && $n -gt 2 ]] && exit 0
echo "simulated: Error 403 rateLimitExceeded (fake)"; exit 1
EOS
# notify-send simulado: captura args en vez de emitir notificación real
cat >"$FAKE/notify-send" <<'EOS'
#!/usr/bin/env bash
echo "NOTIFY: $*" >>"${FAKE_STATE:?}/notify-capture"
EOS
chmod +x "$FAKE/rclone" "$FAKE/notify-send"

run_test() {   # run_test <modo> <nombre> → imprime exit code
    echo "$1" >"$STATE/mode"; rm -f "$STATE/count" "$STATE/notify-capture"
    PATH="$FAKE:$PATH" FAKE_STATE="$STATE" \
        OFFSITE_LOG="$WORK/test-$2.log" \
        OFFSITE_ATTEMPTS=3 OFFSITE_BACKOFF="1 1" \
        bash "$SCRIPT" >/dev/null 2>&1
    echo $?
}

fail=0
echo "════ Test A: 2 fallos → éxito sin notificar ════"
rc=$(run_test A A); logA=$(cat "$WORK/test-A.log" 2>/dev/null)
ok() { printf '  ✅ %s\n' "$1"; }
ko() { printf '  ❌ %s\n' "$1"; fail=1; }
grep -q '\[intento 1/3\]'          <<<"$logA" && ok "intento 1 registrado"        || ko "falta intento 1"
grep -q '\[reintento\] exit=1 → espero 1s' <<<"$logA" && ok "backoff tras fallo 1" || ko "falta reintento 1"
grep -q '\[intento 3/3\]'          <<<"$logA" && ok "llegó al intento 3"          || ko "no llegó al intento 3"
grep -q '\[ok\] offsite sincronizado' <<<"$logA" && ok "[ok] final"                || ko "sin [ok]"
[[ "$rc" == 0 ]] && ok "exit=0" || ko "exit=$rc"
[[ ! -f "$STATE/notify-capture" ]] && ok "SIN notificación (correcto)" || ko "notificó en falso"

echo "════ Test B: fallo total → notifica y sale 1 ════"
rc=$(run_test B B); logB=$(cat "$WORK/test-B.log" 2>/dev/null)
n_int=$(grep -c '\[intento' <<<"$logB")
[[ "$n_int" == 3 ]] && ok "exactamente 3 intentos" || ko "intentos=$n_int"
grep -q '\[FALLO\].*tras 3 intentos' <<<"$logB" && ok "[FALLO] tras agotar"       || ko "sin [FALLO]"
grep -q 'exit=1 tras 3 intentos' "$STATE/notify-capture" 2>/dev/null \
    && ok "notificación con 'tras 3 intentos'" || ko "notificación ausente/mal"
[[ "$rc" == 1 ]] && ok "exit=1" || ko "exit=$rc"
grep -q 'se omite este run' <<<"$logB" && ko "bloqueo de lock: test inválido" || true

echo
if [[ $fail -eq 0 ]]; then echo "RESULTADO: 2/2 tests PASAN ✅"; else echo "RESULTADO: HAY FALLOS ❌"; fi
exit $fail
