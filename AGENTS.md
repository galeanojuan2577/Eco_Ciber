# Ecosistema de Ciberseguridad — Agent Instructions

Este es el **Ecosistema de Ciberseguridad** (antes ECC) integrado con OpenCode. Proporciona **68+ agentes especializados**, **271+ skills**, **92+ comandos**, **hooks automatizados** y un stack ofensivo-defensivo completo para desarrollo seguro y pruebas de seguridad ofensiva (recon, escaneo, explotación, post-explotación, DoS testing y simulación de phishing) **siempre con autorización y consentimiento explícito**.

**Versión:** 2.0.0 (integrado)
**Repo de referencia:** `__ECC_ROOT__/`

## Principios Centrales

1. **Agent-First** — Delegar a agentes especializados para tareas de dominio
2. **Test-Driven** — Escribir tests antes de implementar, cobertura 80%+
3. **Security-First** — Validar inputs, sanitizar outputs, no hardcodear secrets
4. **Inmutabilidad** — Crear nuevos objetos, nunca mutar existentes
5. **Plan Before Execute** — Planificar features complejas antes de escribir código
6. **Consentimiento** — Toda acción ofensiva (scan activo, explotación, DoS, phishing) requiere autorización explícita con alcance documentado en `scope.json` (`__OPENCODE_ROOT__/tools/authorize.sh`). Fuera de alcance → preguntar siempre (gate flexible).

## Herramientas de Investigación Predeterminadas

Siempre que se requiera investigar, buscar información, hacer web scraping, crawling o extraer contenido web, usar AMBAS herramientas en paralelo:

| Herramienta | Propósito | URL |
|---|---|---|
| **ScrapeGraphAI** | Scraping inteligente con IA, extracción estructurada de datos | `https://github.com/ScrapeGraphAI/Scrapegraph-ai.git` |
| **Firecrawl** | Crawling profundo, extracción de contenido completo de sitios web | `https://github.com/firecrawl/firecrawl.git` |

**Regla:** En toda investigación, usar ambas herramientas simultáneamente para maximizar cobertura y precisión. Complementar con `websearch` para búsquedas rápidas cuando sea necesario.

## Mapeo Automático de Tareas a Agentes

Usar esta tabla para seleccionar automáticamente el agente ECC óptimo:

| Tipo de Tarea | Agente ECC | Skill Asociado | Cuándo Usarlo |
|---|---|---|---|
| **Feature nueva / arquitectura** | `planner` + `architect` | `strategic-compact`, `api-design` | Sistema nuevo, feature compleja, decisión arquitectónica |
| **Desarrollo TDD** | `tdd-guide` | `tdd-workflow`, `verification-loop` | Nueva funcionalidad, bug fix con tests |
| **Code review** | `code-reviewer` | `coding-standards` | Después de escribir/modificar código |
| **Seguridad** | `security-reviewer` | `security-review`, `security-scan` | Inputs de usuario, auth, APIs, datos sensibles |
| **Bug / error de build** | `build-error-resolver` | `error-handling` | Build falla, type errors, errores de compilación |
| **Testing E2E** | `e2e-runner` | `e2e-testing` | Flujos críticos de usuario, Playwright |
| **Refactor / limpieza** | `refactor-cleaner` | `code-tour` | Dead code, duplicados, consolidación |
| **Documentación** | `doc-updater` | `article-writing`, `content-engine` | Actualizar docs, codemaps |
| **TypeScript / JS / Node** | `typescript-reviewer` | `react-patterns`, `nestjs-patterns` | Proyectos TS/JS/React/Next/Nest |
| **Python** | `python-reviewer` | `python-patterns`, `fastapi-patterns` | Proyectos Python, FastAPI, Django |
| **Go** | `go-reviewer` | `golang-patterns`, `golang-testing` | Proyectos Go |
| **Rust** | `rust-reviewer` | `rust-patterns`, `rust-testing` | Proyectos Rust |
| **Java / Spring Boot** | `java-reviewer` | `springboot-patterns`, `jpa-patterns` | Proyectos Java/Spring |
| **Kotlin / Android** | `kotlin-reviewer` | `kotlin-patterns`, `compose-multiplatform-patterns` | Kotlin, Android, KMP |
| **C / C++** | `cpp-reviewer` | `cpp-coding-standards`, `cpp-testing` | Proyectos C/C++ |
| **Base de datos** | `database-reviewer` | `postgres-patterns`, `prisma-patterns` | Schema SQL, queries, optimización |
| **Docker / DevOps** | `harness-optimizer` | `docker-patterns`, `deployment-patterns` | Infra, CI/CD, contenedores |
| **n8n / Automatización** | — | `n8n-expert` (skill local) | Workflows n8n, MCP |
| **UI/UX** | — | `ui-ux-pro-max` (skill local) | Diseño, animaciones, Framer Motion |
| **Front-end / Animaciones / Estilos únicos** | — | `web-front-animation-engine` (skill local) | Motion Primitives, DESIGN.md, Unicorn Studio, MotionSites.ai |
| **Web page / fullstack app** | `web-developer` (agente) | `web-developer-engine` (skill local) | Landing pages, dashboards, apps completas con Supabase + animaciones. Delega front-end a `web-front-animation-engine` |
| **Full-stack general** | `build` (agente default) | `fullstack-developer` (skill local) | Tareas que no encajan en lo anterior |
| **Investigación técnica** | `docs-lookup` | `search-first`, `deep-research` | APIs nuevas, documentación, investigación |
| **ML / MLOps** | `mle-reviewer` | `mle-workflow`, `benchmark` | Pipelines ML, evals, modelos |
| **Autonomous loops** | `loop-operator` | `autonomous-loops`, `continuous-agent-loop` | Tareas que requieren iteración autónoma |
| **Seguridad ofensiva** | `red-team-lead` + `recon-agent`+`scanner-agent`+`exploiter-agent` | `cyber-offensive` (skill local), `security-audit-noir` | Pentesting completo autorizado, red team, DoS test y phishing sim con SoW |
| **GSAP / Animaciones** | — | `gsap-expert` (skill local) | Animaciones web de alto impacto |
| **Memory / persistencia** | — | `memory-vault` (skill local) | Memoria entre sesiones |
| **Workflow architect** | — | `workflow-architect` (skill local) | Diseño de flujos de trabajo |

## Reglas de Enrutamiento Automático

### Detección de Lenguaje
Al detectar el lenguaje del proyecto/usuario, cargar automáticamente:
- Si hay `package.json`, `tsconfig.json` → cargar skills TypeScript
- Si hay `requirements.txt`, `pyproject.toml` → cargar skills Python
- Si hay `go.mod` → cargar skills Go
- Si hay `Cargo.toml` → cargar skills Rust
- Si hay `pom.xml`, `build.gradle` → cargar skills Java/Kotlin
- Si hay `CMakeLists.txt` → cargar skills C++
- Si hay `composer.json` → cargar skills PHP
- Si hay `Gemfile` → cargar skills Ruby
- Si hay `*.n8n.json` o `*.n8n_workflow` → cargar skill n8n-expert

### Flujo Automático por Tarea

1. **Feature request**: `planner` (plan) → `tdd-guide` (implement) → `code-reviewer` (review) → `e2e-runner` (e2e)
2. **Bug fix**: `tdd-guide` (test + fix) → `code-reviewer` (review) → `security-reviewer` (security check)
3. **Code review**: `code-reviewer` + `security-reviewer` (parallel)
4. **Refactor**: `refactor-cleaner` (clean) → `tdd-guide` (verify tests pass) → `code-reviewer` (review)
5. **Security audit**: `security-reviewer` + `security-scan` skill + `security-audit-noir` skill + HackingTool (active pentesting)
5b. **Pentest autorizado**: `authorize` (registrar SoW en scope.json) → `recon-agent` → `scanner-agent` → `enumerator-agent` → `exploiter-agent` → `post-exploitation-agent` → `pentest-report-agent` (informe + cleanup). Todos los agentes ejecutan `check-scope.sh` antes de actuación activa.
6. **Web feature**: `web-developer-engine` (build) → `web-front-animation-engine` (front/animaciones) → Chrome DevTools MCP (perf) → HackingTool (audit)
7. **New project**: `architect` (design) → `planner` (plan) → `tdd-guide` (implement)

## Guías de Seguridad

**Antes de CADA commit:**
- No hardcodear secrets (API keys, passwords, tokens)
- Validar todos los inputs de usuario
- Prevención de SQL injection (queries parametrizadas)
- Prevención de XSS (HTML sanitizado)
- CSRF protection habilitado
- Auth/authorization verificado
- Rate limiting en endpoints
- Error messages sin datos sensibles

**Si se encuentra issue de seguridad:** STOP → cargar `security-reviewer` → fix CRITICAL/HIGH → rotar secrets expuestos → review codebase por issues similares.

## Política de Pruebas Ofensivas (Hacking Ético)

El ecosistema permite ejecutar técnicas ofensivas (recon activo, escaneo, explotación, post-explotación, **DoS stress testing** y **simulación de phishing**) como parte de pruebas de hacking ético. Requisitos obligatorios en **TODO** caso:

1. **Autorización previa y explícita**: Ejecutar `__OPENCODE_ROOT__/tools/authorize.sh` ANTES de cualquier acción ofensiva para registrar el alcance (targets, fechas, tipo de test) en `scope.json`.
2. **Gate flexible**: Cada agente ofensivo ejecuta `__OPENCODE_ROOT__/tools/check-scope.sh <target> <tipo>` antes de actuación activa. Si el target NO está en el scope, **se pregunta al usuario** (gate flexible: se procede solo si el usuario confirma y se registra en audit log).
3. **Confirmación de legalidad**: Si el usuario lo solicita, todo se hace "legal y con consentimiento". Corresponde al usuario garantizar la autorización legal del target (propio, lab, o contratado). El ecosistema registra y audita cada acción (`audit.log`).
4. **Límites de DoS**: Solo infraestructura en scope (lab propio), con límites de duración/rate. NUNCA contra terceros.
5. **Límites de Phishing**: Solo servidores/infraestructura en scope, con simulaciones realistas pero no destructivas. NUNCA contra personas que no hayan consentido.
6. **Prohibido**: Daño permanente, exfiltración de datos reales fuera del lab, exfiltración de datos de terceros, acciones que violen la ley.
7. **Siempre**: Registro en `audit.log`, informe final y cleanup de artefactos al terminar.

Los agentes ofensivos por defecto piden confirmación; si el usuario declara explícitamente "autorizado / legal / con consentimiento", se procede registrándolo en el audit log.

## Skills Prioritarios

Los skills más importantes a cargar según el contexto:

### Core (siempre útiles)
- `coding-standards` — Estándares de código multi-lenguaje
- `verification-loop` — Loop de verificación y validación
- `tdd-workflow` — Flujo TDD completo
- `agentic-engineering` — Patrones de ingeniería con agentes
- `strategic-compact` — Toma de decisiones estratégicas

### Por Lenguaje

| Lenguaje | Skills |
|---|---|
| TypeScript | `typescript-patterns`, `react-patterns`, `nestjs-patterns`, `react-testing` |
| Python | `python-patterns`, `fastapi-patterns`, `django-patterns`, `python-testing` |
| Go | `golang-patterns`, `golang-testing` |
| Rust | `rust-patterns`, `rust-testing` |
| Java | `springboot-patterns`, `jpa-patterns`, `springboot-tdd` |
| Kotlin | `kotlin-patterns`, `kotlin-coroutines-flows`, `kotlin-testing` |
| C++ | `cpp-coding-standards`, `cpp-testing` |
| PHP | `laravel-patterns`, `laravel-tdd`, `php-testing` |

### Por Dominio
- **Testing**: `e2e-testing`, `browser-qa`, `ai-regression-testing`
- **Base de datos**: `postgres-patterns`, `prisma-patterns`, `mysql-patterns`, `database-migrations`
- **DevOps**: `docker-patterns`, `deployment-patterns`, `github-ops`
- **API**: `api-design`, `mcp-server-patterns`
- **Frontend**: `frontend-patterns`, `frontend-slides`, `motion-ui`, `liquid-glass-design`
- **Research**: `search-first`, `deep-research`, `scientific-thinking-literature-review`

## Workflow Surface Policy

- `skills/` es la superficie de workflow canónica (en `__ECC_ROOT__/skills/` y `__OPENCODE_ROOT__/skills/`)
- Los skills locales tienen prioridad sobre los de ECC para el mismo dominio
- `commands/` es superficie legacy de compatibilidad

## Project Structure (ECC + Local)

```
__ECC_ROOT__/                          — Repo ECC clonado (referencia)
  ├── agents/                             — 68 agentes especializados
  ├── skills/                             — 271+ skills de dominio
  ├── commands/                           — 92+ comandos slash
  ├── hooks/                              — Automatizaciones por triggers
  ├── rules/                              — Guías por lenguaje
  ├── mcp-configs/                        — 14 configuraciones MCP
  └── scripts/                            — Utilidades Node.js

__OPENCODE_ROOT__/             — Configuración local OpenCode
  ├── opencode.json                       — Config principal
  ├── skills/                             — 12 skills locales
  ├── plugins/multi-agent/                — Plugin multi-agente local
  │
__HOME__/AGENTS.md                     — Este archivo (routing central)
```

## ⚡ Auto-Ejecución en Cada Sesión

El ecosistema ECC ahora tiene un sistema de **auto-bootstrap** que se ejecuta automáticamente al inicio de cada sesión:

1. **🔍 Security Scan** → Escanea secrets hardcodeados (`security-scanner.sh`)
2. **📋 Project Detect** → Detecta tech stack y carga skills relevantes (`project-detect.sh`)
3. **🩺 Config Health** → Verifica que agentes/skills/commands estén registrados (`config-healer.sh`)
4. **🧬 Ecosystem Evolution** → Genera reporte de salud y detecta drift (`ecosystem-evolve.sh`)

### Custom Tools Disponibles

| Tool | Descripción | Uso |
|------|-------------|-----|
| `security-scan` | Escanea secrets hardcodeados | Auto-run al inicio |
| `project-detect` | Detecta tech stack, carga skills | Auto-run al inicio |
| `config-heal` | Audita y repara registro de agentes | Periódico |
| `ecosystem-health` | Reporte completo de salud | Bajo demanda |

### Flujo de Mejora Continua
- **Cada sesión**: El sistema se auto-audita y sugiere mejoras
- **Skills se cargan on-demand**: Ya no se cargan 62KB de instrucciones al inicio
- **Detección de drift**: Si hay agentes sin registrar, se detectan automáticamente
- **Auto-evolución**: El ecosistema se actualiza solo con cada uso
```
