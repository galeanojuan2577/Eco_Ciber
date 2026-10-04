# Agent Write Permissions (Permisos de Escritura de Agentes)

Regla **obligatoria** que define qué agente puede escribir y dónde. Aplica a todos los agentes, subagentes y tools del Ecosistema de Ciberseguridad. La escritura fuera de los directorios permitidos es una violación de aislamiento.

## 1. Directorios permitidos

| Directorio | Escritura | Uso |
|---|---|---|
| `__HOME__/BugBounty/<proyecto>/` | ✅ (solo proyecto activo) | `recon/`, `testing/`, `evidence/`, `reports/`, `SESSION-STATE.md` |
| `__OPENCODE_ROOT__/` | ✅ | tools, templates, rules, `cyber/` (scope, session, audit.log) |
| Resto del sistema (`/etc`, `/usr`, `/var`, `/opt`, home del usuario…) | ❌ | nunca |
| `__HOME__/BugBounty/<otro_proyecto>/` | ❌ | aislamiento por proyecto (`project-isolation.md`) |

1. Todo subagente escribe **solo** dentro de `__HOME__/BugBounty/<proyecto>/` y `__OPENCODE_ROOT__/`.
2. El `<proyecto>` debe ser el **proyecto activo** (`project-context.sh get`); si no coincide → DETENERSE.
3. Escrituras temporales de sistema (si una tool las exige) requieren confirmación previa del usuario (§3).

## 2. Agentes de sólo-lectura

- Los agentes marcados `write:false` / de sólo-lectura (p. ej. `exploiter-agent`, `post-exploitation-agent`, `dos-tester`, `phishing-sim-agent`) declaran **`edit: deny`** (y `write: deny`) en sus permisos: no crean ni modifican ficheros.
- Sus outputs se capturan en stdout/log y los persiste otro agente autorizado (`pentest-report-agent`, `red-team-lead`).
- Un agente de sólo-lectura NUNCA "se autorrepara" editando su propia definición ni ninguna regla/tool.

## 3. Escritura fuera de los directorios permitidos

1. Formular al usuario qué se va a escribir, en qué ruta exacta y por qué es imprescindible.
2. Esperar **confirmación explícita** ("sí, puedes escribir ahí"); la autorización de un `scope.json` NO cubre escrituras de filesystem.
3. Ejecutar la escritura mínima posible (un fichero, sin sobrescrituras masivas).
4. Registrar la excepción: `audit-log.sh "write-exception <ruta> motivo=<...>"`.

## 4. Verificación

- Antes de cada `edit`/`write`: comprobar que la ruta está bajo `__HOME__/BugBounty/<proyecto>/` o `__OPENCODE_ROOT__/`.
- En scripts propios: `set -euo pipefail` y validar rutas de entrada (`${1:?Usage: ...}`) antes de tocar nada.
- Tras escribir: verificar `rc=0` y que no se haya modificado ningún fichero fuera del alcance (`git status` si es repo).

## 5. Prohibido

- NUNCA escribir fuera de `__HOME__/BugBounty/<proyecto>/` y `__OPENCODE_ROOT__/` sin confirmación del usuario.
- NUNCA editar reglas (`rules/cyber/*.md`), permisos de agentes o `scope.json` de otro proyecto.
- NUNCA persistir secretos en claro en ficheros del repositorio (usar `creds.env` con chmod 600).
- NUNCA usar `rm`, `mv` o sobrescritura sobre rutas no verificadas (releer antes: son trabajo de otro agente/usuário).
- NUNCA borrar `__OPENCODE_ROOT__/cyber/archived/` ni `audit.log`: son la memoria del ecosistema.
