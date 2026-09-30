---
name: actualizate
description: Force ECC auto-update or check if update is due. Complements the 3-day automatic cycle.
command: true
---

# Actualizar ECC

Forzar una actualización inmediata del ecosistema o verificar si la actualización automática cada 3 días está lista.

## Uso

```bash
/actualizate                    # Forzar actualización inmediata
/actualizate --check           # Solo verificar estado (sin actualizar)
/actualizate --quick           # Actualización rápida (solo health check)
```

## Descripción

Ejecuta el ciclo de actualización automática del ecosistema ECC.
- Si hace menos de 3 días de la última actualización, solo informa el estado
- Si hace más de 3 días o se usa `--force`, ejecuta investigación profunda y actualiza instincts/skills
- Registra el evento en `audit.log`

## Opciones

| Opción | Descripción |
|--------|-------------|
| `none` | Forzar actualización completa (ignora el límite de 3 días) |
| `--check` | Solo mostrar estado actual sin ejecutar update |
| `--quick` | Health check rápido (sin investigación profunda) |

## What Happens During Update

1. **Security scan** — Escanea secrets hardcodeados en el codebase
2. **Project detection** — Detecta tech stack y recomienda skills
3. **Deep research** — Ejecuta websearch en 8 queries clave de bug bounty 2026
4. **Ecosystem health** — Verifica drift y salud del ecosistema
5. **Instincts update** — Clusterea nuevos patterns, sugiere promotions a skills
6. **Timestamp reset** — Reinicia el contador de 3 días

## Examples

```bash
/actualizate                    # Actualización completa (si hace 3+ días o fuerza)
/actualizate --check           # Solo estado actual
/actualizate --quick           # Health check rápido
```

## Side Effects

- Actualiza `last-update.timestamp` en `$CONFIG_DIR/.auto-update/`
- Añade entradas a `$LEARNINGS_DIR/observations.jsonl`
- Sugiere nuevas skills via `/evolve`
- Registra en `audit.log` con tag `[auto-update]`