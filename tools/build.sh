#!/usr/bin/env bash
# Canonical build. Produces dist/ artifacts locally only; they are gitignored.
# Users are expected to build their own, and to compare hashes with any
# binary they were handed. A differing hash means the binary is not this tool.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist

CC=${CC:-cc}
if command -v "$CC" >/dev/null 2>&1; then
  "$CC" -std=c11 -Wall -Wextra -Werror -O2 -o dist/darkscan-c darkpatterns/c/darkscan.c
  echo "built dist/darkscan-c"
else
  echo "skip c: no compiler"
fi

if command -v go >/dev/null 2>&1; then
  ( cd darkpatterns/go && go build -trimpath -buildvcs=false -ldflags='-s -w' -o ../../dist/darkscan-go darkscan.go )
  echo "built dist/darkscan-go"
else
  echo "skip go: toolchain not installed"
fi

# Syntax-check Python without leaving a .pyc in the tree
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" darkpatterns/python/darkscan.py \
  && echo "python: syntax ok (runs from source, no binary)"

echo
echo "artifact hashes (compare these with any binary you were given):"
( cd dist && sha256sum * )
