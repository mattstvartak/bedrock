#!/usr/bin/env bash
# Live EOS P2P between two processes on this machine. The client runs with its
# own HOME so EOS gives it a second device id. Needs GD-EOS and Doppler creds.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'kill "${host_pid:-}" 2>/dev/null || true; rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home"
BEDROCK_P2P_ROLE=host BEDROCK_P2P_OUT="$tmp/host_puid" doppler run -- godot --headless --path . res://tests/eos_p2p_live_test.tscn > "$tmp/host.log" 2>&1 &
host_pid=$!
for _ in $(seq 60); do [ -s "$tmp/host_puid" ] && break; sleep 1; done
[ -s "$tmp/host_puid" ] || { echo "host never wrote its PUID"; cat "$tmp/host.log"; exit 1; }
client=0
BEDROCK_P2P_ROLE=client BEDROCK_P2P_HOST="$(cat "$tmp/host_puid")" doppler run -- env HOME="$tmp/home" godot --headless --path . res://tests/eos_p2p_live_test.tscn > "$tmp/client.log" 2>&1 || client=$?
host=0
wait "$host_pid" || host=$?
echo "--- host"; grep -E '^\s*\[|^==|ERROR' "$tmp/host.log"
echo "--- client"; grep -E '^\s*\[|^==|ERROR' "$tmp/client.log"
[ "$client" -eq 0 ] && [ "$host" -eq 0 ]
