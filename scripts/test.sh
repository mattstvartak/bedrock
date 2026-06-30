#!/usr/bin/env bash
# Run the headless test suite with secrets injected from Doppler. Secrets are
# fetched once for the whole run (not per test) so the suite stays fast even as
# tests grow.
#
# An editor import runs first so the class_name registry (ISaveable, GameConfig,
# ...) exists before the scenes load; without it, scripts that extend a
# class_name fail to parse. The EOS test does a live login only when
# BEDROCK_EOS_LIVE=1 (see scripts/test-eos-live.sh).
set -euo pipefail
cd "$(dirname "$0")/.."

doppler run -- bash -c '
godot --headless --editor --quit --path . >/dev/null 2>&1 || true
status=0
for scene in tests/*_test.tscn; do
	echo "== ${scene} =="
	godot --headless --path . "res://${scene}" || status=1
done
exit ${status}
'
