#!/usr/bin/env bash
# Bring in a newer MapLibre release. This repo started as a history-free
# snapshot, so instead of merging we apply the diff between the recorded base
# tag and the new tag, with 3-way fallback.
#   scripts/gebeta/sync-upstream.sh ios-v7.1.0
set -euo pipefail
new="${1:?usage: $0 <ios-vX.Y.Z tag>}"
cd "$(git rev-parse --show-toplevel)"
base="$(cat gebeta/UPSTREAM_BASE)"

git remote get-url upstream >/dev/null 2>&1 \
  || git remote add upstream https://github.com/maplibre/maplibre-native.git
# Only the two release commits are needed, not the full 6 GB history.
git fetch --depth 1 --no-tags upstream "refs/tags/$base:refs/upstream-tags/$base" "refs/tags/$new:refs/upstream-tags/$new"

# Upstream CI and bots stay out of this repo.
git diff --binary "refs/upstream-tags/$base" "refs/upstream-tags/$new" -- . \
  ':!.github/workflows' ':!.github/dependabot.yml' ':!.github/renovate.json' > /tmp/upstream.patch

if git apply --3way --index /tmp/upstream.patch; then
  echo "$new" > gebeta/UPSTREAM_BASE && git add gebeta/UPSTREAM_BASE
  echo "Upstream $base -> $new staged. Review, re-run gitleaks, then commit."
else
  echo "Conflicts to resolve:"; git diff --name-only --diff-filter=U
  echo "Our upstream patches (GEBETA: markers):"; git grep -l "GEBETA:" -- ':!gebeta' || true
  echo "After resolving: echo $new > gebeta/UPSTREAM_BASE"
  exit 1
fi
