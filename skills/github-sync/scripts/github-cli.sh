#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS_SCRIPT="$SCRIPT_DIR/github-cli.ps1"

if command -v cygpath >/dev/null 2>&1; then
  PS_SCRIPT_WIN="$(cygpath -w "$PS_SCRIPT")"
else
  PS_SCRIPT_WIN="$PS_SCRIPT"
fi

if command -v powershell.exe >/dev/null 2>&1; then
  exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN" "$@"
elif command -v pwsh >/dev/null 2>&1; then
  exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT_WIN" "$@"
else
  echo "Error: powershell.exe or pwsh is required to run github-cli.ps1" >&2
  exit 1
fi
