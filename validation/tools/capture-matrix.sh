#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
VALIDATION="$ROOT/validation"
RAW="$VALIDATION/captures/raw/backgrounds"
SWIFT_PROCESS=LiquidGlassReference
SWIFT_OWNER="Liquid Glass Reference"
VARIANTS=${MATRIX_VARIANTS:-"regular clear regular-tinted clear-tinted identity"}
BACKGROUNDS=${MATRIX_BACKGROUNDS:-"harbour city-night prism facade"}

stop_reference() {
	pkill -x "$SWIFT_PROCESS" >/dev/null 2>&1 || true
	for _attempt in $(seq 1 50); do
		pgrep -x "$SWIFT_PROCESS" >/dev/null 2>&1 || return 0
		sleep 0.1
	done
	echo "failed to stop $SWIFT_PROCESS" >&2
	return 1
}

cleanup() {
	set +e
	stop_reference
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

for background in harbour city-night prism facade; do
	cmp -s \
		"$ROOT/assets/backgrounds/$background.png" \
		"$VALIDATION/reference-swiftui/Sources/LiquidGlassReference/Resources/$background.png" || {
		echo "reference asset mismatch: $background.png" >&2
		exit 1
	}
done

if [ "${SKIP_NATIVE_BUILD:-0}" != "1" ]; then
	developer_dir=${DEVELOPER_DIR:-$(xcode-select -p)}
	module_cache=${TMPDIR:-/private/tmp}/godot-liquid-glass-swift-modules
	(
		cd "$VALIDATION/reference-swiftui"
		CLANG_MODULE_CACHE_PATH="$module_cache" \
		SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" \
		DEVELOPER_DIR="$developer_dir" \
		swift build -c debug
	)
fi

for background in $BACKGROUNDS; do
	for variant in $VARIANTS; do
		output="$RAW/$background/$variant"
		mkdir -p "$output"

		if [ "${REUSE_NATIVE:-0}" != "1" ] || [ ! -s "$output/swiftui.png" ]; then
			stop_reference
			"$VALIDATION/reference-swiftui/run.sh" "$variant" debug "$background"
			sleep 2
			xcrun swift "$VALIDATION/tools/move-pointer.swift"
			sleep 1
			"$VALIDATION/tools/capture-window.sh" "$SWIFT_OWNER" "$output/swiftui.png"
			stop_reference
		fi

		"$VALIDATION/tools/gd.sh" \
			"--variant=$variant" \
			"--background=$background" \
			--state=rest \
			"--shot=$output/godot.png"
		"$VALIDATION/tools/compare.py" "$output/swiftui.png" "$output/godot.png" "$output"
	done
done
