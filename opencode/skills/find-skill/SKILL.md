---
name: Find-skill
description: Investiga y descubre skills disponibles en el sistema local y repositorios definidos.
---

# Find-skill: Estrategia de Investigación (v2.0 Recursive Discovery)

Esta skill tiene como objetivo automatizar el descubrimiento de nuevas capacidades para el agente.

## Instrucción para el Agente (AUTOMÁTICA)
Cuando el usuario pida buscar una skill, el agente DEBE ejecutar automáticamente el buscador local usando:
`python3 __OPENCODE_ROOT__/skills/find-skill/search_skills.py [QUERY]`

## Acciones de la Skill
- `/list`: Muestra todas las skills instaladas y su ubicación.
- `/search [query]`: Ejecuta automáticamente el script de búsqueda y reporta resultados.
- `/validate`: Verifica que los archivos `SKILL.md` cumplan con el esquema requerido.

## 🧠 Learning Loop & Auto-Mejora (v2.0)
Esta skill mantiene un ciclo de retroalimentación automático para mejorar su propia eficacia.

### Procedimiento ante Fallos en Descubrimiento
1. **Trigger:** Si `search_skills.py` o `validate` reportan un error o falso positivo.
2. **Root Cause Analysis (RCA):**
   - **¿Es el script de búsqueda el problema?** Revisar si la query fue mal parseada.
   - **¿Es la skill encontrada la problemática?** Marcarla como `potentially-broken` en el log interno.
3. **Documentar:** Guardar el caso en `/tmp/opencode/skills/learning-logs/find-skill/`.
4. **Aprender:** Ajustar el algoritmo de búsqueda o el criterio de validación para evitar la recurrencia.

## 🆕 Recursive Discovery & Auto-Validation (v2.0)
Esta skill ahora busca y valida skills de forma más robusta y proactiva.

### Discovery Extendido
1. **Búsqueda Git Modules:** Si el proyecto tiene `.gitmodules`, escanear URLs por si apuntan a repositorios de skills compatibles.
2. **Búsqueda NPM Packages:** Si detecta un paquete cuyo nombre coincide con el patr `opencode-skill-*` o `skill-*`, verificar su README por sección `opencode-skill`.
3. **Búsqueda en Repositorios Definidos:** Si existe un archivo `.skillsources` en el directorio raíz, escaner las URLs listadas.

### Validación Algorítmica (v2.0)
El comando `/validate` ahora escribe un reporte numérico que incluye:
- **Integridad Estructural:** ¿Tiene Frontmatter correcto? ¿Tiene todos los headings obligatorios?
- **Verificación de Ejecutabilidad:** Si la skill menciona un script (ej: `python3 security_check.py`), ¿existe en la ruta mencionada?
- **Puntuación de Calidad:** 0 a 100, basado en completitud de secciones, claridad, y presencia de ejemplos de uso.

### Curación Proactiva
Si `validate` detecta una skill incompleta (score < 75):
1. Registrar el hallazgo en `/tmp/opencode/skills/learning-logs/find-skill/`.
2. Generar un checklist de mejoras necesarias (ej: "Falta sección de fallback", "Script mencionado no existe").
3. Si la skill es del sistema (`~/.config/opencode/skills/`), proponer el auto-patch. Si es externa, notificar al usuario.

## 📋 Esquema Requerido para Validación
Cada skill válida DEBE tener:
1. Frontmatter con `name` y `description`.
2. Al menos un `##` heading definitorio del workflow.
3. Si usa scripts, una sección explícita de comandos o toolbox.
4. Una sección de "Reglas de Guardia" o "Políticas de Seguridad".
5. Un ciclo de "Learning Loop" o "Auto-Mejora" documentado.