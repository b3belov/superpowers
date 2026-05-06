#!/usr/bin/env bash
# Install Superpowers into the current repository for Codex.

set -euo pipefail

DEFAULT_GITHUB_REPO="b3belov/superpowers"
DEFAULT_REF="main"

TARGET_REPO="."
SOURCE_DIR=""
GITHUB_REPO="${SUPERPOWERS_GITHUB_REPO:-$DEFAULT_GITHUB_REPO}"
REF="${SUPERPOWERS_REF:-$DEFAULT_REF}"
FORCE=0
DRY_RUN=0
TMP_DIR=""

usage() {
  cat <<'EOF'
Usage: install-codex-local.sh [options]

Downloads Superpowers and installs it as a repository-local Codex plugin.

Options:
  --repo PATH          Target repository directory (default: current directory)
  --source-dir PATH    Use an existing Superpowers checkout instead of downloading
  --github-repo ORG/REPO
                       GitHub repository to download (default: b3belov/superpowers)
  --ref REF            Branch, tag, or commit to download (default: main)
  --force              Overwrite an existing unmanaged local Superpowers plugin
  --dry-run            Show what would be installed without writing files
  -h, --help           Show this help

Environment:
  SUPERPOWERS_GITHUB_REPO  Default GitHub repository for downloads
  SUPERPOWERS_REF          Default branch, tag, or commit for downloads
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || die "--repo requires a path"
      TARGET_REPO="$2"
      shift 2
      ;;
    --source-dir)
      [[ $# -ge 2 ]] || die "--source-dir requires a path"
      SOURCE_DIR="$2"
      shift 2
      ;;
    --github-repo)
      [[ $# -ge 2 ]] || die "--github-repo requires ORG/REPO"
      GITHUB_REPO="$2"
      shift 2
      ;;
    --ref)
      [[ $# -ge 2 ]] || die "--ref requires a branch, tag, or commit"
      REF="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

absolute_target_dir() {
  local path="$1"
  if [[ $DRY_RUN -ne 1 ]]; then
    mkdir -p "$path"
  fi

  [[ -d "$path" ]] || die "target repository directory does not exist: $path"
  (cd "$path" && pwd)
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || die "required file missing: $path"
}

download_source() {
  command -v curl >/dev/null || die "curl not found in PATH"
  command -v tar >/dev/null || die "tar not found in PATH"

  TMP_DIR="$(mktemp -d)"
  local archive="$TMP_DIR/superpowers.tar.gz"
  local source="$TMP_DIR/source"
  local url="https://codeload.github.com/$GITHUB_REPO/tar.gz/$REF"

  echo "Downloading Superpowers from $GITHUB_REPO@$REF..."
  curl -fsSL "$url" -o "$archive" || die "failed to download $url"
  mkdir -p "$source"
  tar -xzf "$archive" -C "$source" --strip-components=1 || die "failed to extract Superpowers archive"
  SOURCE_DIR="$source"
}

is_managed_install() {
  [[ -f "$MANAGED_FILE" ]]
}

check_plugin_conflict() {
  if [[ -e "$DEST_PLUGIN" && $FORCE -ne 1 ]] && ! is_managed_install; then
    die "Refusing to overwrite existing local plugin: plugins/superpowers (rerun with --force to replace it)"
  fi
}

check_marketplace_conflict() {
  if [[ -f "$MARKETPLACE_FILE" && $FORCE -ne 1 ]] && ! is_managed_install; then
    die "Refusing to overwrite existing Codex marketplace: .agents/plugins/marketplace.json (rerun with --force to replace it)"
  fi
}

install_plugin_files() {
  echo "Installing Codex plugin: superpowers"
  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  rm -rf "$DEST_PLUGIN"
  mkdir -p "$DEST_PLUGIN"

  cp -R "$SOURCE_DIR/.codex-plugin" "$DEST_PLUGIN/.codex-plugin"
  cp -R "$SOURCE_DIR/skills" "$DEST_PLUGIN/skills"
  cp -R "$SOURCE_DIR/assets" "$DEST_PLUGIN/assets"

  if [[ -f "$SOURCE_DIR/README.md" ]]; then
    cp "$SOURCE_DIR/README.md" "$DEST_PLUGIN/README.md"
  fi

  if [[ -f "$SOURCE_DIR/LICENSE" ]]; then
    cp "$SOURCE_DIR/LICENSE" "$DEST_PLUGIN/LICENSE"
  fi

  if [[ -d "$SOURCE_DIR/agents" ]]; then
    cp -R "$SOURCE_DIR/agents" "$DEST_PLUGIN/agents"
  fi

  find "$DEST_PLUGIN" -name '.DS_Store' -type f -delete
}

write_marketplace() {
  echo "Installing Codex repo marketplace entry"
  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$MARKETPLACE_FILE")"

  if [[ -f "$MARKETPLACE_FILE" && $FORCE -eq 1 ]] && ! is_managed_install; then
    cp "$MARKETPLACE_FILE" "$MARKETPLACE_FILE.superpowers-backup"
    echo "Existing marketplace saved to $MARKETPLACE_FILE.superpowers-backup"
  fi

  cat > "$MARKETPLACE_FILE" <<'EOF'
{
  "name": "local-repo",
  "interface": {
    "displayName": "Local Repo Plugins"
  },
  "plugins": [
    {
      "name": "superpowers",
      "source": {
        "source": "local",
        "path": "./plugins/superpowers"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Coding"
    }
  ]
}
EOF
}

write_manifest() {
  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  mkdir -p "$META_DIR"

  {
    printf '# Managed by scripts/install-codex-local.sh\n'
    printf '# Source: %s@%s\n' "$GITHUB_REPO" "$REF"
    printf 'plugins/superpowers\n'
    printf '.agents/plugins/marketplace.json\n'
  } > "$MANAGED_FILE"

  cat > "$META_DIR/README.md" <<'EOF'
# Superpowers for Codex

This directory marks the repository-local Superpowers installation.

Codex discovers this installation through `.agents/plugins/marketplace.json`.
The plugin bundle lives at `plugins/superpowers/`.

Restart Codex or VS Code after installing, open Plugins, choose the local repo
marketplace, install Superpowers, and start a new Codex thread from this
repository.
EOF
}

TARGET_ROOT="$(absolute_target_dir "$TARGET_REPO")"

if [[ -z "$SOURCE_DIR" ]]; then
  download_source
else
  SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
fi

require_file "$SOURCE_DIR/.codex-plugin/plugin.json"
[[ -d "$SOURCE_DIR/skills" ]] || die "skills directory missing: $SOURCE_DIR/skills"
require_file "$SOURCE_DIR/skills/using-superpowers/SKILL.md"
[[ -d "$SOURCE_DIR/assets" ]] || die "assets directory missing: $SOURCE_DIR/assets"

DEST_PLUGIN="$TARGET_ROOT/plugins/superpowers"
MARKETPLACE_FILE="$TARGET_ROOT/.agents/plugins/marketplace.json"
META_DIR="$TARGET_ROOT/.agents/superpowers"
MANAGED_FILE="$META_DIR/codex-managed.txt"

check_plugin_conflict
check_marketplace_conflict

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run: would install Superpowers for Codex into $TARGET_ROOT"
else
  echo "Installing Superpowers for Codex into $TARGET_ROOT"
fi

install_plugin_files
write_marketplace
write_manifest

echo ""
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run only. No files were changed."
else
  echo "Installed Superpowers for Codex."
fi
echo "Plugin:      $DEST_PLUGIN"
echo "Marketplace: $MARKETPLACE_FILE"
echo ""
echo "Next: restart Codex or VS Code, open Plugins, install Superpowers from Local Repo Plugins, then start a new thread."
