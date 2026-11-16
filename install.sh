#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$REPO_ROOT/skills/github-sync"

if [ ! -f "$SKILL_SOURCE/SKILL.md" ]; then
  echo "Error: skill source not found at $SKILL_SOURCE/SKILL.md" >&2
  exit 1
fi

XDG_CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

has_harness_markers() {
  local dir="$1"
  [ -d "$dir/skills" ] && return 0
  for m in mcp_config.json mcp.json AGENTS.md CLAUDE.md GEMINI.md; do
    [ -e "$dir/$m" ] && return 0
  done
  case "$(basename "$dir")" in
    .agents|.antigravity|.dsh|.codex|.claude|.cursor|.windsurf|.cline|.roo|.qoder|.qoder-cn|.zcode|.opencode|.opencode2dsh|opencode)
      return 0
      ;;
  esac
  return 1
}

install_to_harness() {
  local harness_root="$1"
  local dest=""
  local base_name
  base_name="$(basename "$harness_root")"
  if [ "$base_name" = "github-sync" ]; then
    dest="$harness_root"
  elif [ "$base_name" = "skills" ]; then
    dest="$harness_root/github-sync"
  else
    dest="$harness_root/skills/github-sync"
  fi

  local parent_dir
  parent_dir="$(dirname "$dest")"
  mkdir -p "$parent_dir"

  if [ -d "$parent_dir/github" ] && [ "$parent_dir/github" != "$SKILL_SOURCE" ]; then
    rm -rf "$parent_dir/github"
  fi

  rm -rf "$dest"
  cp -R "$SKILL_SOURCE" "$dest"
  printf 'Installed: %s\n' "$dest"
}

declare -a TARGETS=("$HOME/.agents")

if [ -d "$HOME/.gemini/config" ]; then
  TARGETS+=("$HOME/.gemini/config")
fi

for d in "$HOME"/.*; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  case "$name" in
    .|..|.gemini|.git) continue ;;
  esac
  if has_harness_markers "$d"; then
    TARGETS+=("$d")
  fi
done

if [ -d "$XDG_CFG" ]; then
  for d in "$XDG_CFG"/*; do
    [ -d "$d" ] || continue
    if has_harness_markers "$d"; then
      TARGETS+=("$d")
    fi
  done
fi

for extra in "$@"; do
  [ -n "$extra" ] && TARGETS+=("$extra")
done

# Deduplicate and install
seen="|"
for t in "${TARGETS[@]}"; do
  case "$seen" in
    *"|$t|"*) continue ;;
  esac
  seen="${seen}${t}|"
  install_to_harness "$t"
done
