#!/usr/bin/env bash
# Boundary guard: fail if consumer code reaches into the base's _internal. Games
# must use only addons/bedrock/api. `examples/` models consumer code so it IS
# checked; `tests/` is the base's own white-box tests, which legitimately reach
# into _internal, so it's excluded. A consuming game runs this same guard over
# its own source.
set -euo pipefail
cd "$(dirname "$0")/.."

hits=$(grep -rn "addons/bedrock/_internal" --include="*.gd" . 2>/dev/null | grep -vE "^\./(addons/bedrock|tests)/" || true)
if [ -n "${hits}" ]; then
	echo "boundary violation: code outside addons/bedrock references _internal:"
	echo "${hits}"
	exit 1
fi
echo "boundary clean"
