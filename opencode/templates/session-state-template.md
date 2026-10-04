# Session State — {{proyecto}} (plantilla por turno)

> Plantilla **parametrizable** para la continuidad de sesión (`rules/cyber/session-continuity.md`).
> **Complementa** a `__OPENCODE_ROOT__/templates/session-state.md`, que cubre el estado por fases y orgs de todo el engagement;
> esta cubre el **handoff entre turnos**: target actual, fase, hallazgos abiertos, pendientes y decisiones de scope.
> Copiar a `__HOME__/BugBounty/{{proyecto}}/SESSION-STATE.md` y regenerar/actualizar en cada turno.

**Proyecto:** {{proyecto}} · **Pin activo:** `project-context.sh get` → {{proyecto}}
**Turno:** {{YYYY-MM-DD_HH:MM}} · **Fase:** {{recon|scan|enumerate|exploit|post-exploit|report|cleanup}}
**Última acción:** {{resumen_de_una_linea}}
**Próxima acción:** {{siguiente_paso_concreto}}

---

## 1. Target actual

| Campo | Valor |
|---|---|
| Target | {{host_o_url}} |
| Scope verificado | `scope-validate.sh {{target}}` → `[IN SCOPE]` ({{fecha}}) |
| Tipo de test autorizado | {{recon/scan/enumerate/exploit/post-exploit/dos/phishing}} |
| Herramientas en curso / colgadas | {{ninguna_o_lista_con_pid}} |

## 2. Hallazgos abiertos

| ID | Severidad | Target | Estado | Nota del turno |
|---|---|---|---|---|
| {{H-001}} | {{critical/high/medium/low/info}} | {{target}} | {{abierto|en curso|confirmado|descartado}} | {{nota}} |
| {{H-002}} | {{severidad}} | {{target}} | {{estado}} | {{nota}} |

- **Descartados este turno (y por qué):** {{falsos_positivos_o_fuera_de_alcance}}

## 3. Pendientes del siguiente turno

1. {{pendiente_1 — con comando/ruta previstos}}
2. {{pendiente_2}}
3. {{pendiente_3}}

- **Blockers:** {{blocker_actual}}
- **Requisitos previos pendientes:** {{credenciales_endpoint_wordlist}}

## 4. Decisiones de scope

| Fecha | Decisión | Registrada en |
|---|---|---|
| {{YYYY-MM-DD}} | {{añadido/retirado}} `{{target}}` — {{motivo}} | `authorize.sh add/remove {{target}} {{tipo}}` |
| {{YYYY-MM-DD}} | {{excepción confirmada por el usuario}} | audit.log `[proyecto={{proyecto}}]` |

- **Fuera de alcance detectado este turno:** {{targets_out_of_scope}}
- **Confirmaciones del usuario pendientes:** {{lista_o_ninguna}}

## 5. Evidencias y rutas

- Recon: `__HOME__/BugBounty/{{proyecto}}/recon/` (triage en `recon/triage/`)
- Testing: `__HOME__/BugBounty/{{proyecto}}/testing/`
- Evidencias: `__HOME__/BugBounty/{{proyecto}}/evidence/`
- Informes: `__HOME__/BugBounty/{{proyecto}}/reports/`
- Credenciales: `creds.env` (chmod 600) — **nunca pegar secretos aquí**

## 6. Retomar tras reinicio (checklist)

- [ ] `project-context.sh get` → proyecto activo correcto
- [ ] Leer este fichero completo (secciones 1-4)
- [ ] `authorize.sh status` + `scope-validate.sh {{target}}`
- [ ] `tail -n 20 __OPENCODE_ROOT__/cyber/audit.log`
- [ ] Estado con más de 48h → re-verificar alcance y avisar al usuario

## 7. Learnings de este turno

- {{aprendizaje → patterns-log.md}}
- {{error cometido → mistakes-log.md}}
