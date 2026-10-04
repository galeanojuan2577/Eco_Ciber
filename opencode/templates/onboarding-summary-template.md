# Resumen de Alta del Proyecto — {{proyecto}}

> Plantilla parametrizable para **onboarding / handoff**: poner al día a un agente o a un humano nuevo en menos de 5 minutos.
> Generarla al iniciar un proyecto y actualizarla en cada traspaso de sesión.
> Archivo destino: `__HOME__/BugBounty/{{proyecto}}/ONBOARDING.md`

**Actualizado:** {{YYYY-MM-DD_HH:MM}} · **Autor del resumen:** {{agente_o_usuario}} · **Proyecto activo:** {{proyecto}}

## 1. Qué se sabe

| Campo | Valor |
|---|---|
| Programa / plataforma | {{nombre}} — {{url}} |
| Alcance confirmado | {{targets_clave}} (fuente: `__OPENCODE_ROOT__/cyber/projects/{{proyecto}}/scope.json`) |
| Exclusiones relevantes | {{targets_out_of_scope}} |
| Stack detectado | {{tecnologias}} |
| Superficie interesante | {{auth_admin_api_pago}} |
| Cuentas propias de prueba | referencia a `creds.env` (chmod 600; nunca secretos en claro) |
| Contacto del programa | {{contacto}} |

**Hallazgos confirmados hasta la fecha:** {{n}} ({{H-001}} {{severidad}} — {{titulo}}; …)

## 2. Qué se ha probado

| Fase | Estado | Resultado | Evidencia |
|---|---|---|---|
| Recon | {{completo/parcial/no empezado}} | {{resumen}} | `recon/` |
| Scan | {{estado}} | {{resumen}} | `testing/` |
| Enumerate | {{estado}} | {{resumen}} | `testing/` |
| Exploit | {{estado}} | {{resumen}} | `evidence/` |
| Post-exploit | {{estado}} | {{resumen}} | `evidence/` |
| Report | {{estado}} | {{informe_actual}} | `reports/` |

- **Técnicas agotadas / sin fruto:** {{lista — no repetir}}
- **Herramientas que fallaron en este entorno:** {{lista y motivo}}

## 3. Qué queda por hacer

1. {{pendiente_prioritario}}
2. {{pendiente_2}}
3. {{pendiente_3}}

- **Fase actual:** {{fase}} · **Checklist:** `__HOME__/BugBounty/{{proyecto}}/checklist.md` ({{n}}/{{total}} casillas)
- **Estado de sesión:** `__HOME__/BugBounty/{{proyecto}}/SESSION-STATE.md`

## 4. Riesgos y precauciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| {{riesgo_1 — ej. WAF/baneo por rate}} | {{bloqueo_de_ip}} | {{rate limit + ventanas horarias}} |
| {{riesgo_2 — ej. dato sensible de usuarios}} | {{exposición}} | {{sanitizar evidencias, no exfiltrar}} |
| {{riesgo_3 — ej. técnicas destructivas prohibidas}} | {{daño_permanente}} | {{solo lab propio, confirmación previa}} |

- **Siempre:** gate `scope-validate.sh <target>` antes de cada acción ofensiva y traza en `audit.log`.
- **Si algo sale mal / EDR dispara:** DETENERSE → reportar al usuario → registrar en audit log (`rules/cyber/authorization.md`).

## 5. Próximo paso

> **Acción inmediata para el siguiente turno:** {{comando_o_tarea_concreta}}

- Requisitos previos: {{que_hace_falta}}
- Criterio de éxito: {{como_se_sabe_que_termino}}
- Tras ejecutarlo: actualizar `SESSION-STATE.md` y este resumen.
