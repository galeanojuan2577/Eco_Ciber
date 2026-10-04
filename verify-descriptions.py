#!/usr/bin/env python3
"""Valida longitudes de `description` (invocado por verify-ecosystem.sh).

Uso:
  verify-descriptions.py skill <dir>...   # límite 200 car por SKILL.md
  verify-descriptions.py agent <dir>...   # límite 150 car por *.md

- Directorios inexistentes se omiten (el mismo comando sirve para modo repo
  y modo instalado).
- Exit 0 si todo OK; 1 si hay ficheros fuera de límite o sin frontmatter.
"""
import pathlib
import sys

import yaml

LIMITS = {"skill": 200, "agent": 150}


def main() -> int:
    if len(sys.argv) < 3 or sys.argv[1] not in LIMITS:
        print(__doc__, file=sys.stderr)
        return 2
    kind = sys.argv[1]
    limit = LIMITS[kind]
    bad = checked = 0

    for d in sys.argv[2:]:
        base = pathlib.Path(d)
        if not base.is_dir():
            continue
        files = base.rglob("SKILL.md") if kind == "skill" else base.glob("*.md")
        for md in sorted(files):
            checked += 1
            try:
                txt = md.read_text(encoding="utf-8")
                if not txt.startswith("---"):
                    raise ValueError("sin frontmatter")
                end = txt.find("\n---", 3)
                if end < 0:
                    raise ValueError("frontmatter sin cerrar")
                fm = yaml.safe_load(txt[4:end])
                desc = str((fm or {}).get("description", "") or "")
                if not desc:
                    raise ValueError("description vacía")
                if len(desc) > limit:
                    raise ValueError(f"description {len(desc)} car > {limit}")
            except ValueError as ex:
                bad += 1
                print(f"  [FAIL] {md}: {ex}", file=sys.stderr)
            except Exception as ex:  # YAML roto u otro error de lectura
                bad += 1
                print(f"  [FAIL] {md}: {type(ex).__name__}: {ex}", file=sys.stderr)

    if checked == 0:
        print("  [FAIL] ningún fichero comprobado (¿rutas mal?)", file=sys.stderr)
        return 1
    if bad:
        print(f"  [FAIL] {bad}/{checked} ficheros fuera de límite", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
