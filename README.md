# Ecosistema de Ciberseguridad + OpenCode

Ecosistema completo de **67+ agentes especializados**, **285+ skills**, **119+ comandos** para desarrollo de software seguro y **pruebas ofensivas de ciberseguridad (hacking ético)** con OpenCode. Incluye stack ofensivo (recon, scan, exploit, post-explotación, DoS testing y phishing sim) controlado por un gate de autorización con registro de alcance en `scope.json` y auditoría completa.

## Estructura

```
Eco_program/
├── ecc/              # Core ECC (agentes, skills, comandos, hooks, reglas)
│   ├── agents/       # 67 agentes especializados
│   ├── skills/       # 272+ skills de dominio
│   ├── commands/     # Slash commands
│   ├── hooks/        # Automatizaciones
│   └── rules/        # Guías por lenguaje
├── opencode/         # Configuración local OpenCode
│   ├── opencode.json # Registro central de skills/agents/commands
│   ├── skills/       # Skills locales (n8n, GSAP, UI/UX, etc.)
│   ├── commands/     # Comandos slash
│   ├── plugins/      # Plugins (multi-agent)
│   └── tools/        # Scripts de herramienta
├── AGENTS.md         # Routing central de agentes
└── .github/workflows/ci.yml  # CI/CD del ecosistema
```

## Uso Local

```bash
# 1. Clonar
git clone https://github.com/galeanojuan2577/Eco_program.git ~/Eco_program

# 2. Vincular opencode config
ln -sf ~/Eco_program/opencode ~/.config/opencode

# 3. Opcional: copiar AGENTS.md al home
cp ~/Eco_program/AGENTS.md ~/
```

## CI/CD

El workflow de CI valida automáticamente:
- Estructura completa del ecosistema
- Skills registrados vs skills en disco
- Integridad de `opencode.json`
- Presencia de `AGENTS.md`
