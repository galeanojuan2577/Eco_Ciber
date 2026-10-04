# Eco_Ciber — ecosistema de ciberseguridad para OpenCode **V2**

**81 agentes** · **437 skills** (166 ciber + 271 ingeniería) · **11 comandos `/pentest/*`** · **7 MCPs** · **26 tools** · **7 reglas** · **6 plantillas**

Stack ofensivo-defensivo para hacking ético y desarrollo de software seguro, **nativo de OpenCode V2** (probado con `opencode` v2.0.22). Todo lo ofensivo pasa por un **gate de autorización** con registro de alcance (`scope.json`) y auditoría (`audit.log`).

> ⚠️ **No ejecutes `Eco_Ciber/install.sh`** (el heredado de upstream): hace `rm -rf` sobre `~/.config/opencode`. El instalador correcto es `eco-install.sh`.

---

## Instalación

```bash
git clone https://github.com/galeanojuan2577/Eco_Ciber.git ~/Eco_Ciber
cd ~/Eco_Ciber
bash eco-install.sh              # agrega --dry-run para ver el plan sin escribir
```

`eco-install.sh` copia el árbol, **resuelve los placeholders** (`__OPENCODE_ROOT__`, `__ECC_ROOT__`, `__HOME__`, `__LOCAL_BIN__`) sólo en destino, preserva `service.json` byte a byte, instala `recon`/`bbrecon` en `~/.local/bin`, crea el espacio `~/BugBounty` con sus plantillas y **valida que los 81 agentes se descubran**.

Validación completa (69 comprobaciones):

```bash
bash verify-ecosystem.sh --instalado
```

---

## Qué cambió al portar de V1 a V2

OpenCode V2 valida la configuración contra un esquema con `additionalProperties: false`. Varios usos heredados de V1 **se ignoraban en silencio**: el ecosistema "parecía" funcionar, pero no estaba aplicando nada.

| Apartado | Forma V1 (heredada) | Forma V2 (esta portada) | Evidencia |
|---|---|---|---|
| Permisos | `permissions` (plural) | `permission` (singular) | La clave V1 no aparece en el esquema ⇒ el runtime la descartaba. Hoy `security-scanner.sh` la marca como `❌` |
| Proveedores | `providers` (plural) | `provider` (singular) | Ídem: `options`/`models` no llegaban a aplicarse |
| Skills | `"skills": ["ruta", …]` | `"skills": {"paths": [...]}` | `opencode run` confirma los 437 skills cargados desde ambas rutas |
| MCP | `"mcp": {"servers": {…}}` | `"mcp": {"<nombre>": {…}}` plano | `opencode mcp list` → 7/7 `connected` |
| Restricción MCP | `"mcp_*": "ask"` | `"*": "ask"` + nativas en `allow` | El catch-all cubre las herramientas MCP, cuyos nombres varían por servidor |
| Skill descubrible | cualquier `SKILL.md` | frontmatter `name` + `description` | 3 skills sin frontmatter eran invisibles: 434/437 → **437/437** |
| `tools/` | script no incluido | `cyber-tools-installed.sh` instalado | `pentest-flow-detail` lo citaba y no existía |

Claves de la configuración actual: `$schema`, `provider`, `model`, `default_agent`, `skills`, `mcp`, `permission` — **todas válidas contra <https://opencode.ai/config.json> (0 errores)**.

---

## Estructura

```
Eco_Ciber/
├── eco-install.sh          # instalador (placeholders, service.json, validación de agentes)
├── verify-ecosystem.sh      # 69 comprobaciones; --instalado también revisa la instalación viva
├── AGENTS.md                # instrucciones globales (se instala con placeholders resueltos)
├── opencode/
│   ├── opencode.json        # config V2 (provider · skills.paths · mcp · permission)
│   ├── agents/              # 81 agentes con frontmatter (mode: subagent / primary)
│   ├── skills/              # 166 skills de ciberseguridad
│   ├── commands/            # 11 comandos /pentest/* + /agent
│   ├── rules/               # 7 reglas cyber (permanentes) + reglas por lenguaje
│   ├── templates/           # 6 plantillas de informe/scope/sesión
│   ├── tools/               # 26 scripts (gate, auditoría, recon, inventario…)
│   └── plugins/README.md    # por qué se retiró el plugin multi-agent
├── ecc/skills/              # 271 skills de ingeniería de software
├── recon/                   # recon_pro.sh (nivel 1–3, informes MD/JSON/HTML)
└── Hyprdots/scripts/        # copias de los instaladores del sistema
```

En destino todo vive en `~/.config/opencode/` (los skills de ingeniería en `skills-ecc/`).

---

## Seguridad y authorization

```bash
bash ~/.config/opencode/tools/check-scope.sh <target> <tipo>   # 0 · 1 · 2 · 3
bash ~/.config/opencode/tools/audit-log.sh "<tool> <target> <tipo>"
```

| Exit | Significado |
|---|---|
| `0` | **IN SCOPE** — procede y registra |
| `1` | **NEEDS CONFIRM** — STOP: pregunta al usuario; si confirma, repite con `--force` |
| `2` | **HARD DENY** — pertenece a **otro** proyecto; no se fuerza |
| `3` | **USAGE ERROR** — faltan argumentos o scope |

Cada proyecto es un mundo: `cyber/projects/<proyecto>/scope.json` es la única fuente de verdad, `cyber/session.json` fija el proyecto activo y `cyber/archived/` conserva el histórico.

Auditoría de seguridad de la configuración:

```bash
bash ~/.config/opencode/tools/security-scanner.sh            # 0 issues = PASS
```

**Nunca** se versionan `service.json`, `rclone.conf`, la contraseña de restic ni `Backups/`.

---

## Inventario del toolchain

```bash
bash ~/.config/opencode/tools/cyber-tools-installed.sh        # tabla completa (invoca cada binario)
bash ~/.config/opencode/tools/cyber-tools-installed.sh --missing
bash ~/.config/opencode/tools/cyber-tools-installed.sh --json
```

Estado actual: **105/106** — la única ausente es `wapiti`, descartada a propósito (exige Python <3.14 y el sistema trae 3.14.7; la cubren nuclei, sqlmap, dalfox y nikto).

---

## Verificación y estado

| Qué | Resultado |
|---|---|
| `verify-ecosystem.sh --instalado` | **69/69 PASS** |
| Config contra el esquema V2 | **0 errores** |
| `opencode mcp list` | **7/7 connected** |
| `opencode debug agents` | **88** (81 propios + 7 de fábrica), todos con system prompt |
| Skills descubribles | **437/437** con `name` + `description` |
| `bash -n` sobre todos los `.sh` | OK |
| Gate de autorización | exit 0 en scope · 1 fuera de scope · 2 proyecto ajeno · 3 sin args |
| Subagente cyber real (`recon-agent`) | ejecutado: gate exit 0 desde subagente, toolchain 8/8 |
| `recon 127.0.0.1 -l 1 --ecc` | exit 0 · informes MD + JSON + HTML |

**Sin probar de forma headless:** la invocación en TUI de los 11 comandos `/pentest/*` (sólo se valida su existencia y frontmatter).

### Coste de contexto (medido, no estimado)

Suelo de tokens por turno (`tokens_input + tokens_cache_read` de `session_v2` en `opencode.db`, mediana de 3 sesiones headless `opencode run "ok"`):

| Escenario | Suelo/turno | Δ |
|---|---|---|
| Baseline (antes de compactar) | **44.736 tok** | — |
| Tras compactar (Fases 1-5) | **39.412 tok** | **−5.324 (−11,9 %)** |

Desglose del suelo compactado (aislado midiendo con `skills` y `AGENTS.md` fuera):

- Base irrenunciable (system prompt + tools nativas + comandos + proveedor): **≈ 22.498 tok**
- Índice de skills (437 `name`+`description`): **≈ 14.192 tok**
- `AGENTS.md`: **≈ 2.722 tok**
- Catálogo MCP: **0 tok en headless** — sólo cuesta en sesiones interactivas; por eso los 3 MCP de contexto (`agent-browser`, `chrome-devtools`, `filesystem`) están con `enabled: false` (ahorro ≈ 27.000 caracteres de esquemas ≈ 7.000 tok en TUI), conservando `playwright`, `memory`, `sequential-thinking` y `context7`.

Qué se hizo (reversible, nada borrado):

1. `enabled: false` en 3 MCPs de contexto (los 7 siguen declarados; CLI vía shell disponible).
2. `description` de skills a ≤200 car (166 reescritas, detalle migrado al cuerpo bajo `## Detalle de la descripción` — sólo carga al invocar el skill). Índice: 92.411 → 53.185 car.
3. `AGENTS.md` §10 (tabla de enrutamiento redundante con las descripciones que inyecta el harness) y §2 comprimidos; §3 (gate de autorización) intacto.
4. `description` de agentes a ≤150 car (64 reescritas).
5. `compaction: {auto, prune, tail_turns: 4}` + `tool_output: {max_lines: 800, max_bytes: 20000}`.

El objetivo de 20.000 tok/turno era inalcanzable sin perder cobertura: la base del propio OpenCode ya son ≈22.500 tok. Anclajes de regresión: `verify-ecosystem.sh` valida ≤200/≤150, los 3 MCP desactivados y la config de compaction (74/74 en modo instalado).

---

## Licencia

Apache-2.0 (salvo indicación en cada skill).
