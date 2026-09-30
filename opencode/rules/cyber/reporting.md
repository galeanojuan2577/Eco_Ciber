# Pentest Reporting Policy

Regla para la elaboración del **informe final de pruebas de seguridad**. Todo pentest del ecosistema debe terminar con un informe estructurado.

## 1. Formato del Informe (Markdown)

`reports/<fecha>_<target>_pentest-report.md`

```
# Informe de Pentest — <target>
Fecha:            YYYY-MM-DD
Alcance (SoW):    [referencia scope.json]
Tester:           [operador / red-team-lead]
Estado:           DRAFT | FINAL

## 1. Resumen Ejecutivo
- Objetivo y alcance
- Resumen de hallazgos (tabla: ID, severidad, título)
- Veredicto general

## 2. Metodología y Fases
- Recon → Scan → Enumeración → Explotación → Post-explotación → Reporting

## 3. Hallazgos Detallados
Para cada hallazgo (ID):
- Título
- Severidad: CRÍTICA | ALTA | MEDIA | BAJA | INFO
- Descripción
- Evidencia (PoC, comandos, outputs sanitizados)
- Impacto
- Remediación recomendada
- Referencias (CWE/CVE si aplica)
- **MITRE ATT&CK**: technique ID (ej: T1190 - Exploitation for Initial Access)
- **NIST CSF 2.0**: category (ej: DE.CM-01 - Networks and Environment)

## 4. Matriz de Severidad
| ID | Severidad | Estado (abierto/remediado) |

## 5. Framework Coverage Matrix
| Framework | Tactics/Functions Cubiertos | Skills Utilizados |
|-----------|---------------------------|-------------------|
| MITRE ATT&CK v19.1 | TA0001, TA0002, TA0003... | scanning-web-applications-with-nikto, ... |
| NIST CSF 2.0 | DE.CM-01, RS.AN-03... | ... |
| MITRE ATLAS | AML.T0047... | (si aplica AI/ML) |
| MITRE D3FEND | D3-NTA... | (contramedidas recomendadas) |

## 6. Recomendaciones Priorizadas
1. ...
## 7. Anexos
- Comandos utilizados (audit log)
- Notas de alcance
- Skills ACS utilizados (lista completa)
```

## 2. Reglas de Reporte

- **Evidencia sanitizada:** nunca incluir secretos, datos personales reales ni payloads dañinos en el reporte.
- **Toda severidad**: CRÍTICA/ALTA deben incluir PoC reproducible en el entorno autorizado.
- **Remediación**: cada hallazgo crítico/alto con pasos de mitigación accionables.
- **Traza**: referenciar el `audit.log` para demostrar autorización y trazabilidad.

## 3. Gerente del reporte

El agente `pentest-report-agent` consolida los hallazgos de todas las fases. Verificar con `red-team-lead` antes de entregar.