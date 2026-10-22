#!/usr/bin/env bash
# Downloads Godot 4.5 (standard, Linux x86_64) so headless tests can run in a fresh
# cloud session, where Godot isn't installed. Installs to ~/.local/bin/godot by default,
# which is on PATH, so the commands in each project's CLAUDE.md work as written.
#
#   tools/get_godot.sh            # install to ~/.local/bin
#   tools/get_godot.sh <dir>      # install somewhere else
set -euo pipefail

VERSION="4.5-stable"
dest="${1:-$HOME/.local/bin}"

if [ -x "$dest/godot" ] && "$dest/godot" --version 2>/dev/null | grep -q "^4.5"; then
	echo "Godot already at $dest/godot ($("$dest/godot" --version))"
	exit 0
fi

mkdir -p "$dest"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -sSL -o "$tmp/godot.zip" \
	"https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
unzip -q "$tmp/godot.zip" -d "$tmp"
mv "$tmp/Godot_v${VERSION}_linux.x86_64" "$dest/godot"
chmod +x "$dest/godot"
echo "Installed $("$dest/godot" --version) at $dest/godot"
