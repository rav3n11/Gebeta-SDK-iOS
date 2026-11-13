#!/usr/bin/env bash
# One-time setup per clone:  scripts/gebeta/install-hooks.sh you@example.com
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
[[ $# -eq 1 ]] || { echo "usage: $0 <author-email>" >&2; exit 1; }
git config gebeta.authorEmail "$1"
git config core.hooksPath scripts/gebeta/hooks
chmod +x scripts/gebeta/hooks/*
echo "Hooks installed; allowed author: $1"
