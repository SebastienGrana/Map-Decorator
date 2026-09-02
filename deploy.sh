#!/bin/sh
# Mirror MapDecorator into Openplanet's plugin folder.
#
# The workspace is the source and the Openplanet folder is a COPY, so this
# direction is the only one that is ever correct: never edit the deployed copy,
# it is overwritten here without warning.
#
# It MIRRORS rather than copies: a file renamed in files/ would otherwise leave
# its old name behind, and Openplanet compiles EVERY .as file in the plugin
# folder into one module - so an orphan does not sit there quietly, it gets
# compiled alongside the real thing and collides with it.
set -e

SRC="$(cd "$(dirname "$0")/files" && pwd)"

# Openplanet's folder is named after the game (Openplanet4 for ManiaPlanet).
# OPENPLANET_DIR overrides it for an install that lives somewhere else.
OPENPLANET_DIR="${OPENPLANET_DIR:-$USERPROFILE/Openplanet4}"
DST="$OPENPLANET_DIR/Plugins/MapDecorator"

[ -d "$OPENPLANET_DIR" ] || {
	echo "Openplanet folder not found: $OPENPLANET_DIR" >&2
	echo "Set OPENPLANET_DIR to your install and run again." >&2
	exit 1
}

mkdir -p "$DST"

for f in "$DST"/*.as "$DST"/info.toml; do
	[ -e "$f" ] || continue
	if [ ! -e "$SRC/$(basename "$f")" ]; then
		rm "$f"
		echo "removed orphan $(basename "$f")"
	fi
done

for f in "$SRC"/*.as "$SRC"/info.toml; do
	cp "$f" "$DST/"
	echo "deployed $(basename "$f")"
done

echo "done - reload the plugin in game with Openplanet's plugin manager (F3)"
