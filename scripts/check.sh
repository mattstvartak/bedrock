#!/usr/bin/env bash
# Headless import to catch GDScript parse errors. No secrets needed, so this one
# doesn't go through Doppler. Good as a fast CI gate.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf .godot
out=$(godot --headless --editor --quit --path . 2>&1 || true)
if echo "${out}" | grep -iqE "SCRIPT ERROR|Parse Error|Failed to load|not compiling"; then
	echo "${out}" | grep -iE "SCRIPT ERROR|Parse Error|Failed to load|not compiling"
	echo "import FAILED"
	exit 1
fi
echo "import clean"
