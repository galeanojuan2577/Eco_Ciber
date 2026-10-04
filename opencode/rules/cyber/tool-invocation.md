# Tool Invocation (Invocación de Herramientas)

Regla para **invocar herramientas de forma determinista y segura** desde cualquier agente del ecosistema. Aplica a bash, binarios de red y scripts propios de `__OPENCODE_ROOT__/tools/`.

## 1. Argumentos explícitos (obligatorio)

- SIEMPRE pasar argumentos explícitos a cada herramienta (target, ruta de salida, formato).
- NUNCA invocar un binario "a secas": muchos entran en modo interactivo, escanean de más o esperan stdin y quedan **colgados**.
- NUNCA asumir defaults de un tercero: si la tool no tiene la opción documentada, sondearla antes (ver §2).
- Redactar la llamada completa en `audit-log.sh "<tool> <target> <tipo>"` antes de ejecutarla.

## 2. Sondeos y Timeouts

| Tipo de llamada | Timeout | Ejemplo |
|---|---|---|
| Sondeo de ayuda/version | `timeout 8` | `timeout 8 <tool> --help </dev/null 2>&1 \| head -n 40` |
| Consulta rápida (dns/whois/curl) | `timeout 30` | `timeout 30 curl -sS -o out.json -w '%{http_code}' <url>` |
| Escaneo local (nmap/nuclei/gobuster) | `timeout 300` | `timeout 300 nuclei -u <target> -o out.jsonl` |
| Recon/explotación larga | `timeout 1800` o background | `timeout 1800 <tool> ... > run.log 2>&1 &` |

- Todo proceso lanzado DEBE llevar timeout: `timeout N <tool>` (exit **124** = se superó el tiempo → tratarlo como fallo, no como éxito).
- Procesos largos en background: redirigir a fichero y dejar PID/orden de espera explícito.

## 3. Códigos de salida

- Capturar siempre el código: `rc=0; timeout 30 <tool> ... || rc=$?` y **actuar sobre `rc`** (124 timeout, 127 binario ausente, 1+ error de la tool).
- Scripts propios: `#!/usr/bin/env bash` + `set -euo pipefail` (un fallo inesperado detiene, no continúa en silencio).
- `grep`/`test` pueden devolver 1 sin ser un error real: usar `if ... ; then` o `|| true` de forma consciente.
- Jamás ocultar errores con `2>/dev/null` salvo para sondeos de ayuda; la salida de error sueste ser la única pista.

## 4. stdin

- NUNCA heredar stdin del shell: cualquier tool que pueda leer stdin se traga la entrada y **congela la sesión**.
- Añadir `</dev/null` a toda herramienta que no deba leer nada (`curl`, `nmap`, `nuclei`, `gobuster`, `timeout 8 <tool> --help`).
- Si la tool SÍ necesita stdin, pasarlo por pipe explícito (`printf '%s\n' "$input" | <tool> -`), nunca por herencia.
- Redirigir siempre la salida larga a fichero: `<tool> ... > salida.log 2>&1` (evita desbordar el contexto).

## 5. Procedimiento

1. Sondear la tool si se desconoce: `timeout 8 <tool> --help </dev/null`.
2. Registrar la intención: `audit-log.sh "<tool> <target> <tipo>"`.
3. Invocar con argumentos explícitos, timeout y `</dev/null`.
4. Capturar `rc` + salida + duración; guardar evidencia en la carpeta de la fase.
5. Si `rc != 0` o hay timeout: documentar el fallo en `SESSION-STATE.md` y no repetir la misma llamada a ciegas.

## 6. Prohibido

- NUNCA ejecutar binarios sin argumentos "a ver qué hacen".
- NUNCA dejar procesos ofensivos sin timeout ni dueño identificable.
- NUNCA pipear stdin heredado del agente a una tool externa.
- NUNCA tratar exit 0 como "éxito del escaneo" sin revisar la salida (muchas tools devuelven 0 aunque fallen).
