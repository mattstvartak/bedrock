#!/usr/bin/env bash
# Live EOS device-id login check. Hits Epic's servers, so it needs GD-EOS
# installed (scripts/fetch-eos.sh) and Doppler creds. Kept out of the default
# test suite because it's slow and the EOS SDK can stall headless exit.
set -euo pipefail
cd "$(dirname "$0")/.."
BEDROCK_EOS_LIVE=1 doppler run -- godot --headless --path . res://tests/eos_identity_test.tscn
