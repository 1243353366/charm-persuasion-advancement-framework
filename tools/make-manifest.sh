#!/usr/bin/env bash
# Regenerate MANIFEST.sha256 over all source and documentation files.
# Excludes: .git, dist (build output), MANIFEST itself, .github (CI config).
set -euo pipefail
cd "$(dirname "$0")/.."

{
  find . \
    -path ./.git -prune -o \
    -path ./dist -prune -o \
    -path ./.github -prune -o \
    -name 'MANIFEST.sha256' -prune -o \
    -name '*.pyc' -prune -o \
    -name '__pycache__' -prune -o \
    -type f -print
} | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r f; do
  printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"
done > MANIFEST.sha256

echo "wrote MANIFEST.sha256 ($(wc -l < MANIFEST.sha256) files)"
echo "publish its own hash out of band: sha256sum MANIFEST.sha256"
sha256sum MANIFEST.sha256
