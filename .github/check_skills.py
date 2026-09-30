"""Verify ECC ecosystem integrity."""
import json
import os
import sys

config_path = "opencode/opencode.json"
config = json.load(open(config_path))

errors = 0

# 1. Verify instructions exist
print("Checking instructions...")
for instr in config.get("instructions", []):
    path = instr
    for ph, val in [
        ("__ECC_ROOT__", "ecc"),
        ("__OPENCODE_ROOT__", "opencode"),
        ("__HOME__", "."),
    ]:
        path = path.replace(ph, val)
    if os.path.exists(path) or os.path.exists("." + path):
        print(f"  OK: {instr.split('/')[-1]}")
    else:
        print(f"  MISSING: {instr}")
        errors += 1

# 2. Verify skill directories exist
print("Checking skill directories...")
for sp in config.get("skills", {}).get("paths", []):
    path = sp.replace("__OPENCODE_ROOT__", "opencode").replace("__ECC_ROOT__", "ecc").replace("__HOME__", ".")
    if os.path.isdir(path):
        count = len([d for d in os.listdir(path) if os.path.isdir(os.path.join(path, d))])
        print(f"  OK: {sp.split('/')[-1]} ({count} skills)")
    else:
        print(f"  MISSING: {sp}")
        errors += 1

# 3. Verify commands exist (from plugin commands)
print("Checking commands...")
for plugin in config.get("plugin", []):
    path = plugin.replace("__OPENCODE_ROOT__", "opencode").replace("__ECC_ROOT__", "ecc").replace("__HOME__", ".")
    if os.path.isdir(path) or os.path.isfile(path + ".json"):
        print(f"  OK: plugin {plugin.split('/')[-1]}")
    else:
        print(f"  MISSING: {plugin}")
        errors += 1

    # 4. Verify command templates
print("Checking command templates...")
commands_section = config.get("command", {})
for cmd_name, cmd_data in commands_section.items():
    if isinstance(cmd_data, dict) and "template" in cmd_data:
        tpl = cmd_data["template"]
        path = tpl.replace("__ECC_ROOT__", "ecc").replace("__OPENCODE_ROOT__", "opencode").replace("__HOME__", ".")
        if os.path.exists(path):
            print(f"  OK: cmd {cmd_name}")
        else:
            print(f"  MISSING template: {tpl}")
            errors += 1

if errors:
    print(f"FAIL: {errors} issues found")
    sys.exit(1)

print(f"All checks passed")
