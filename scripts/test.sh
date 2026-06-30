#!/usr/bin/env bash
# Run the headless test suite with secrets injected from Doppler. Secrets are
# fetched once for the whole run.
#
# An editor import runs first so the class_name registry (ISaveable, GameConfig,
# ...) exists before scenes load. Pass/fail is judged by each scene's "ALL PASS"
# marker, not its raw exit code, because the EOS SDK background threads can abort
# on process teardown (a core dump after a clean quit) which would otherwise
# poison the exit code. Core dumps are suppressed. The EOS test does a live login
# only when BEDROCK_EOS_LIVE=1 (see scripts/test-eos-live.sh).
set -euo pipefail
cd "$(dirname "$0")/.."

doppler run -- bash -c '
ulimit -c 0
godot --headless --editor --quit --path . >/dev/null 2>&1 || true
status=0
for scene in tests/*_test.tscn; do
	echo "== ${scene} =="
	out=$(godot --headless --path . "res://${scene}" 2>&1 || true)
	echo "${out}" | grep -E "\[PASS\]|\[FAIL\]|\[SKIP\]|ALL PASS|FAILURES" || true
	if ! echo "${out}" | grep -q "ALL PASS"; then
		echo "  !! ${scene} did not report ALL PASS"
		status=1
	fi
done
exit ${status}
'
