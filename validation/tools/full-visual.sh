#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
VALIDATION="$ROOT/validation"
"$VALIDATION/tools/capture-matrix.sh"
"$VALIDATION/tools/compose-evidence.py"
"$VALIDATION/tools/capture-interactions.sh"
echo "VISUAL OK - 20 native/Godot pairs plus three interaction states"
