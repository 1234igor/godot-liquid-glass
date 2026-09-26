#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
VALIDATION="$ROOT/validation"
RAW="$VALIDATION/captures/raw/interactions"
mkdir -p "$RAW"

for state in rest hover pressed; do
	"$VALIDATION/tools/gd.sh" \
		--variant=regular \
		--background=harbour \
		"--state=$state" \
		"--shot=$RAW/$state.png"
done

"$VALIDATION/tools/compose-interactions.py"
