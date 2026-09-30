---
name: Architect-Factory
description: Orquestador profesional full-stack con escaneo de seguridad, validación de integridad y retroalimentación iterativa.
---

# Architect-Factory: Workflow Operativo (v2.0 Auto-Mejora)

Esta skill actúa como el orquestador principal. Cualquier proceso de desarrollo sigue obligatoriamente este flujo:

## 1. Fase de Escaneo de Seguridad (BLOQUEANTE)
Antes de integrar cualquier repositorio externo o código nuevo, se debe ejecutar el protocolo de seguridad obligatorio:
`python3 __OPENCODE_ROOT__/skills/architect-factory/security_check.py [directorio]`
- **Verificación:** Gitleaks (secretos) + Semgrep (SAST/código malicioso).
- **Acción:** Si el escaneo falla (código de salida != 0), la integración se ABORTA inmediatamente.

### 1.1 Fallback Auto-Cleanup (v2.0)
Si el escaneo deteja secretos expuestos pero el proyecto es interno o de confianza:
1. **Intentar Auto-Remediar:** Ejecutar scrubbing de secretos con regex predefinidos (API keys, tokens JWT, etc.).
2. **Guardar Backups:** Snapshot del estado antes del scrubbing en `/tmp/opencode/skills/.state/pre-scrub/YYYY-MM-DD/`.
3. **Re-escanear:** Volver a ejecutar `security_check.py`. Si pasa, continuar. Si no, abortar y registrar el fallo.

## 2. Fase Iterativa de Requerimientos
- El agente realizará preguntas hasta que el entendimiento sea del 100%.
- Análisis de stack tecnológico basado en los requerimientos.
- **NUEVO (v2.0):** Registro de "satisfacción del usuario" con una rúbrica simple: al final de cada interacción, preguntar internamente "¿Resolví el problema del usuario? ¿Sí/No/Parcialmente?". Si la respuesta es No o Parcialmente, iterar.

## 3. Fase de Desarrollo Full-Stack
- Generación de estructura y código con los mejores patrones detectados.
- Auditoría de seguridad (OWASP Noir) durante la generación.

## 4. Fase de QA y Auto-Retroalimentación (v2.0)
- Ejecución de linters y tests unitarios.
- Si hay errores, la skill entra en un bucle de refactorización hasta que pase el 100% de las pruebas.
- **Bucle Auto-Reparativo:** Si un error persiste por más de 3 intentos:
  1. Guardar contexto completo del error en `/tmp/opencode/skills/learning-logs/architect-factory/{timestamp}_stuck_error.md`.
  2. Cambiar estrategia radicalmente (ej: en lugar de modificar, re-generar desde plantilla, o pivotear de librería).
  3. Documentar el cambio de estrategia como una nueva "Fase Pivot" en este SKILL.md.

## 5. Fase de Documentación
- Generación automática de `SKILL.md` profesional.
- **Auto-Actualización:** Si durante la ejecución se descubre un nuevo patrón o una mejora al workflow, añadirla a esta skill bajo un nuevo heading con fecha (ej: `## Lesson Learned 2026-05-05: ...`).

## 6. Ciclo de Auto-Evaluación y Mejora (v2.0)
Al finalizar cualquier proyecto, se DEBE ejecutar el siguiente check:
1. ¿Hubo errores repetidos que no estaban en guardrails?
2. ¿El escaneo de seguridad atrapó algo que debería haber sido prevenido?
3. ¿El usuario quedó satisfecho?

Si la respuesta a cualquiera es afirmativa, actualizar esta skill con la nueva regla o guardrail.

## 📋 Templates de Auto-Documentación
Para asegurar consistencia, cada nueva lección aprendida DEBE seguir este formato al añadirse a este archivo:

```markdown
## Lesson Learned [YYYY-MM-DD]: [Error Class]
- **Contexto:** [Breve descripción del proyecto/sesión]
- **Síntoma:** [¿Qué falló?]
- **Causa Raíz:** [¿Por qué falló?]
- **Solución Aplicada:** [¿Qué se hizo para arreglarlo?]
- **Regla de Guardia Añadida:** [¿Cómo se previene en el futuro?]
```