# ECC Auto-Bootstrap Instructions

⚠️ **IDIOMA**: Siempre responder en **español**. Sin excepción.

## ⚡ ARRANQUE OBLIGATORIO — EJECUTAR SIEMPRE

**PASO 1:** Ejecuta `bash __OPENCODE_ROOT__/tools/ecc-init.sh`
**PASO 2:** Lee COMPLETAMENTE su output (contiene: security scan, project-detect, learnings, health)
**PASO 3:** Usa el tool `skill` para cargar CADA UNA de las skills listadas en "SKILLS_TO_LOAD"
**PASO 4:** Lee `__OPENCODE_ROOT__/_data/learnings/mistakes-log.md`
**PASO 5:** Lee `__OPENCODE_ROOT__/_data/learnings/patterns-log.md`

NO CONTINUAR SIN COMPLETAR ESTOS 5 PASOS.

## Auto-Carga Reactiva

Tu system prompt lista todas las skills disponibles con descripciones. Cuando detectes que la conversación coincide con la descripción de alguna skill, USA el tool `skill` para cargarla automáticamente antes de continuar. Sé proactivo, no esperes a que el usuario la pida.

## Optimización de Tokens (SIEMPRE ACTIVA)
- Respuestas ultracortas, sin preámbulos, sin resúmenes, sin explicaciones
- No repetir código existente — solo mostrar cambios con `edit`
- No añadir comentarios al código a menos que sean necesarios
- Skills del stack actual tienen prioridad sobre skills genéricas
- Después de cada hito, sugerir `/compact`

## 🔁 AUTO-EVALUACIÓN OBLIGATORIA (NO OPCIONAL)

**Antes de CADA tarea no-trivial:**
1. Lee mistakes-log.md y patterns-log.md
2. Verifica que no vas a repetir un error pasado

**Después de CADA tarea no-trivial:**
1. Ejecuta `bash __OPENCODE_ROOT__/tools/session-review.sh`
2. Si hubo error → REGÍSTRALO en mistakes-log.md con causa raíz + fix + gatillo
3. Si hubo acierto repetible → REGÍSTRALO en patterns-log.md
4. Si el mismo error ocurre 2+ veces → AGREGA instrucción permanente aquí mismo

Sin excepción. Sin olvido. Sin autoengaño.

## Auto-Mantenimiento
- `ecc-test` — suite de pruebas completa (25 tests)
- `ecosystem-health` — auditoría completa del ecosistema
- `config-heal fix` — repara drift automáticamente (agentes, comandos, SOUL.md)
- `backup-config` — backup timestamped de opencode.json (guarda últimos 10)
- `ecc-status.html` — dashboard visual en __OPENCODE_ROOT__/ecc-status.html
