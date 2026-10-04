# plugins/

**No hay plugins de OpenCode instalados en este ecosistema.** Este directorio se
mantiene porque `verify-ecosystem.sh` lo comprueba.

## Por qué no hay ninguno

| Intento | Motivo por el que se descartó |
|---|---|
| `multi-agent/` (Python) | Dependía de `~/Eco_program/external/sistema-multi-agente`, un proyecto externo que no existe en esta máquina, y su formato (`__init__.py`) no es el de un plugin de OpenCode. **Eliminado.** |
| `ecc/hooks/hooks.json` + `ecc/scripts/hooks/*.js` (48 hooks) | Fichero con `$schema: https://json.schemastore.org/claude-code-settings.json` y eventos `PreToolUse`/`PostToolUse`/`SessionStart`/`Stop` con `CLAUDE_PLUGIN_ROOT`: son **hooks de Claude Code**, no de OpenCode. `ecc/` es un fork de `affaan-m/ECC` y nunca corrió dentro de OpenCode. Se conservan como referencia de upstream, sin instalar. |

## Alternativa instalada

La función de seguridad que cubrían esos hooks (impedir acciones destructivas)
la cubren de forma **nativa de OpenCode V2**:

- `permissions` en `opencode.json` y por agente (`shell`/`edit`/`read` con `deny`),
- `check-scope.sh` como gate de autorización previa (exit 0/1/2),
- `audit-log.sh` para trazabilidad de cada acción.

## Cómo añadir uno

OpenCode V2 descubre `~/.config/opencode/plugins/*.ts|js` y `.opencode/plugins/`.
Ver <https://opencode.ai/v2/docs/plugins>.
