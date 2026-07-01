#!/usr/bin/env bash
# Fetch GD-EOS (Epic Online Services GDExtension) into addons/gd-eos.
#
# It's a ~76MB prebuilt binary dependency, gitignored, required only for the
# online features (identity, net, lobbies, voice, achievements). Single-player
# games that disable multiplayer in GameConfig don't need it. The 4.3 build is
# forward-compatible and loads in Godot 4.7.
set -euo pipefail
cd "$(dirname "$0")/.."

VER="v0.5.1"
ASSET="GD-EOS-${VER}-min-godot-4.3.zip"
URL="https://github.com/Daylily-Zeleen/GD-EOS/releases/download/${VER}/${ASSET}"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "downloading GD-EOS ${VER} ..."
curl -fL "${URL}" -o "${TMP}/${ASSET}"
echo "extracting addons/gd-eos ..."
rm -rf addons/gd-eos
unzip -q "${TMP}/${ASSET}" "addons/gd-eos/*" -d .

# The EOS-backed internals ship .gdignore'd so the base opens clean without the
# SDK. Now that it's installed, drop those markers so the editor parses (and
# exports) that code. Re-added if you delete addons/gd-eos and re-checkout.
echo "enabling the EOS internals (removing .gdignore markers) ..."
find addons/bedrock/_internal -name .gdignore -delete

echo "done. GD-EOS installed at addons/gd-eos (gitignored)."
echo "open the project once in the editor so Godot registers the extension."
