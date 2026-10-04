# Session Continuity (Continuidad de Sesión)

Regla para **mantener el contexto entre turnos y reinicios**. Cada engagement persiste su estado en `__HOME__/BugBounty/<proyecto>/SESSION-STATE.md`, de modo que cualquier turno —o cualquier sesión tras un reinicio— pueda retomar exactamente donde se quedó, sin repetir trabajo ni re-abrir targets ya descartados.

## 1. Dónde vive el estado

| Archivo | Contenido | Quién lo escribe |
|---|---|---|
| `__HOME__/BugBounty/<proyecto>/SESSION-STATE.md` | Estado vivo del engagement | agente principal, al final de cada turno |
| `__OPENCODE_ROOT__/templates/session-state.md` | Estructura base (fases, orgs, blockers) | plantilla de referencia (no editar) |
| `__OPENCODE_ROOT__/templates/session-state-template.md` | Versión parametrizable con `{{placeholders}}` | al iniciar un proyecto nuevo |
| `__OPENCODE_ROOT__/cyber/session.json` | Pin del proyecto activo | `project-context.sh set <proyecto>` |
| `__OPENCODE_ROOT__/cyber/audit.log` | Historial de acciones ofensivas | `audit-log.sh` |

## 2. Qué persistir SIEMPRE

1. **Target actual** y la fase exacta en la que se quedó (recon → scan → enumerate → exploit → post-exploit → report).
2. **Hallazgos abiertos**: qué se confirmó, qué está en curso, qué quedó descartado y por qué.
3. **Pendientes**: la siguiente acción concreta, el comando previsto y sus prerequisitos.
4. **Decisiones de scope**: targets añadidos/retirados, excepciones confirmadas por el usuario, tipo de test autorizado (`authorize.sh`).
5. **Bloqueadores** y la *referencia* a credenciales (`creds.env`, chmod 600) — nunca secretos en claro.
6. **Rutas de evidencias** generadas (`recon/`, `testing/`, `evidence/`, `reports/`).

## 3. Cuándo guardar

- Al **final de cada turno** que haya ejecutado acciones ofensivas o producido hallazgos.
- **Antes** de un reinicio, una compactación de contexto o un cambio de proyecto.
- Al **cambiar de fase** o al recibir del usuario una decisión nueva de alcance.
- En cuanto aparezca un **blocker** que impida continuar.

## 4. Cómo retomar tras reinicio

1. `project-context.sh get` → confirmar el proyecto activo (`__OPENCODE_ROOT__/cyber/session.json`).
2. Leer completo `__HOME__/BugBounty/<proyecto>/SESSION-STATE.md` (target actual, fase, hallazgos abiertos, pendientes).
3. `authorize.sh status` y `scope-validate.sh <target>` → re-validar que el alcance sigue vigente.
4. `tail -n 20 __OPENCODE_ROOT__/cyber/audit.log` → últimas acciones registradas.
5. Reanudar por el primer **pendiente**, sin repetir pasos ya hechos.
6. Si el estado tiene más de 48h: re-verificar alcance y avisar al usuario antes de reanudar.

## 5. Prohibido

- NUNCA iniciar acciones ofensivas sin leer antes el `SESSION-STATE.md` del proyecto activo.
- NUNCA persistir secretos, tokens o contraseñas en el estado (solo referencia a `creds.env`).
- NUNCA mezclar el estado de dos proyectos en el mismo fichero.
- NUNCA borrar el historial de sesiones anteriores: se añade o se secciona por fecha, no se destruye.
- NUNCA dar por bueno un estado desactualizado sin re-validar scope y autorización.
