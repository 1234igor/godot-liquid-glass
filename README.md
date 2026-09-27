# Liquid Glass for Godot

An experimental Godot control that refracts and blurs the scene behind it.

![Four Godot glass materials over a harbour photo and a building facade](examples/media_player/app.png)

[Image credits and licenses](IMAGE-LICENSES.md): Bernard Spragg (CC0) and project-generated backgrounds (MIT).

The image comes from the reusable addon. Its Clear color response follows GPUI, and refraction and blur scale with the component. See the [direct GPUI comparison](validation/captures/component-comparison.png).

The current 16-case comparison averages 0.922 RGB SSIM against GPUI, ranging from 0.854 to 0.955. Regular on fine facade lines remains the weakest case. This is an approximation, not a pixel-perfect recreation of native Apple glass.

## Run

Requires Godot 4.7 with the GL Compatibility renderer. From this checkout:

```sh
godot --path .
```

Press **M** to cycle Regular, Clear, both tinted styles, and Identity. Hover or press a panel to change its illumination.

## Use the control

Copy [`addons/liquid_glass/`](addons/liquid_glass/) into your project:

```gdscript
var glass := LiquidGlassPanel.new()
glass.position = Vector2(320, 640)
glass.size = Vector2(560, 104)
glass.corner_radius = 38
glass.material_style = LiquidGlassPanel.MaterialStyle.CLEAR
add_child(glass)

var title := Label.new()
title.text = "Now Playing"
title.position = Vector2(24, 24)
glass.content_layer.add_child(title)
```

Draw the background before the panels. Put labels and controls in `content_layer` so they stay sharp. Identity disables the material and shadow while keeping that content visible.

Panels in the same canvas share a background capture. Keep them together in a stable draw order, without other drawing nodes between them. Use separate `CanvasLayer`s for independently ordered groups.

## Development

[Validation](validation/README.md) documents the remaining visual gaps, stored comparisons, and image generation. [Performance](PERFORMANCE.md) covers the dynamic-scene benchmarks.

[MIT license](LICENSE). See [third-party notices](THIRD-PARTY.md). This project is independent of Apple.
