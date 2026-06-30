#!/usr/bin/env bash
# CI entrypoint: boundary guard + import/parse check + the test suite, all with
# no secrets and no GD-EOS. The live EOS login is opt-in (BEDROCK_EOS_LIVE) and
# stays off; the EOS tests skip or take their graceful no-addon path. Pass/fail
# is judged by each scene's ALL PASS marker.
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/check-boundary.sh
bash scripts/check.sh

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
