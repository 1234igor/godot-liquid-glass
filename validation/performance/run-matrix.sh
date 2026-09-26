#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
OUTPUT=${1:-$ROOT/validation/performance/results}
mkdir -p "$OUTPUT"

"$ROOT/validation/performance/run.sh" none 0 "$OUTPUT/none-0.json"
"$ROOT/validation/performance/run.sh" regular 1 "$OUTPUT/regular-1.json"
for mode in regular clear regular-tinted clear-tinted identity; do
	"$ROOT/validation/performance/run.sh" "$mode" 24 "$OUTPUT/$mode-24.json"
done

echo "Godot Liquid Glass performance matrix written to $OUTPUT"
