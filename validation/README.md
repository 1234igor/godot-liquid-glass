# Validation

This directory holds the pixel reference for the addon: a small SwiftUI
application that calls Apple's public `.glassEffect`, a Godot scene that draws
the same composition through `addons/liquid_glass/`, and the tooling that
captures both and compares them.

The point is that the similarity claims in the README are measurements anyone
can repeat, not assertions.

## What is measured

Five materials × four backgrounds = 20 pairs, captured at 2400 × 1600 and
compared in sRGB. Each pair is scored three ways:

| Region | What it covers |
|--------|----------------|
| Whole window | The full 2400 × 1600 frame |
| Glass crop | The expanded glass surface and the pixels immediately around it |
| Control bounds | Just the control, where the optics are strongest |

Each score is a **gate**, not a report. The thresholds are in
`tools/compose-evidence.py`, which is what raises the failure at the end of a
full run.

## Current results

Measured on macOS 27 with Godot 4.7.1:

| Metric | Range |
|--------|-------|
| Glass crop — Regular, Clear, both tinted | 93.78 – 97.73 % |
| Glass crop — Identity | 98.81 – 99.52 % |
| Whole window | 99.42 – 99.94 % |

Checked in as [`captures/background-matrix.png`](captures/background-matrix.png)
and `captures/background-metrics.json`.

### Known failure

`tools/full-visual.sh` **reports a failure on Regular out of the box**:

```
harbour/regular     glass 94.91% < 95.00%
city-night/regular  glass 93.78% < 95.00%
prism/regular       glass 94.78% < 95.00%
```

The optics were calibrated against macOS 26. macOS 27 moved the Regular
material slightly; the other four are unaffected and still clear the gate. The
gate has deliberately **not** been lowered to make the run green — a gate that
moves whenever it fails measures nothing. Re-tuning Regular against the current
system is the open work.

## Running it

Fast — scripts, shaders, asset parity and the comparison unit tests, no GUI:

```sh
validation/tools/check.sh
```

Full — builds the SwiftUI reference, then captures and compares all 20 pairs:

```sh
validation/tools/full-visual.sh
```

That needs macOS 26 or newer and a matching Xcode, plus permission for
`screencapture` to record the screen. `tools/gd.sh` launches the dedicated
reference scene explicitly, so the root project keeps opening the media-player
example. GUI launches are serialized, framebuffer captures quit themselves, and
cleanup targets only the exact process the current run created.

The reference build uses whatever `xcode-select -p` points at; override it with
`DEVELOPER_DIR=...` if you keep several Xcodes.

## Layout

| Path | What it is |
|------|-----------|
| `reference-swiftui/` | The SwiftUI application the Godot output is compared against |
| `godot/` | The Godot scene that draws the matching composition |
| `tools/` | Capture, comparison and evidence-composition scripts |
| `performance/` | The offscreen benchmark and capture-strategy test |
| `captures/` | Checked-in evidence; `captures/raw/` is generated and ignored |
