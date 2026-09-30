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
- Si agregas/quitas agents, skills o commands, asegúrate que los archivos correspondientes existan en `/root/Escritorio/Eco_program-main/ecc/`
- Ejecuta `bash /root/.config/opencode/tools/backup-config.sh` antes de cambios destructivos
- Valida con: `python3 -c "import json; json.load(open('...'))"`
