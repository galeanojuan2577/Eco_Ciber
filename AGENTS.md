# Ecosistema de Ciberseguridad — Agent Instructions

**81+ agentes** · **1091+ skills** (271 ECC + 820 ACS) · **93+ comandos** · Stack ofensivo-defensivo completo para desarrollo seguro y hacking ético **siempre con autorización explícita**.

**Repo:** `/root/Escritorio/Eco_program-main/ecc/`

## Idioma
⚠️ **Siempre responder en español. Sin excepción.**

## Principios
1. **Agent-First** — Delegar a especialistas
2. **Test-Driven** — Tests antes, cobertura 80%+
3. **Security-First** — No hardcodear secrets, validar inputs
4. **Consentimiento** — Acción ofensiva requiere `scope.json` + `authorize.sh`

## Mapeo de Tareas a Agentes
| Tarea | Agente(s) | Skill(s) |
|---|---|---|
| Feature / arquitectura | `planner` + `architect` | `strategic-compact`, `api-design` |
| TDD | `tdd-guide` | `tdd-workflow`, `verification-loop` |
| Code review | `code-reviewer` | `coding-standards` |
| Seguridad | `security-reviewer` | `security-review`, `security-scan` |
| Bug / build error | `build-error-resolver` | `error-handling` |
| E2E testing | `e2e-runner` | `e2e-testing` |
| Refactor | `refactor-cleaner` | `code-tour` |
| TypeScript/JS | `typescript-reviewer` | `react-patterns`, `nestjs-patterns` |
| Python | `python-reviewer` | `python-patterns`, `fastapi-patterns` |
| Go | `go-reviewer` | `golang-patterns` |
| Rust | `rust-reviewer` | `rust-patterns` |
| Java/Spring | `java-reviewer` | `springboot-patterns` |
| Base de datos | `database-reviewer` | `postgres-patterns`, `prisma-patterns` |
| Docker/DevOps | `harness-optimizer` | `docker-patterns`, `deployment-patterns` |
| Pentest autorizado | `red-team-lead` → recon → scan → enum → exploit → post-exploit → report | `conducting-network-penetration-test` + 820 ACS skills |
| Forensics | `forensics-agent` | `performing-memory-forensics-with-volatility3`, etc. |
| Malware analysis | `malware-analyst-agent` | ACS: Ghidra, Cuckoo, YARA |
| Threat hunting | `threat-hunting-agent` | ACS: YARA, Splunk, Elastic |

## Flujos Automáticos
- **Feature**: `planner` → `tdd-guide` → `code-reviewer` → `e2e-runner`
- **Bug fix**: `tdd-guide` → `code-reviewer` → `security-reviewer`
- **Refactor**: `refactor-cleaner` → `tdd-guide` → `code-reviewer`
- **Pentest**: `authorize` → `recon-agent` → `scanner-agent` → `enumerator-agent` → `exploiter-agent` → `post-exploitation-agent` → `pentest-report-agent`
  → Flujo detallado: `/root/.config/opencode/rules/cyber/pentest-flow-detail.md`

## Reglas de Enrutamiento
- `package.json`/`tsconfig.json` → skills TypeScript
- `requirements.txt`/`pyproject.toml` → skills Python
- `go.mod` → skills Go | `Cargo.toml` → skills Rust | `pom.xml` → skills Java

## Seguridad (Antes de CADA Commit)
No hardcodear secrets · Validar inputs · SQL parametrizado · CSRF habilitado · Rate limiting · Error messages sin datos sensibles

**Si issue de seguridad**: STOP → `security-reviewer` → fix CRITICAL/HIGH → rotar secrets

## Política Ofensiva
1. **Autorización previa**: `authorize.sh` ANTES de cualquier acción → `scope.json`
2. **Gate flexible**: `check-scope.sh <target>` antes de actuación. Fuera de scope → preguntar
3. **Aislamiento por proyecto**: Cada bug bounty tiene su `scope.json`
4. **Prohibido**: Daño permanente, exfiltración real, acciones ilegales
5. **Siempre**: `audit.log`, informe final, cleanup

## Workflow
- Cada sesión → `ecc-init.sh`
- Tarea no trivial antes → leer `mistakes-log.md` y `patterns-log.md`
- Tarea no trivial después → `session-review.sh`
