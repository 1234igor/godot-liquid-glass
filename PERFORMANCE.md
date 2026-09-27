# Godot Liquid Glass performance

The addon keeps one live framebuffer snapshot per 2D canvas and shares it across
all active `LiquidGlassPanel` instances. Regular now uses a 49-tap mip-filtered
Gaussian kernel whose radius follows component scale. Identity disables its
glass draw, shadow, and capture participation.

## Shader update, 2026-09-27

One background run of the existing 24-panel Regular benchmark, after the visual
fixes, measured **8.314 ms median / 8.782 ms p95**, with no frames over 12.5 ms
in 480 samples after 120 warmup frames. This used Godot 4.7.1, Apple M4 Pro,
1200 × 800, and a 120 Hz cap. It checks cadence on this machine; it is not an
uncapped GPU cost measurement.

The tables below are historical results from the earlier single-mip shader.
They have not been re-measured as a full matrix after this update.

## Test setup

- Apple M4 Pro, macOS 27.0.
- Godot 4.7.1 stable, Compatibility renderer on OpenGL 4.1 Metal.
- 1200 x 800 viewport, render thread in safe mode, paced at 120 Hz.
- 120 warmup frames followed by 480 measured frames.
- A continuously panning and warping photographic background changes every
  pixel beneath moving glass surfaces.
- Runs use `open -g` so the window stays behind the active app, and launches are
  serialized. Each runner waits for and cleans up its exact Godot process.

Run the complete matrix:

```sh
validation/performance/run-matrix.sh /tmp/godot-liquid-glass-performance
```

## Before and after

| Scene | Metric | Before | After | Change |
|---|---:|---:|---:|---:|
| 1 Regular surface | median | 8.403 ms | 8.334 ms | 0.8% lower |
| 1 Regular surface | p95 | 17.069 ms | 8.446 ms | 50.5% lower |
| 1 Regular surface | frames over 16.67 ms | 52 / 480 | 0 / 480 | 100% fewer |
| 24 Regular surfaces | median | 10.354 ms | 8.333-8.337 ms | 19.5% lower |
| 24 Regular surfaces | p95 | 16.434 ms | 8.420-9.246 ms | 43.7-48.8% lower |
| 24 Regular surfaces | frames over 16.67 ms | 15 / 480 | 0-1 / 480 | 93.3-100% fewer |
| 24 Identity surfaces | median draw calls | 25 | 1 | 96.0% fewer |
| 24 Identity surfaces | p95 | 15.572 ms | 8.421 ms | 45.9% lower |

The one-surface and no-glass runs both have a median interval of about 8.33 ms.

## Earlier material matrix

| Material | Surfaces | Median | p95 | Frames over 12.5 ms |
|---|---:|---:|---:|---:|
| No glass | 0 | 8.336 ms | 8.466 ms | 0 / 480 |
| Regular | 1 | 8.334 ms | 8.446 ms | 0 / 480 |
| Regular | 24 | 8.333 ms | 8.420 ms | 0 / 480 |
| Clear | 24 | 8.336 ms | 8.748 ms | 0 / 480 |
| Regular Tinted | 24 | 8.336 ms | 8.408 ms | 0 / 480 |
| Clear Tinted | 24 | 8.333 ms | 8.444 ms | 0 / 480 |
| Identity | 24 | 8.334 ms | 8.421 ms | 0 / 480 |

A later 24-panel Regular run, while other processes were active, measured
8.337 ms median, 9.246 ms p95, and one frame over 16.67 ms. Both runs are
included in the ranges above.

## Visual comparisons

[Validation](validation/README.md) contains the current component captures,
reference comparisons, and measurements. The tables above describe the earlier
single-mip shader; the 2026-09-27 run at the top of this page uses the updated
49-tap kernel.
