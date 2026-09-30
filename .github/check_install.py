"""Test install.sh in sandbox and verify placeholder resolution."""
import json
import os
import subprocess
import sys
import tempfile


def main():
    with tempfile.TemporaryDirectory() as tmpdir:
        test_home = os.path.join(tmpdir, "home")
        test_config = os.path.join(test_home, ".config")
        os.makedirs(test_config, exist_ok=True)

        env = os.environ.copy()
        env["HOME"] = test_home
        env["XDG_CONFIG_HOME"] = test_config

        result = subprocess.run(
            ["bash", "install.sh"],
            env=env,
            capture_output=True,
            text=True,
        )
        print(result.stdout)
        if result.returncode != 0:
            print(result.stderr)
            print("FAIL: install.sh exited", result.returncode)
            sys.exit(1)

        config_path = os.path.join(test_config, "opencode", "opencode.json")
        with open(config_path) as f:
            config = json.load(f)

        skills_paths = config.get("skills", {}).get("paths", [])
        agents = config.get("agent", [])
        print(f"OK: JSON valid, skills paths: {len(skills_paths)}, agents: {len(agents)}")

        opencode_dir = os.path.join(test_config, "opencode")
        placeholders_left = 0
        for root, dirs, files in os.walk(opencode_dir):
            for fn in files:
                fp = os.path.join(root, fn)
                for marker in ["__ECC_ROOT__", "__OPENCODE_ROOT__", "__HOME__", "__LOCAL_BIN__"]:
                    try:
                        with open(fp) as f:
                            if marker in f.read():
                                print(f"  UNRESOLVED: {marker} in {fp}")
                                placeholders_left += 1
                    except Exception:
                        pass

        if placeholders_left:
            print(f"FAIL: {placeholders_left} unresolved placeholders")
            sys.exit(1)
        print("OK: all placeholders resolved")

        home_paths = 0
        for root, dirs, files in os.walk(opencode_dir):
            for fn in files:
                fp = os.path.join(root, fn)
                try:
                    with open(fp) as f:
                        content = f.read()
                        # Only flag /home/diego (template was missed),
                        # NOT resolved placeholders like /home/runner/work/...
                        if "/home/diego" in content:
                            print(f"  HARDCODED: /home/diego in {fp}")
                            home_paths += 1
                except Exception:
                    pass

        if home_paths:
            print(f"FAIL: {home_paths} hardcoded /home/diego paths remain")
            sys.exit(1)
        print("OK: no hardcoded /home/diego paths in installed config")

        agents_md = os.path.join(test_home, "AGENTS.md")
        if os.path.exists(agents_md):
            print(f"OK: AGENTS.md installed ({sum(1 for _ in open(agents_md))} lines)")
        else:
            print("FAIL: AGENTS.md not installed")
            sys.exit(1)

    print("All install checks passed")


if __name__ == "__main__":
    main()
