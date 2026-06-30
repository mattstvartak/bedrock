#!/usr/bin/env bash
# Live cloud-sync check: authenticates to the deployed backend and round-trips a
# save to the cloud. Needs BEDROCK_BACKEND_URL (in Doppler) and hits the network,
# so it's kept out of the default suite.
set -euo pipefail
cd "$(dirname "$0")/.."
BEDROCK_BACKEND_LIVE=1 doppler run -- godot --headless --path . res://tests/cloud_sync_test.tscn
