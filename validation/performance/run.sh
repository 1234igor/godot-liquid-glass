#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
MODE=${1:-regular}
COUNT=${2:-24}
RESULT=${3:-/tmp/godot-liquid-glass-performance.json}
SHOT=${4:-}
WARMUP=${PERF_WARMUP:-120}
FRAMES=${PERF_FRAMES:-480}
TIMEOUT=${PERF_TIMEOUT:-90}
APP=${GODOT_APP:-/Applications/Godot.app}
LOG=$(mktemp -t godot-liquid-glass-performance-log)
LAUNCH_LOG=$(mktemp -t godot-liquid-glass-performance-launch)
launcher=
user_args=(
	"--mode=$MODE"
	"--count=$COUNT"
	"--warmup=$WARMUP"
	"--frames=$FRAMES"
	"--result=$RESULT"
)
if [ -n "$SHOT" ]; then
	user_args+=("--shot=$SHOT")
fi

stop_render_process() {
	for pid in $(pgrep -f -- "--log-file $LOG" 2>/dev/null || true); do
		kill -TERM "$pid" 2>/dev/null || true
	done
}

cleanup() {
	stop_render_process
	if [ -n "$launcher" ] && kill -0 "$launcher" 2>/dev/null; then
		kill -TERM "$launcher" 2>/dev/null || true
		wait "$launcher" 2>/dev/null || true
	fi
	rm -f "$LOG" "$LAUNCH_LOG"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

rm -f "$RESULT"

open -g -W -n -a "$APP" --args \
	--position 80,80 \
	--path "$ROOT" \
	--scene res://validation/performance/benchmark.tscn \
	--audio-driver Dummy \
	--disable-vsync \
	--max-fps 120 \
	--render-thread safe \
	--log-file "$LOG" \
	-- \
	"${user_args[@]}" > /dev/null 2>"$LAUNCH_LOG" &
launcher=$!

elapsed=0
status=0
while kill -0 "$launcher" 2>/dev/null; do
	sleep 1
	elapsed=$((elapsed + 1))
	if [ "$elapsed" -ge "$TIMEOUT" ]; then
		stop_render_process
		kill -TERM "$launcher" 2>/dev/null || true
		wait "$launcher" 2>/dev/null || true
		status=124
		break
	fi
done
if [ "$status" -eq 0 ]; then
	wait "$launcher" || status=$?
fi
launcher=
cat "$LOG" 2>/dev/null || true
cat "$LAUNCH_LOG" >&2 2>/dev/null || true

if [ "$status" -ne 0 ] || [ ! -s "$RESULT" ] || ! grep -q '^LIQUID GLASS BENCH OK ' "$LOG"; then
	echo "Godot performance run failed for $MODE/$COUNT" >&2
	exit 1
fi

python3 - "$RESULT" "$MODE" "$COUNT" <<'PY'
import json
import sys
from pathlib import Path

result_path, expected_mode, raw_count = sys.argv[1:]
try:
    expected_count = int(raw_count)
    result = json.loads(Path(result_path).read_text())
except (OSError, ValueError, json.JSONDecodeError) as error:
    raise SystemExit(f"invalid Godot performance result: {error}") from error

if not isinstance(result, dict):
    raise SystemExit("invalid Godot performance result: root must be an object")
if result.get("mode") != expected_mode or result.get("glass_count") != expected_count:
    raise SystemExit(
        "stale or mismatched Godot performance result: "
        f"expected {expected_mode}/{expected_count}, "
        f"got {result.get('mode')}/{result.get('glass_count')}"
    )
PY
