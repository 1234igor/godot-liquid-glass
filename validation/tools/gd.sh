#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
TIMEOUT=${GD_TIMEOUT:-90}
APP=${GODOT_APP:-/Applications/Godot.app}
BINARY="$APP/Contents/MacOS/Godot"

if [ ! -x "$BINARY" ]; then
	echo "gd.sh: Godot.app not found at $APP" >&2
	exit 1
fi

LOG=$(mktemp -t liquid-glass-godot-log)
LAUNCH_LOG=$(mktemp -t liquid-glass-godot-launch)

stop_render_process() {
	for pid in $(pgrep -f -- "--log-file $LOG" 2>/dev/null || true); do
		kill -TERM "$pid" 2>/dev/null || true
	done
}

cleanup() {
	stop_render_process
	rm -f "$LOG" "$LAUNCH_LOG"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Launch the exact binary so the PID we wait on is the PID we can terminate.
# The project captures its own framebuffer and quits without opening Terminal.
"$BINARY" \
	--position 6000,6000 \
	--path "$ROOT" \
	--log-file "$LOG" \
	res://validation/godot/scenes/main.tscn \
	-- "$@" >/dev/null 2>"$LAUNCH_LOG" &
launcher=$!

elapsed=0
while kill -0 "$launcher" 2>/dev/null; do
	sleep 1
	elapsed=$((elapsed + 1))
	if [ "$elapsed" -ge "$TIMEOUT" ]; then
		stop_render_process
		kill -TERM "$launcher" 2>/dev/null || true
		wait "$launcher" 2>/dev/null || true
		cat "$LOG" 2>/dev/null || true
		echo "gd.sh: capture timed out after ${TIMEOUT}s" >&2
		exit 124
	fi
done
wait "$launcher" || launch_status=$?
launch_status=${launch_status:-0}
cat "$LOG" 2>/dev/null || true
cat "$LAUNCH_LOG" >&2 2>/dev/null || true

if ! grep -q '^LIQUID GLASS OK ' "$LOG"; then
	echo "gd.sh: project did not report a successful capture" >&2
	exit 1
fi
