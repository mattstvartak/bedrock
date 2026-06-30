#!/usr/bin/env bash
# Open the Godot editor with EOS config (and any other secrets) injected from
# Doppler, so running from the editor matches a real build.
set -euo pipefail
cd "$(dirname "$0")/.."
doppler run -- godot --path . --editor
