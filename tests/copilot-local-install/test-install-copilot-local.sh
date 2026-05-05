#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALLER="$REPO_ROOT/scripts/install-copilot-local.sh"
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

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local description="$3"

    if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
        fail "$description"
        echo "    did not expect to find: $needle"
    else
        pass "$description"
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
    local marker="${2:-Fixture bootstrap marker}"

    mkdir -p \
        "$source/hooks" \
        "$source/skills/using-superpowers" \
        "$source/skills/example"

    cp "$REPO_ROOT/hooks/run-hook.cmd" "$source/hooks/run-hook.cmd"
    cp "$REPO_ROOT/hooks/session-start" "$source/hooks/session-start"

    cat > "$source/skills/using-superpowers/SKILL.md" <<EOF
---
name: using-superpowers
description: Fixture using-superpowers skill
---

# Using Superpowers

$marker
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
    local dry_run_repo
    local update_source
    local install_output
    local install_status
    local hook_config
    local hook_output
    local conflict_output
    local conflict_status
    local dry_run_output
    local dry_run_status
    local update_output
    local update_status

    echo "=== Test: Copilot local install wrapper ==="

    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    source="$TEST_ROOT/source"
    repo="$TEST_ROOT/target-repo"
    conflict_repo="$TEST_ROOT/conflict-repo"
    dry_run_repo="$TEST_ROOT/dry-run-repo"
    update_source="$TEST_ROOT/update-source"

    mkdir -p "$repo" "$conflict_repo" "$dry_run_repo"
    write_source_fixture "$source"
    write_source_fixture "$update_source" "Updated bootstrap marker"

    set +e
    install_output="$(run_installer "$source" "$repo" 2>&1)"
    install_status=$?
    set -e

    echo ""
    echo "Install assertions..."
    assert_equals "$install_status" "0" "Installer exits successfully"
    assert_contains "$install_output" "Installed Superpowers for GitHub Copilot CLI" "Installer reports success"
    assert_contains "$install_output" ".github/skills" "Installer reports project skill path"
    assert_file_exists "$repo/.github/skills/using-superpowers/SKILL.md" "using-superpowers skill installed as project skill"
    assert_file_exists "$repo/.github/skills/example/SKILL.md" "example skill installed as project skill"
    assert_file_exists "$repo/.github/hooks/superpowers-run-hook.cmd" "prefixed hook runner installed"
    assert_file_exists "$repo/.github/hooks/superpowers-session-start" "prefixed session-start hook installed"
    assert_file_exists "$repo/.github/hooks/superpowers.json" "Copilot hook config installed"
    assert_file_exists "$repo/.github/superpowers/managed-skills.txt" "managed skill manifest installed"

    hook_config="$(cat "$repo/.github/hooks/superpowers.json")"
    assert_contains "$hook_config" '"sessionStart"' "Hook config uses Copilot camelCase sessionStart"
    assert_contains "$hook_config" '"bash"' "Hook config uses Copilot bash command field"
    assert_contains "$hook_config" '"powershell"' "Hook config uses Copilot powershell command field"
    assert_contains "$hook_config" '"COPILOT_CLI"' "Hook config forces Copilot output mode"
    assert_contains "$hook_config" 'superpowers-run-hook.cmd' "Hook config invokes installed runner"
    assert_contains "$hook_config" 'superpowers-session-start' "Hook config invokes installed session hook"

    hook_output="$(cd "$repo" && COPILOT_CLI=1 bash ".github/hooks/superpowers-run-hook.cmd" superpowers-session-start)"
    assert_contains "$hook_output" '"additionalContext"' "Session hook emits Copilot additionalContext"
    assert_contains "$hook_output" "Fixture bootstrap marker" "Session hook reads installed using-superpowers skill"
    assert_not_contains "$hook_output" "hookSpecificOutput" "Session hook avoids Claude output shape under Copilot"

    echo ""
    echo "Conflict assertions..."
    mkdir -p "$conflict_repo/.github/skills/example"
    printf 'local project skill\n' > "$conflict_repo/.github/skills/example/SKILL.md"

    set +e
    conflict_output="$(run_installer "$source" "$conflict_repo" 2>&1)"
    conflict_status=$?
    set -e

    assert_equals "$conflict_status" "1" "Installer refuses unmanaged skill overwrite"
    assert_contains "$conflict_output" "Refusing to overwrite existing project skill: example" "Conflict message names unmanaged skill"

    echo ""
    echo "Dry-run assertions..."
    set +e
    dry_run_output="$(run_installer "$source" "$dry_run_repo" --dry-run 2>&1)"
    dry_run_status=$?
    set -e

    assert_equals "$dry_run_status" "0" "Dry-run exits successfully"
    assert_contains "$dry_run_output" "Dry run only. No files were changed." "Dry-run reports no writes"
    if [[ -e "$dry_run_repo/.github" ]]; then
        fail "Dry-run leaves repository untouched"
        echo "    unexpected path: $dry_run_repo/.github"
    else
        pass "Dry-run leaves repository untouched"
    fi

    echo ""
    echo "Managed update assertions..."
    set +e
    update_output="$(run_installer "$update_source" "$repo" 2>&1)"
    update_status=$?
    set -e

    assert_equals "$update_status" "0" "Installer updates previously managed skills"
    assert_contains "$(cat "$repo/.github/skills/using-superpowers/SKILL.md")" "Updated bootstrap marker" "Managed skill updates without --force"
    assert_contains "$update_output" "Installed Superpowers for GitHub Copilot CLI" "Managed update reports success"

    if [[ $FAILURES -ne 0 ]]; then
        echo ""
        echo "FAILED: $FAILURES assertion(s) failed."
        exit 1
    fi

    echo ""
    echo "PASS"
}

main "$@"
