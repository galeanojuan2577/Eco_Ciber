# Auto-Bootstrap Instructions

> **Este fichero ya no se carga.** OpenCode V2 sólo auto-carga `AGENTS.md`,
> `CLAUDE.md` y `.cursor/rules/` — `rules/` no es una ruta de descubrimiento.
>
> El contenido permanente de este archivo vive ahora en
> **`~/.config/opencode/AGENTS.md`** (instalado desde `AGENTS.md` de la raíz
> del repo). Las reglas **situacionales** pasaron a ser skills que se cargan
> bajo demanda: `dos-testing`, `phishing-sim`, `pentest-flow-detail`.
>
> Documentación detallada de cada regla permanente:
> `__OPENCODE_ROOT__/rules/cyber/{authorization,project-isolation,cleanup,reporting,session-continuity,tool-invocation,agent-write-permissions}.md`

## Referencias rápidas

| Qué | Dónde |
|---|---|
| Instrucciones permanentes | `AGENTS.md` (raíz del repo) → `~/.config/opencode/AGENTS.md` |
| Reglas permanentes (detalle) | `__OPENCODE_ROOT__/rules/cyber/*.md` |
| Reglas situacionales | skills `dos-testing`, `phishing-sim`, `pentest-flow-detail` |
| Gate de autorización | `__OPENCODE_ROOT__/tools/check-scope.sh` |
| Trazabilidad | `__OPENCODE_ROOT__/tools/audit-log.sh` |
| Enrutamiento de agentes | `AGENTS.md` §10 |
