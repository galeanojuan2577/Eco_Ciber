# Informe de Pentest — {{target}}

> Plantilla parametrizable. Copiar a `__HOME__/BugBounty/{{proyecto}}/reports/{{fecha}}_{{target}}_pentest-report.md` y sustituir cada `{{placeholder}}`.
> Regla aplicable: `__OPENCODE_ROOT__/rules/cyber/reporting.md` · Estado: **{{DRAFT|FINAL}}**

---

## 1. Resumen Ejecutivo

- **Programa / Cliente:** {{programa_o_cliente}}
- **Objetivo del engagement:** {{objetivo}}
- **Periodo:** {{fecha_inicio}} → {{fecha_fin}}
- **Hallazgos:** {{n_critical}} críticos · {{n_high}} altos · {{n_medium}} medios · {{n_low}} bajos · {{n_info}} info
- **Veredicto general:** {{veredicto_en_una_linea}}

## 2. Target y Alcance

| Campo | Valor |
|---|---|
| Targets en scope | {{targets_in_scope}} |
| Exclusiones | {{targets_out_of_scope}} |
| Tipos de test permitidos | {{tipos_de_test}} |
| Fuente de alcance | `__OPENCODE_ROOT__/cyber/projects/{{proyecto}}/scope.json` |
| Limitaciones | {{limitaciones}} |

## 3. Metodología

Fases ejecutadas: recon → scan → enumerate → exploit → post-exploit → report.

| Fase | Herramientas | Ficheros de evidencia |
|---|---|---|
| Recon (pasivo/activo) | {{herramientas_recon}} | `recon/` |
| Scan | {{herramientas_scan}} | `testing/` |
| Enumeración | {{herramientas_enum}} | `testing/` |
| Explotación | {{herramientas_exploit}} | `evidence/` |
| Post-explotación | {{herramientas_post}} | `evidence/` |

- **Fecha de ejecución:** {{fecha_ejecucion}} · **Operador:** {{operador}}
- **Desviaciones del plan:** {{desviaciones}}

## 4. Hallazgos con Severidad

| ID | Severidad | Título | Estado | CWE/CVE | MITRE ATT&CK |
|---|---|---|---|---|---|
| {{H-001}} | critical | {{titulo}} | {{abierto/remediado}} | {{cwe}} | {{T1190}} |
| {{H-002}} | high | {{titulo}} | {{abierto}} | {{cwe}} | {{technique}} |
| {{H-003}} | medium | {{titulo}} | {{abierto}} | {{cwe}} | {{technique}} |
| {{H-004}} | low | {{titulo}} | {{abierto}} | {{cwe}} | — |
| {{H-005}} | info | {{titulo}} | {{informativo}} | — | — |

### {{H-001}} — {{titulo_del_hallazgo}} ({{severidad}})

- **Descripción:** {{descripcion_tecnica}}
- **Vector:** {{endpoint_o_vector}}
- **PoC paso a paso:**
  1. {{paso_1}}
  2. {{paso_2}}
  3. {{paso_3}}
- **Resultado esperado / obtenido:** {{resultado}}
- **Impacto:** {{impacto_negocio_y_tecnico}}
- **Remediación:** {{remediacion_accionable}}
- **Referencias:** {{cwe_cve_urls}}

## 5. PoC y Evidencias

- Evidencias en `__HOME__/BugBounty/{{proyecto}}/evidence/{{H-001}}/` (capturas, respuestas HTTP, logs).
- **Sanitización obligatoria:** sin secretos, sin datos personales reales, sin payloads dañinos (ver `rules/cyber/reporting.md`).
- Comandos reproducibles en el entorno autorizado: {{comandos_reproducibles}}.

## 6. Historia de Autorización

| Fecha | Evento | Registro |
|---|---|---|
| {{fecha}} | SoW / consentimiento del {{programa}} | {{referencia_contrato}} |
| {{fecha}} | Scope registrado | `authorize.sh add {{target}} {{tipo}}` |
| {{fecha}} | Gate de alcance previo a acciones | `scope-validate.sh {{target}}` → `[IN SCOPE]` |
| {{fecha}} | Acciones ofensivas ejecutadas | `__OPENCODE_ROOT__/cyber/audit.log` (etiqueta `[proyecto={{proyecto}}]`) |
| {{fecha}} | Cleanup finalizado | `cleanup.sh {{proyecto}}` |

## 7. Recomendaciones Priorizadas

1. {{recomendacion_1}}
2. {{recomendacion_2}}
3. {{recomendacion_3}}

## 8. Anexos

- Checklist de fases completado: `__OPENCODE_ROOT__/templates/checklist-template.md` → `__HOME__/BugBounty/{{proyecto}}/checklist.md`
- Estado de sesión al cierre: `__HOME__/BugBounty/{{proyecto}}/SESSION-STATE.md`
- Skills/agentes utilizados: {{lista_agentes_y_skills}}
