# Aislamiento por Proyecto (Project Isolation)

Regla **estructural** del Ecosistema de Ciberseguridad: cada bug bounty se valida de forma **independiente**. Un target solo se autoriza contra el scope del proyecto al que pertenece. Proyectos activos, finalizados y archivados se gestionan por separado.

## 1. Estructura de almacenamiento

```
/root/.config/opencode/cyber/
├── session.json                  ← Pin de sesión (proyecto activo de ESTA sesión)
├── projects/
│   ├── <proyecto>/scope.json     ← Scope autorizado del proyecto (única fuente de verdad)
│   ├── chime-bb/scope.json       ← ej. Chime BB
│   └── ynab-bb/scope.json        ← ej. YNAB BB
├── archived/<proyecto>-scope.json ← Proyectos FINALIZADOS (historial de aprendizaje)
├── backups/scope.legacy-*.json   ← Backups de migraciones
└── audit.log                     ← Auditoría global etiquetada [proyecto=X]
```

## 2. Reglas de oro

1. **Cada proyecto tiene su propio `scope.json`** en `cyber/projects/<proyecto>/scope.json`. Nunca mezclar targets de proyectos distintos en un mismo archivo.
2. **Al iniciar un ataque a una bug bounty NUEVA** → crear su scope:
   ```bash
   project-context.sh set <proyecto>        # fija el pin de sesión
   authorize.sh init <programa_url>         # crea scope.json vacío
   authorize.sh add <target> <tipo>         # registra targets (con consentimiento)
   ```
3. **Sesión = un solo proyecto.** `check-scope.sh` valida SOLO contra el proyecto activo.
4. **Rechazo duro cross-project:** si un target pertenece al scope de OTRO proyecto (aunque esté registrado ahí), `check-scope.sh` devuelve exit 2 y BLOQUEA la acción. No se ataca de un proyecto con el scope de otro.
5. **Proyecto finalizado** → archivar:
   ```bash
   authorize.sh archive <proyecto>
   ```
   El scope se mueve a `cyber/archived/<proyecto>-scope.json` y queda como **historial de aprendizaje** (lecciones/errores de ese engagement).

## 3. Comandos

| Comando | Descripción |
|---|---|
| `project-context.sh` | Muestra el proyecto activo + path del scope |
| `project-context.sh resolve` | Devuelve el ID del proyecto activo |
| `project-context.sh set <id>` | Fija el pin de sesión al proyecto |
| `project-context.sh unset` | Quita el pin (vuelve a detección por cwd/env) |
| `project-context.sh list` | Lista proyectos con scope registrado |
| `scope-validate.sh` | Auditoría de consistencia (activos sin scope, huérfanos, vencidos, pin) |
| `scope-validate.sh --fix` | Crea scope vacío para proyectos que no lo tienen |
| `authorize.sh init <url>` | Crea `scope.json` para el proyecto activo |
| `authorize.sh add <t> <tipo>` | Registra target en el proyecto activo |
| `authorize.sh archive <p>` | Archiva un proyecto finalizado |
| `authorize.sh list --all` | Lista scopes de todos los proyectos |

## 4. Detección del proyecto activo (prioridad)

1. `$CYBER_PROJECT` (env var)
2. `session.json` (pin fijado con `project-context.sh set`)
3. `$PWD` bajo `/root/Bugbonty/<proyecto>/`
4. Sin proyecto → error: fijar pin explícitamente

## 5. Dónde se ejecuta la validación

- **`ecc-init.sh`** (cada inicio de sesión): resuelve proyecto activo + ejecuta `scope-validate.sh`
- **`check-scope.sh`** (antes de CADA acción ofensiva): valida contra el scope del proyecto activo
- **`project-detect.sh`**: alerta si estás en un proyecto distinto al fijado
- **`config-healer.sh`**: incluye la auditoría de scope en su reporte

## 6. Buenas prácticas

- Antes de empezar: `scope-validate.sh` debe dar ✅ (ecosistema consistente).
- Al cambiar de bug bounty: `project-context.sh set <nuevo_proyecto>` SIEMPRE. No reutilizar el pin anterior.
- Aprender de los proyectos archivados: revisar `cyber/archived/<proyecto>-scope.json` y `audit.log` para evitar repetir errores (ver `rules/cyber/authorization.md`).
- Nunca borrar `archived/` — es la memoria del ecosistema.
