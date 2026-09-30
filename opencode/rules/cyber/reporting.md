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

## 4. Matriz de Severidad
| ID | Severidad | Estado (abierto/remediado) |

## 5. Recomendaciones Priorizadas
1. ...
## 6. Anexos
- Comandos utilizados (audit log)
- Notas de alcance
```

## 2. Reglas de Reporte

- **Evidencia sanitizada:** nunca incluir secretos, datos personales reales ni payloads dañinos en el reporte.
- **Toda severidad**: CRÍTICA/ALTA deben incluir PoC reproducible en el entorno autorizado.
- **Remediación**: cada hallazgo crítico/alto con pasos de mitigación accionables.
- **Traza**: referenciar el `audit.log` para demostrar autorización y trazabilidad.

## 3. Gerente del reporte

El agente `pentest-report-agent` consolida los hallazgos de todas las fases. Verificar con `red-team-lead` antes de entregar.