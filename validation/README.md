# Validation

The current comparison captures `LiquidGlassPanel` itself, at the same size and position as GPUI. The README image uses this path too.

## Current component results

Captured on 2026-09-27 with Godot 4.7.1 on an Apple M4 Pro. Sixteen cases cover four materials and four backgrounds at 2400 × 1600.

The comparison converts tagged images to sRGB before measuring the **880 × 192 control bounds**, excluding the surrounding photograph. It reports RGB SSIM, mean absolute channel error, and pixels with severe channel error.

| Comparison against stored GPUI renders | RGB SSIM |
| --- | ---: |
| Mean across 16 cases | 0.922 |
| Lowest: Regular on facade | 0.854 |
| Highest: Clear on facade | 0.955 |

SSIM measures image structure on a scale whose maximum is 1. Fifteen cases exceed 0.90; Regular on dense facade lines scores 0.854.

See the [GPUI/Godot close-ups](captures/component-comparison.png) and [all measurements](captures/component-metrics.json). The report also includes comparisons with the stored native SwiftUI captures and SHA-256 hashes of every source image. GPUI and SwiftUI were not recaptured for this run.

The fixes align Clear's color transform with GPUI, include parent scaling in refraction, and use a blur kernel whose size follows the component scale. The old single mip sample changed apparent blur between 1x and 2x.

## Capture and compare

Requires Godot 4.7, Python 3, Pillow 10.1+, and NumPy. Native reference
captures also require macOS 26+, Xcode with Swift 6.2+, and Screen Recording
permission. Set `DEVELOPER_DIR` if more than one Xcode is installed.

The comparison needs three sets of raw images: this addon, GPUI, and SwiftUI.
Raw images are generated locally. To prepare the reference sets:

1. Clone [gpui-liquid-glass](https://github.com/1234igor/gpui-liquid-glass) beside
   this checkout. Follow its
   [matrix capture instructions](https://github.com/1234igor/gpui-liquid-glass/blob/main/validation/README.md#capture-the-matrix),
   using `ALLOW_FIDELITY_REGRESSION=1` to collect all cases.
2. From this repository root, run `validation/tools/capture-matrix.sh` to
   generate the local SwiftUI references. Close existing reference windows first.

Then capture the addon and compare:

```sh
python3 validation/tools/capture-components.py
python3 validation/tools/compose-showcase.py
python3 validation/tools/compare-components.py ../gpui-liquid-glass/validation/captures/raw/backgrounds
```

Set `GODOT` to a background-safe launcher when running without user interaction. The GPUI argument points to its raw matrix; local SwiftUI references are read from `validation/captures/raw/backgrounds/`.

The image composer checks dimensions, crops, resizes, and adds labels. It does not add glass effects. Raw captures are generated files and are not checked in. [Image credits](../IMAGE-LICENSES.md) cover the backgrounds and screenshots.

## Other checks

```sh
validation/tools/check.sh
validation/tools/full-visual.sh
```

The first checks scripts, shaders, assets, and capture sharing without a window. The second captures the older standalone shader scene against SwiftUI. Native captures require macOS 26 or later, matching Xcode, and Screen Recording permission; set `DEVELOPER_DIR` to choose Xcode.

`background-matrix.png` and `background-metrics.json` retain the earlier native comparison, before the current shader changes. That run failed three Regular cases. Its `similarity_percent` field is `100 × (1 − mean absolute RGB error / 255)`, not the percentage of matching pixels.
