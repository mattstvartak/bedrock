#!/usr/bin/env bash
# Run the headless test suite with secrets injected from Doppler.
# Secrets aren't needed by the current tests, but routing through `doppler run`
# keeps one path for everything so EOS-dependent tests just work later.
set -euo pipefail
cd "$(dirname "$0")/.."

status=0
for scene in tests/*_test.tscn; do
	echo "== ${scene} =="
	doppler run -- godot --headless --path . "res://${scene}" || status=1
done
exit "${status}"
