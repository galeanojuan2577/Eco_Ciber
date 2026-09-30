---
name: expanded-audit-playbook
description: "Playbook unificado de auditoría para el ecosistema ECC. Consolida mistakes, patterns, verification phases, y health checks en un solo documento de referencia. Usar ANTES de cada tarea no-trivial, DURANTE la ejecución para validación continua, y DESPUÉS para auto-evaluación."
origin: ECC
---

# Expanded Audit Playbook — ECC Ecosystem

## Propósito
Este playbook es el documento central de referencia para mantener la calidad, seguridad y consistencia del ecosistema ECC. Combina learnings históricos (mistakes, patterns), fases de verificación, y health checks en un flujo unificado.

---

## 1. PRE-TASK: Checklist de Inicio (antes de CADA tarea no-trivial)

### 1.1 Learnings Obligatorios
```
□ Leer mistakes-log.md (evitar repetir errores conocidos)
□ Leer patterns-log.md (aplicar patrones comprobados)
□ Verificar que no se va a repetir un mistake pasado
```

### 1.2 Contexto del Proyecto
```
□ Identificar stack tecnológico (TypeScript, Python, Go, Rust, Java, etc.)
□ Cargar skills relevantes al stack actual
□ Verificar reglas de routing en AGENTS.md (package.json → TS, requirements.txt → Python, etc.)
```

### 1.3 Seguridad (SIEMPRE)
```
□ ¿Hay autorización para acción ofensiva? → check-scope.sh ANTES
□ ¿Se están manejando secrets? → No hardcodear
□ ¿Hay inputs de usuario? → Validar siempre
□ ¿Se está usando SQL? → Parametrizado
```

---

## 2. DURING-TASK: Fases de Verificación (durante la ejecución)

### Fase 1: Auto-Discovery
- Verificar que todos los archivos necesarios existen
- Confirmar que el stack detectado coincide con el esperado
- Buscar skills existentes relacionadas (evitar duplicar funcionalidad)

### Fase 2: Code Quality Gate
- Sintaxis correcta del lenguaje
- Convenciones del proyecto (naming, imports, patterns)
- Sin código muerto ni duplicado
- Funciones con responsabilidad única

### Fase 3: Security Gate
- Inputs validados y sanitizados
- No hardcodeo de secrets/keys
- SQL parametrizado
- Autenticación/autorización implementada
- Rate limiting donde aplique

### Fase 4: Test Coverage Gate
- Tests escritos ANTES de la implementación (TDD)
- Cobertura mínima 80% en código nuevo
- Tests unitarios + integración
- Edge cases cubiertos

### Fase 5: Integration Gate
- Compatibilidad con código existente
- No romper funcionalidad existente
- Imports correctos y dependencias declaradas
- Build exitoso (`npm run build`, `make build`, etc.)

### Fase 6: Documentation Gate
- README actualizado si aplica
- Comentarios en código complejo (NO innecesarios)
- CHANGELOG actualizado
- Ejemplos de uso si es API pública

### Fase 7: Patch Completeness Gate
- Verificar que todos los archivos modificados están completos
- No hay marcadores de placeholder sin resolver
- No hay TODOs olvidados
- Dependencias actualizadas si se agregaron nuevas

---

## 3. POST-TASK: Checklist de Cierre (después de CADA tarea no-trivial)

### 3.1 Verificación Automatizada
```
□ Ejecutar lint (npm run lint, eslint, flake8, etc.)
□ Ejecutar typecheck (npm run typecheck, mypy, etc.)
□ Ejecutar tests (npm test, pytest, go test, etc.)
□ Ejecutar build (npm run build, make build, etc.)
```

### 3.2 Health Check
```
□ Ejecutar ecc-init.sh → 5/5 OK
□ Verificar que no se rompieron skills existentes
□ Verificar que no se incrementó el tamaño innecesariamente
```

### 3.3 Auto-Evaluación
```
□ ¿Se cometió algún mistake conocido? → Registrar si es nuevo
□ ¿Se aplicó algún patrón exitoso? → Registrar si es nuevo
□ ¿Hay algo que documentar para el futuro? → Actualizar learnings
```

### 3.4 Session Review
```
□ Ejecutar session-review.sh
□ Registrar hallazgos en mistakes-log.md (si hubo error)
□ Registrar patrones en patterns-log.md (si hubo acierto)
□ Si el mismo error ocurre 2+ veces → AGREGAR instrucción permanente
```

---

## 4. MISTAKES CONOCIDOS (Evitar repetir)

### Mistake 1: Creates NEW files instead of editing existing
- **Causa raíz**: No buscar archivos existentes antes de crear
- **Fix**: SIEMPRE usar glob/grep primero; editar existentes > crear nuevos

### Mistake 2: Does not run verification after changes
- **Causa raíz**: Asumir que "funciona" sin verificar
- **Fix**: SIEMPRE ejecutar lint, typecheck, tests después de cambios

### Mistake 3: Over--engineers solutions
- **Causa raíz**: Agregar features no solicitadas
- **Fix**: Hacer SOLO lo que se pide; nada extra sin preguntar

### Mistake 4: Does not read before edit
- **Causa raíz**: Editar archivos sin entender el contexto actual
- **Fix**: SIEMPRE leer el archivo primero (mínimo 1 vez antes de editar)

### Mistake 5: Confuses skill storage paths
- **Causa raíz**: No distinguir entre `/root/Escritorio/Eco_program-main/ecc/` (repo) y `/root/.config/opencode/` (instalado)
- **Fix**: `/root/Escritorio/` = repo fuente; `/root/.config/opencode/` = instalado y activo

### Mistake 6: Creates skill without verifying ecosystem alignment
- **Causa raíz**: No verificar skills existentes, duplicar funcionalidad, ignorar rules/flows establecidos
- **Fix**: SIEMPRE: (1) glob/grep skills existentes, (2) leer AGENTS.md, (3) verificar rules/flows, (4) preguntar antes de crear si hay duda

---

## 5. PATRONES COMPROBADOS (Aplicar siempre que aplique)

### Patrón 1: Layered Security
Múltiples capas de defensa; no depender de una sola control.

### Patrón 2: Least Privilege
Mínimos privilegios necesarios para cada componente/usuario.

### Patrón 3: Defense in Depth
Profundidad de defensa: perimeter → network → host → application → data.

### Patrón 4: Fail Secure
Fallas seguras por defecto; denegar si hay duda.

### Patrón 5: Separation of Duties
Separación de funciones para reducir riesgo de fraude/error.

### Patrón 6: Security by Design
Seguridad integrada desde el diseño, no agregada después.

### Patrón 7: Zero Trust
No confiar, siempre verificar. Autenticación y autorización continuas.

### Patrón 8: Shift Left
Seguridad y testing lo más temprano posible en el ciclo de vida.

### Patrón 9: Automation First
Automatizar controles repetitivos (CI/CD, scanning, response).

### Patrón 10: Immutable Infrastructure
Infraestructura inmutable; reemplazar, no parchear.

### Patrón 11: API Gateway Security
Gateway como punto central de autenticación, rate limiting, y validación.

### Patrón 12: Container Isolation
Aislamiento de contenedores;最小权限, read-only filesystem.

### Patrón 13: Secret Rotation
Rotación automática de secrets; vida útil mínima.

### Patrón 14: Continuous Monitoring
Monitoreo continuo; alertas tempranas, respuesta rápida.

### Patrón 15: Code Review Gates
Revisión de código obligatoria antes de merge.

### Patrón 16: Dependency Scanning
Escaneo de dependencias en CI/CD; bloquear vulnerabilidades conocidas.

### Patrón 17: Network Segmentation
Segmentación de red para limitar movimiento lateral.

### Patrón 18: Incident Response Plan
Plan de respuesta a incidentes documentado y probado.

### Patrón 19: Ephemeral Credentials
Credenciales temporales; eliminar standing privileges.

---

## 6. ECC HEALTH CHECK (ejecutar periódicamente)

### Verificación de Integridad
```bash
bash /root/.config/opencode/tools/ecc-init.sh
```
Resultado esperado: 5/5 OK, skills count estable, mistakes/patterns actualizados.

### Verificación de Tamaño
```bash
find /root/.config/opencode/skills -name "SKILL.md" -exec wc -l {} + | sort -rn | head -5
```
Archivos > 800 líneas son candidatos a compactación.

### Verificación de Duplicación
```bash
grep -rh "^name:" /root/.config/opencode/skills/*/SKILL.md | sort | uniq -d
```
No debe haber nombres de skill duplicados.

### Verificación de Security Rules
```bash
ls /root/Escritorio/Eco_program-main/ecc/.agents/rules/cyber/
```
Debe existir: `pentest-flow-detail.md` y todos los archivos de rules.

---

## 7. WORKFLOW DE AUDITORÍA COMPLETA

Cuando se pida una auditoría del ecosistema:

1. **Pre-audit**: Ejecutar ecc-init.sh, leer mistakes/patterns
2. **Scan de skills**: Contar, medir tamaños, detectar duplicados
3. **Security review**: Verificar rules, pentest flow, autorizaciones
4. **Health check**: Verificar que todo funciona (5/5 OK)
5. **Report**: Generar hallazgos con severidad y recomendaciones
6. **Post-audit**: Actualizar learnings si hay nuevos hallazgos

---

## 8. REFERENCIAS RÁPIDAS

- **Rules de routing**: `/root/Escritorio/Eco_program-main/ecc/AGENTS.md`
- **Mistakes**: `/root/.config/opencode/_data/learnings/mistakes-log.md`
- **Patterns**: `/root/.config/opencode/_data/learnings/patterns-log.md`
- **Pentest flow**: `/root/Escritorio/Eco_program-main/ecc/.agents/rules/cyber/pentest-flow-detail.md`
- **Init script**: `/root/.config/opencode/tools/ecc-init.sh`
- **Observations**: `/root/.config/opencode/_data/learnings/observations.jsonl`
