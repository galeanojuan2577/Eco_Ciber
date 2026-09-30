# Auto-Bootstrap Instructions

## Language (Always On)
⚠️ **IDIOMA**: Siempre responder en **español**. Sin excepción.

## Pentest Workflow
Before starting any pentest engagement:
1. **Read `pentest-flow-detail.md`** — full pentest reference
2. **Authorize** — `authorize.sh` + SoW before any offensive action
3. **Scope check** — `check-scope.sh <target>` before acting
4. **Use subagents** — delegate to specialized agents (recon-agent, scanner-agent, etc.)

## Agent Routing
| Task | Agent |
|---|---|
| Recon/OSINT | `recon-agent` |
| Vulnerability scan | `scanner-agent` |
| Enum/web/API fuzz | `enumerator-agent` or `web-tester` or `api-tester` |
| Exploitation | `exploiter-agent` |
| Post-exploit | `post-exploit-agent` |
| Report | `report-agent` |
| Orchestrate full pentest | `red-team-lead` |
| OpSec/review | `opsec-agent` |
| Code review | `code-reviewer` |
| Fix verification | `pentest-verification` |

## Token Optimization
- Ultra-short responses, no preambles
- Don't repeat existing code — only show changes with `edit`
- No code comments unless necessary
- After each milestone, suggest `/compact`

## Rules (Pentest-Specific)
- `rules/cyber/authorization.md` — Authorization & Scope (MANDATORY)
- `rules/cyber/pentest-flow-detail.md` — Full pentest flow reference
- `rules/cyber/reporting.md` — Pentest reporting
- `rules/cyber/cleanup.md` — Post-engagement cleanup
- `rules/cyber/project-isolation.md` — Per-project isolation
