#!/usr/bin/env bash
# Install Superpowers into the current repository for GitHub Copilot CLI.

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
Usage: install-copilot-local.sh [options]

Downloads Superpowers and installs the required skills and sessionStart hook
into the current repository for GitHub Copilot CLI.

Options:
  --repo PATH          Target repository directory (default: current directory)
  --source-dir PATH    Use an existing Superpowers checkout instead of downloading
  --github-repo ORG/REPO
                       GitHub repository to download (default: obra/superpowers)
  --ref REF            Branch, tag, or commit to download (default: main)
  --force              Overwrite existing unmanaged project skills
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

collect_source_skills() {
  local skills_root="$1"
  local skill_dir

  SOURCE_SKILL_DIRS=()
  SOURCE_SKILL_NAMES=()

  while IFS= read -r skill_dir; do
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    SOURCE_SKILL_DIRS+=("$skill_dir")
    SOURCE_SKILL_NAMES+=("$(basename "$skill_dir")")
  done < <(find "$skills_root" -mindepth 1 -maxdepth 1 -type d | sort)

  [[ ${#SOURCE_SKILL_DIRS[@]} -gt 0 ]] || die "no skills found in $skills_root"
}

skill_name_in_source() {
  local wanted="$1"
  local name

  for name in "${SOURCE_SKILL_NAMES[@]}"; do
    [[ "$name" == "$wanted" ]] && return 0
  done

  return 1
}

is_managed_skill() {
  local name="$1"
  [[ -f "$MANAGED_SKILLS" ]] || return 1
  grep -Fxq "$name" "$MANAGED_SKILLS"
}

check_skill_conflicts() {
  local skill_name
  local dest
  local conflicts=()

  for skill_name in "${SOURCE_SKILL_NAMES[@]}"; do
    dest="$DEST_SKILLS/$skill_name"
    if [[ -e "$dest" && $FORCE -ne 1 ]] && ! is_managed_skill "$skill_name"; then
      conflicts+=("$skill_name")
    fi
  done

  if [[ ${#conflicts[@]} -gt 0 ]]; then
    if [[ ${#conflicts[@]} -eq 1 ]]; then
      die "Refusing to overwrite existing project skill: ${conflicts[0]} (rerun with --force to replace it)"
    fi

    die "Refusing to overwrite existing project skills: ${conflicts[*]} (rerun with --force to replace them)"
  fi
}

remove_stale_managed_skills() {
  local old_name
  [[ -f "$MANAGED_SKILLS" ]] || return 0

  while IFS= read -r old_name; do
    [[ -n "$old_name" ]] || continue
    [[ "$old_name" == \#* ]] && continue
    if ! skill_name_in_source "$old_name" && [[ -e "$DEST_SKILLS/$old_name" ]]; then
      echo "Removing stale managed skill: $old_name"
      if [[ $DRY_RUN -ne 1 ]]; then
        rm -rf "$DEST_SKILLS/$old_name"
      fi
    fi
  done < "$MANAGED_SKILLS"
}

install_skills() {
  local index
  local skill_dir
  local skill_name
  local dest

  if [[ $DRY_RUN -ne 1 ]]; then
    mkdir -p "$DEST_SKILLS"
  fi

  for index in "${!SOURCE_SKILL_DIRS[@]}"; do
    skill_dir="${SOURCE_SKILL_DIRS[$index]}"
    skill_name="${SOURCE_SKILL_NAMES[$index]}"
    dest="$DEST_SKILLS/$skill_name"

    echo "Installing skill: $skill_name"
    if [[ $DRY_RUN -ne 1 ]]; then
      rm -rf "$dest"
      cp -R "$skill_dir" "$dest"
    fi
  done
}

install_hooks() {
  echo "Installing Copilot sessionStart hook"
  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  mkdir -p "$DEST_HOOKS"
  cp "$SOURCE_DIR/hooks/run-hook.cmd" "$DEST_HOOKS/superpowers-run-hook.cmd"
  cp "$SOURCE_DIR/hooks/session-start" "$DEST_HOOKS/superpowers-session-start"
  chmod +x "$DEST_HOOKS/superpowers-run-hook.cmd" "$DEST_HOOKS/superpowers-session-start"

  cat > "$DEST_HOOKS/superpowers.json" <<'EOF'
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "type": "command",
        "bash": "bash \".github/hooks/superpowers-run-hook.cmd\" superpowers-session-start",
        "powershell": "& \".github/hooks/superpowers-run-hook.cmd\" superpowers-session-start",
        "env": {
          "COPILOT_CLI": "1"
        },
        "timeoutSec": 30
      }
    ]
  }
}
EOF
}

write_manifest() {
  if [[ $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  mkdir -p "$META_DIR"

  {
    printf '# Managed by scripts/install-copilot-local.sh\n'
    printf '# Source: %s@%s\n' "$GITHUB_REPO" "$REF"
    printf '%s\n' "${SOURCE_SKILL_NAMES[@]}"
  } > "$MANAGED_SKILLS"

  cat > "$META_DIR/README.md" <<'EOF'
# Superpowers for GitHub Copilot CLI

This directory marks the repository-local Superpowers installation. The actual
Copilot project skills live in `.github/skills/`, and the sessionStart hook
lives in `.github/hooks/superpowers.json` with its helper scripts.

Start a new Copilot CLI session from this repository for the hook to inject the
Superpowers bootstrap. If a session is already running, restart it and run
`/skills reload` if needed.
EOF
}

TARGET_ROOT="$(absolute_target_dir "$TARGET_REPO")"

if [[ -z "$SOURCE_DIR" ]]; then
  download_source
else
  SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
fi

[[ -d "$SOURCE_DIR/skills" ]] || die "skills directory missing: $SOURCE_DIR/skills"
require_file "$SOURCE_DIR/hooks/run-hook.cmd"
require_file "$SOURCE_DIR/hooks/session-start"
require_file "$SOURCE_DIR/skills/using-superpowers/SKILL.md"

DEST_SKILLS="$TARGET_ROOT/.github/skills"
DEST_HOOKS="$TARGET_ROOT/.github/hooks"
META_DIR="$TARGET_ROOT/.github/superpowers"
MANAGED_SKILLS="$META_DIR/managed-skills.txt"

collect_source_skills "$SOURCE_DIR/skills"
check_skill_conflicts

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run: would install Superpowers for GitHub Copilot CLI into $TARGET_ROOT"
else
  echo "Installing Superpowers for GitHub Copilot CLI into $TARGET_ROOT"
fi

remove_stale_managed_skills
install_skills
install_hooks
write_manifest

echo ""
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run only. No files were changed."
else
  echo "Installed Superpowers for GitHub Copilot CLI."
fi
echo "Skills: $DEST_SKILLS"
echo "Hooks:  $DEST_HOOKS/superpowers.json"
echo ""
echo "Next: start a new Copilot CLI session from this repository."
