#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/scripts/install-codex-local.sh"
BASH_UNDER_TEST="/bin/bash"

FAILURES=0
TEST_ROOT=""

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local description="$3"

    if [[ "$actual" == "$expected" ]]; then
        pass "$description"
    else
        fail "$description"
        echo "    expected: $expected"
        echo "    actual:   $actual"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local description="$3"

    if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
        pass "$description"
    else
        fail "$description"
        echo "    expected to find: $needle"
    fi
}

assert_file_exists() {
    local path="$1"
    local description="$2"

    if [[ -f "$path" ]]; then
        pass "$description"
    else
        fail "$description"
        echo "    missing file: $path"
    fi
}

cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

write_source_fixture() {
    local source="$1"
    local version="${2:-1.0.0}"

    mkdir -p \
        "$source/.codex-plugin" \
        "$source/assets" \
        "$source/skills/using-superpowers" \
        "$source/skills/example"

    cat > "$source/.codex-plugin/plugin.json" <<EOF
{
  "name": "superpowers",
  "version": "$version",
  "description": "Fixture Superpowers plugin",
  "skills": "./skills/"
}
EOF

    printf '<svg></svg>\n' > "$source/assets/superpowers-small.svg"
    printf 'png fixture\n' > "$source/assets/app-icon.png"
    printf '# Fixture README\n' > "$source/README.md"
    printf 'Fixture license\n' > "$source/LICENSE"

    cat > "$source/skills/using-superpowers/SKILL.md" <<'EOF'
---
name: using-superpowers
description: Fixture using-superpowers skill
---

# Using Superpowers

Fixture bootstrap marker
EOF

    cat > "$source/skills/example/SKILL.md" <<'EOF'
---
name: example
description: Fixture example skill
---

# Example Skill

Example fixture content.
EOF
}

run_installer() {
    local source="$1"
    local repo="$2"
    shift 2

    "$BASH_UNDER_TEST" "$INSTALLER" --source-dir "$source" --repo "$repo" "$@"
}

main() {
    local source
    local repo
    local conflict_repo
    local marketplace_conflict_repo
    local dry_run_repo
    local update_source
    local install_output
    local install_status
    local marketplace
    local conflict_output
    local conflict_status
    local marketplace_conflict_output
    local marketplace_conflict_status
    local dry_run_output
    local dry_run_status
    local update_output
    local update_status

    echo "=== Test: Codex local install wrapper ==="

    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    source="$TEST_ROOT/source"
    repo="$TEST_ROOT/target-repo"
    conflict_repo="$TEST_ROOT/conflict-repo"
    marketplace_conflict_repo="$TEST_ROOT/marketplace-conflict-repo"
    dry_run_repo="$TEST_ROOT/dry-run-repo"
    update_source="$TEST_ROOT/update-source"

    mkdir -p "$repo" "$conflict_repo" "$marketplace_conflict_repo" "$dry_run_repo"
    write_source_fixture "$source" "1.0.0"
    write_source_fixture "$update_source" "1.1.0"

    set +e
    install_output="$(run_installer "$source" "$repo" 2>&1)"
    install_status=$?
    set -e

    echo ""
    echo "Install assertions..."
    assert_equals "$install_status" "0" "Installer exits successfully"
    assert_contains "$install_output" "Installed Superpowers for Codex" "Installer reports success"
    assert_contains "$install_output" "plugins/superpowers" "Installer reports plugin path"
    assert_file_exists "$repo/plugins/superpowers/.codex-plugin/plugin.json" "Codex manifest installed"
    assert_file_exists "$repo/plugins/superpowers/skills/using-superpowers/SKILL.md" "using-superpowers skill installed"
    assert_file_exists "$repo/plugins/superpowers/skills/example/SKILL.md" "example skill installed"
    assert_file_exists "$repo/plugins/superpowers/assets/superpowers-small.svg" "asset installed"
    assert_file_exists "$repo/.agents/plugins/marketplace.json" "repo marketplace installed"
    assert_file_exists "$repo/.agents/superpowers/codex-managed.txt" "managed manifest installed"

    marketplace="$(cat "$repo/.agents/plugins/marketplace.json")"
    assert_contains "$marketplace" '"name": "superpowers"' "Marketplace includes superpowers entry"
    assert_contains "$marketplace" '"path": "./plugins/superpowers"' "Marketplace points at plugin path"
    assert_contains "$marketplace" '"installation": "AVAILABLE"' "Marketplace marks plugin available"
    assert_contains "$marketplace" '"authentication": "ON_INSTALL"' "Marketplace includes authentication policy"

    echo ""
    echo "Conflict assertions..."
    mkdir -p "$conflict_repo/plugins/superpowers"
    printf 'local plugin\n' > "$conflict_repo/plugins/superpowers/local.txt"

    set +e
    conflict_output="$(run_installer "$source" "$conflict_repo" 2>&1)"
    conflict_status=$?
    set -e

    assert_equals "$conflict_status" "1" "Installer refuses unmanaged plugin overwrite"
    assert_contains "$conflict_output" "Refusing to overwrite existing local plugin: plugins/superpowers" "Conflict message names unmanaged plugin"

    mkdir -p "$marketplace_conflict_repo/.agents/plugins"
    printf '{"name":"existing","plugins":[]}\n' > "$marketplace_conflict_repo/.agents/plugins/marketplace.json"

    set +e
    marketplace_conflict_output="$(run_installer "$source" "$marketplace_conflict_repo" 2>&1)"
    marketplace_conflict_status=$?
    set -e

    assert_equals "$marketplace_conflict_status" "1" "Installer refuses unmanaged marketplace overwrite"
    assert_contains "$marketplace_conflict_output" "Refusing to overwrite existing Codex marketplace" "Marketplace conflict message names file"

    echo ""
    echo "Dry-run assertions..."
    set +e
    dry_run_output="$(run_installer "$source" "$dry_run_repo" --dry-run 2>&1)"
    dry_run_status=$?
    set -e

    assert_equals "$dry_run_status" "0" "Dry-run exits successfully"
    assert_contains "$dry_run_output" "Dry run only. No files were changed." "Dry-run reports no writes"
    if [[ -e "$dry_run_repo/plugins" || -e "$dry_run_repo/.agents" ]]; then
        fail "Dry-run leaves repository untouched"
    else
        pass "Dry-run leaves repository untouched"
    fi

    echo ""
    echo "Managed update assertions..."
    set +e
    update_output="$(run_installer "$update_source" "$repo" 2>&1)"
    update_status=$?
    set -e

    assert_equals "$update_status" "0" "Installer updates previously managed plugin"
    assert_contains "$(cat "$repo/plugins/superpowers/.codex-plugin/plugin.json")" '"version": "1.1.0"' "Managed plugin updates without --force"
    assert_contains "$update_output" "Installed Superpowers for Codex" "Managed update reports success"

    if [[ $FAILURES -ne 0 ]]; then
        echo ""
        echo "FAILED: $FAILURES assertion(s) failed."
        exit 1
    fi

    echo ""
    echo "PASS"
}

main "$@"
