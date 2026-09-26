#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
VALIDATION="$ROOT/validation"
cd "$ROOT"

python3 validation/tools/test_compare.py
bash -n \
	validation/tools/gd.sh \
	validation/tools/capture-matrix.sh \
	validation/tools/capture-interactions.sh \
	validation/tools/full-visual.sh \
	validation/performance/run.sh \
	validation/performance/run-matrix.sh
sh -n validation/tools/capture-window.sh validation/reference-swiftui/bundle.sh validation/reference-swiftui/run.sh

for background in harbour city-night prism facade; do
	cmp -s \
		"assets/backgrounds/$background.png" \
		"$VALIDATION/reference-swiftui/Sources/LiquidGlassReference/Resources/$background.png" || {
		echo "asset parity failed for $background.png" >&2
		exit 1
	}
done

CHECK_LOG=${TMPDIR:-/tmp}/godot-liquid-glass-check.log
CHECK_HOME=${TMPDIR:-/tmp}/godot-liquid-glass-home
mkdir -p "$CHECK_HOME"
set +e
HOME="$CHECK_HOME" godot --headless --path "$ROOT" --editor --quit >"$CHECK_LOG" 2>&1
godot_status=$?
set -e

if [ "$godot_status" -ne 0 ] \
		|| grep -Eq "SCRIPT ERROR|SHADER ERROR|Failed to load script|Shader compilation failed|Program crashed|handle_crash" "$CHECK_LOG"; then
	cat "$CHECK_LOG"
	echo "Godot compile/import check failed" >&2
	exit 1
fi

godot --headless \
	--log-file ${TMPDIR:-/tmp}/godot-liquid-glass-capture-strategy.log \
	--path "$ROOT" \
	--script validation/performance/test_capture_strategy.gd

# Whitespace errors, when this is a git checkout at all.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	git diff --check
fi
echo "CHECK OK - scripts, shaders, assets, and strict comparison tests"
