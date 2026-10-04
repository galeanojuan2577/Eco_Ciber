# Ecosistema de Ciberseguridad — Instrucciones globales

**81 agentes** · **437 skills** (166 ciber + 271 ingeniería) · **11 comandos `/pentest/*`** · **7 MCPs** · **26 tools** · stack ofensivo-defensivo para hacking ético **siempre con autorización explícita**.

> Este fichero se carga en **todas** las sesiones. Todo lo situacional (fases concretas, casos de uso) vive en los **skills** y sólo se carga cuando toca.

---

## 1. Idioma

⚠️ **Siempre responder en español. Sin excepción.**

---

## 2. Rutas del ecosistema

| Placeholder | Equivale a |
|---|---|
| `__OPENCODE_ROOT__` | `~/.config/opencode` |
| `__ECC_ROOT__` | clon del repositorio Eco_Ciber (`ecc/`) — **sólo existe en el repo** |
| `__HOME__` | `$HOME` |
| `__LOCAL_BIN__` | `~/.local/bin` |

En **destino** los skills viven en dos carpetas separadas, ambas bajo `__OPENCODE_ROOT__`:

| Carpeta | Origen | Contenido |
|---|---|---|
| `__OPENCODE_ROOT__/skills/` | `opencode/skills/` | 166 skills de ciberseguridad |
| `__OPENCODE_ROOT__/skills-ecc/` | `ecc/skills/` | 271 skills de ingeniería de software |

`opencode.json` declara ambas en el array `skills`, por eso el clon (`__ECC_ROOT__`)
**no** se referencia desde ninguna instrucción que se cargue en una sesión.

Los ficheros de **instalación** del repo llevan placeholders; `eco-install.sh` los resuelve al instalar. **Nunca** escribas rutas `/root/...` ni `/home/diego/...` en el repo.

Los espacios de trabajo de engagements viven en `__HOME__/BugBounty/<proyecto>/`.

---

## 3. GATE DE AUTORIZACIÓN — obligatorio

**Regla de oro:** ANTES de **cualquier** acción activa sobre un target (recon, scan, enumerate, exploit, post-exploit, dos, phishing), ejecuta el gate:

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh <target> <tipo_test>
```

| Exit | Significado | Qué hace el agente |
|---|---|---|
| `0` | **IN SCOPE** — coincide con el scope del proyecto activo | Procede y registra la acción en el audit log |
| `1` | **NEEDS CONFIRM** — fuera de scope / autorización vencida / tipo no autorizado / sólo en scope global | **STOP. Pregunta al usuario** si es legal y consentida. Si confirma explícitamente, repite con `--force` y regístralo. Si no confirma → aborta |
| `2` | **HARD DENY** — el target pertenece al scope de **OTRO** proyecto | **STOP, rechazo duro.** No se fuerza. Cambia de proyecto con `project-context.sh set <proyecto>` |
| `3` | **USAGE ERROR** — sin argumentos o sin ningún fichero de scope | Registra la autorización primero |

Registro de cada acción (evidencia y trazabilidad):

```bash
bash __OPENCODE_ROOT__/tools/audit-log.sh "<tool> <target> <tipo>"
```

El log queda en `__OPENCODE_ROOT__/cyber/audit.log` con etiqueta `[proyecto=X]`.

**Nunca inventar autorización.** Si no hay confirmación explícita del usuario, preguntar. Prohibido: daño permanente, exfiltración real, DoS destructivo, phishing real sin autorización escrita.

Registro y consulta del alcance:

```bash
bash __OPENCODE_ROOT__/tools/authorize.sh status          # estado + path del scope
bash __OPENCODE_ROOT__/tools/authorize.sh list            # targets autorizados
bash __OPENCODE_ROOT__/tools/scope.sh --all               # resumen de todos los proyectos
bash __OPENCODE_ROOT__/tools/authorize.sh init <url>      # crear scope de un proyecto
bash __OPENCODE_ROOT__/tools/authorize.sh add <target> <tipo> [duración]
```

Duraciones tipo `2h`, `7d`, `30d` **vencen automáticamente**: el gate devuelve `1` cuando caducan.

---

## 4. Aislamiento por proyecto

Cada bug bounty se valida de forma **independiente**.

```
__OPENCODE_ROOT__/cyber/
├── session.json                      ← pin: proyecto activo de ESTA sesión
├── projects/<proyecto>/scope.json    ← única fuente de verdad del proyecto
├── archived/<proyecto>-scope.json    ← proyectos finalizados (historial)
└── audit.log                         ← auditoría global etiquetada [proyecto=X]
```

1. Un target **sólo** se autoriza contra el scope de **su** proyecto.
2. Al empezar un proyecto nuevo: `project-context.sh set <proyecto>` → `authorize.sh init <url>` → `authorize.sh add <target> <tipo>`.
3. Sesión = **un solo proyecto**. Al cambiar de bug bounty, cambiar el pin **siempre**.
4. Target de otro proyecto → exit `2`, bloqueado. No se ataca de un proyecto con el scope de otro.
5. Al terminar: `authorize.sh archive <proyecto>` → pasa a `archived/`. **No borrar `archived/`**, es la memoria del ecosistema.

---

## 5. Escritura de ficheros

- Los **subagentes** sólo escriben dentro de `__HOME__/BugBounty/<proyecto>/` y `__OPENCODE_ROOT__/`.
- **Jamás** escribir fuera de esos directorios sin confirmación del usuario.
- Los agentes de sólo-lectura llevan `edit: deny` en sus `permissions` de V2 — **no intentes saltártelo**.
- Las escrituras pasan por el permiso `edit` de V2: si está denegado, pide el cambio al usuario en lugar de reintentar.

---

## 6. Invocación de herramientas

- **Argumentos siempre explícitos.** Nunca lances un binario sin argumentos: muchas herramientas esperan stdin o entran en modo interactivo.
- Redirige stdin en sondeos: `< /dev/null`. Muchas herramientas se cuelgan si heredan un stdin abierto.
- Limita lo que puede bloquear: `timeout 8 <tool> -h` para comprobar ayuda; `timeout 60` para escaneos cortos.
- Captura y reporta el **exit code**. `126`/`127` y `129`–`165` significan *herramienta rota*, no *sin hallazgos*.
- No pipes que oculten fallos: si encadenas, usa `set -o pipefail` o comprueba `$?`.
- Lee `__OPENCODE_ROOT__/rules/cyber/tool-invocation.md` para el detalle.

---

## 7. Continuidad de sesión

Al empezar y al terminar cada sesión relevante, persiste el estado en `__HOME__/BugBounty/<proyecto>/SESSION-STATE.md`: target actual, fase, hallazgos abiertos, pendientes y decisiones de scope. Detalle en `__OPENCODE_ROOT__/rules/cyber/session-continuity.md`.

---

## 8. Limpieza (obligatoria al cerrar un engagement)

1. Listar artefactos creados (revisar `audit.log`).
2. Detener procesos/daemons levantados para la prueba (`pkill -x <comm>`, no `-f`).
3. Borrar temporales de `__HOME__/BugBounty/<proyecto>/`.
4. Eliminar credenciales/datos sensibles capturados que ya no hagan falta.
5. Dejar el informe actualizado y registrar `audit-log.sh "cleanup: <detalle>"`.

**Conservar** logs, informes y `scope.json` si el engagement sigue activo.

---

## 9. Informe

Todo pentest termina con un informe en `__HOME__/BugBounty/<proyecto>/reports/<fecha>_<target>_pentest-report.md`: resumen ejecutivo, metodología, hallazgos con severidad (CRÍTICA/ALTA/MEDIA/BAJA/INFO), PoC reproducible, impacto, remediación y traza hacia `audit.log`.

- Evidencia **sanitizada**: nunca secretos, datos personales reales ni payloads dañinos.
- Severidad CRÍTICA/ALTA exige PoC reproducible **en el entorno autorizado**.
- Plantillas en `__HOME__/BugBounty/templates/`.

---

## 10. Enrutamiento → agentes

| Tarea | Agente |
|---|---|
| Recon / OSINT | `recon-agent` |
| Escaneo de vulnerabilidades | `scanner-agent` |
| Enumeración web/API | `enumerator-agent` |
| Explotación | `exploiter-agent` |
| Post-explotación | `post-exploitation-agent` |
| Informe | `pentest-report-agent` |
| Orquestar un pentest completo | `red-team-lead` |
| DoS / estrés (autorizado) | `dos-tester` |
| Simulación de phishing | `phishing-sim-agent` |
| Forensics | `forensics-agent` · `malware-analyst-agent` |
| Threat hunting | `threat-hunting-agent` |
| Revisión de seguridad | `security-reviewer` · `cyber-ciso` |
| Arquitectura / planificación | `planner` · `architect` · `code-architect` |
| TDD | `tdd-guide` |
| Code review | `code-reviewer` + `*-reviewer` (typescript, python, go, rust, java, php, kotlin, swift, csharp, cpp, dart, flutter, react, vue, django, fastapi, pytorch, mle, healthcare…) |
| Bug de build / error | `build-error-resolver` + `*-build-resolver` |
| Refactor | `refactor-cleaner` |
| DevOps / red | `harness-optimizer` · `network-architect` · `homelab-architect` |

**Delega.** Si una tarea corresponde a un agente, lánzalo como subagente en lugar de hacerla tú.

---

## 11. Comandos

`/pentest/recon` · `/pentest/scan` · `/pentest/enumerate` · `/pentest/exploit` · `/pentest/post-exploit` · `/pentest/pentest-report` · `/pentest/authorize` · `/pentest/dos-test` · `/pentest/phishing-sim` · `/pentest/redteam` · `/agent`

Flujo completo: `authorize` → `recon` → `scan` → `enumerate` → `exploit` → `post-exploit` → `pentest-report`.
Detalle de fases: skill `conducting-network-penetration-test`.

---

## 12. Skills

Se descubren automáticamente en `__OPENCODE_ROOT__/skills/` (166, ciberseguridad) y `__OPENCODE_ROOT__/skills-ecc/` (271, ingeniería de software) — las dos rutas que declara `skills` en `opencode.json`. Se cargan **bajo demanda**; no los cites si no los vas a usar.

Los ficheros de `__OPENCODE_ROOT__/rules/cyber/` son la **documentación detallada** de las reglas permanentes de este fichero: `authorization`, `project-isolation`, `cleanup`, `reporting`, `session-continuity`, `tool-invocation`, `agent-write-permissions`. Las reglas **situacionales** son skills: `dos-testing`, `phishing-sim`, `pentest-flow-detail`.

---

## 13. Seguridad antes de cada commit

No hardcodear secrets · validar inputs · SQL parametrizado · CSRF activo · rate limiting · mensajes de error sin datos sensibles.

**Si aparece un issue de seguridad:** STOP → `security-reviewer` → corregir CRITICAL/HIGH → rotar secrets.

---

## 14. Economía de contexto

- Respuestas cortas y directas, sin preámbulos.
- No repitas código existente: usa `edit` y muestra sólo el cambio.
- Tras cada hito importante, sugiere `/compact`.
- Tarea no trivial **antes** → leer `__OPENCODE_ROOT__/_data/learnings/{mistakes,patterns}-log.md`.
- Tarea no trivial **después** → `bash __OPENCODE_ROOT__/tools/session-review.sh`.
- Inicio de sesión → `bash __OPENCODE_ROOT__/tools/ecc-init.sh`.
