#!/usr/bin/env bash
# Boundary guard: fail if any game code (outside addons/bedrock) reaches into the
# base's _internal. Games must use only addons/bedrock/api. In this repo there's
# no game code, so it passes trivially, but it's the same guard a consuming game
# runs in its own CI.
set -euo pipefail
cd "$(dirname "$0")/.."

hits=$(grep -rn "addons/bedrock/_internal" --include="*.gd" . 2>/dev/null | grep -v "^\./addons/bedrock/" || true)
if [ -n "${hits}" ]; then
	echo "boundary violation: code outside addons/bedrock references _internal:"
	echo "${hits}"
	exit 1
fi
echo "boundary clean"
