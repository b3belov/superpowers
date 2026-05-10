#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MARKETPLACE="$REPO_ROOT/.agents/plugins/marketplace.json"
PLUGIN_ROOT="$REPO_ROOT/plugins/superpowers"

echo "=== Test: Codex marketplace metadata ==="

python3 - "$MARKETPLACE" "$PLUGIN_ROOT" <<'PY'
import json
import pathlib
import sys

marketplace_path = pathlib.Path(sys.argv[1])
plugin_root = pathlib.Path(sys.argv[2])

with marketplace_path.open() as f:
    marketplace = json.load(f)

plugins = marketplace.get("plugins", [])
assert len(plugins) == 1, "expected exactly one marketplace plugin"
plugin = plugins[0]

assert marketplace["name"] == "superpowers-dev"
assert marketplace["interface"]["displayName"] == "Superpowers Dev"
assert plugin["name"] == "superpowers"
assert plugin["source"] == {
    "source": "local",
    "path": "./plugins/superpowers",
}
assert plugin["policy"] == {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL",
}
assert plugin["category"] == "Coding"

manifest_path = plugin_root / ".codex-plugin" / "plugin.json"
with manifest_path.open() as f:
    manifest = json.load(f)

for relative_path in [
    ".codex-plugin",
    "skills",
    "assets",
    "README.md",
    "LICENSE",
]:
    bundled_path = plugin_root / relative_path
    assert bundled_path.exists(), f"missing bundled path: {relative_path}"
    assert not bundled_path.is_symlink(), f"bundled path must be a real copy: {relative_path}"

skill_files = sorted((plugin_root / "skills").glob("*/SKILL.md"))
assert len(skill_files) >= 10, "expected bundled Superpowers skills"

assert manifest["name"] == plugin["name"]
assert (plugin_root / "skills" / "using-superpowers" / "SKILL.md").is_file()
assert (plugin_root / "assets" / "superpowers-small.svg").is_file()
assert (plugin_root / "assets" / "app-icon.png").is_file()
PY

echo "PASS"
