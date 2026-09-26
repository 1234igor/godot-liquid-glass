#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
	echo "usage: capture-window.sh <owner-or-title-fragment> <output.png>" >&2
	exit 2
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
module_cache=/private/tmp/godot-liquid-glass-capture-modules
window_id=$(
	CLANG_MODULE_CACHE_PATH="$module_cache" \
	SWIFT_MODULECACHE_PATH="$module_cache" \
	xcrun swift "$script_dir/window-id.swift" "$1"
)
screencapture -x -o -l "$window_id" "$2"
