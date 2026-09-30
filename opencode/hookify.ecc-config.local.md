---
name: ecc-config-guard
enabled: true
event: file
conditions:
  - field: file_path
    operator: regex_match
    pattern: opencode\.json$
  - field: new_text
    operator: not_contains
    pattern: "\"agent\""
---

⚠️ **CUIDADO:** Estás modificando opencode.json directamente.
- Si agregas/quitas agents, skills o commands, asegúrate que los archivos correspondientes existan en `__ECC_ROOT__/`
- Ejecuta `bash __OPENCODE_ROOT__/tools/backup-config.sh` antes de cambios destructivos
- Valida con: `python3 -c "import json; json.load(open('...'))"`
