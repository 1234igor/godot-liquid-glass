#!/usr/bin/env python3
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "captures" / "raw" / "backgrounds"
OUT = ROOT / "captures"
BACKGROUNDS = ["harbour", "city-night", "prism", "facade"]
VARIANTS = ["regular", "clear", "regular-tinted", "clear-tinted", "identity"]
BACKGROUND_LABELS = {
    "harbour": "Bright harbour",
    "city-night": "Dark city",
    "prism": "Saturated prism",
    "facade": "Fine facade",
}
VARIANT_LABELS = {
    "regular": "Regular",
    "clear": "Clear",
    "regular-tinted": "Regular + tint",
    "clear-tinted": "Clear + tint",
    "identity": "Identity",
}
MIN_MATERIAL_GLASS_SIMILARITY = 95.0
MIN_IDENTITY_GLASS_SIMILARITY = 98.5
MIN_WHOLE_WINDOW_SIMILARITY = 99.4


def text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, fill: str, size: int) -> None:
    draw.text(xy, value, fill=fill, font=ImageFont.load_default(size=size))


def main() -> None:
    cell_width = 390
    image_height = 128
    label_height = 54
    gutter = 10
    row_label_width = 145
    header_height = 50
    width = row_label_width + len(VARIANTS) * (cell_width + gutter) - gutter
    height = header_height + len(BACKGROUNDS) * (label_height + image_height + gutter) - gutter
    sheet = Image.new("RGB", (width, height), "#111114")
    draw = ImageDraw.Draw(sheet)

    for column, variant in enumerate(VARIANTS):
        x = row_label_width + column * (cell_width + gutter)
        text(draw, (x + 10, 16), VARIANT_LABELS[variant], "#ffffff", 17)

    report = {
        "reference": "SwiftUI Glass built with Xcode beta",
        "godot": "4.7.1 stable, live canvas_item screen shader",
        "capture_size_pixels": [2400, 1600],
        "acceptance": {
            "material_glass_similarity_percent_min": MIN_MATERIAL_GLASS_SIMILARITY,
            "identity_glass_similarity_percent_min": MIN_IDENTITY_GLASS_SIMILARITY,
            "whole_window_similarity_percent_min": MIN_WHOLE_WINDOW_SIMILARITY,
        },
        "matrix": {},
    }
    failures = []
    for row, background in enumerate(BACKGROUNDS):
        y = header_height + row * (label_height + image_height + gutter)
        text(draw, (8, y + 61), BACKGROUND_LABELS[background], "#ffffff", 17)
        report["matrix"][background] = {}
        for column, variant in enumerate(VARIANTS):
            root = RAW / background / variant
            metrics = json.loads((root / "metrics.json").read_text())
            report["matrix"][background][variant] = metrics
            score = metrics["glass_crop"]["similarity_percent"]
            minimum = (
                MIN_IDENTITY_GLASS_SIMILARITY
                if variant == "identity"
                else MIN_MATERIAL_GLASS_SIMILARITY
            )
            if score < minimum:
                failures.append(f"{background}/{variant} glass {score:.4f}% < {minimum:.2f}%")
            whole = metrics["whole_window"]["similarity_percent"]
            if whole < MIN_WHOLE_WINDOW_SIMILARITY:
                failures.append(
                    f"{background}/{variant} whole window {whole:.4f}% "
                    f"< {MIN_WHOLE_WINDOW_SIMILARITY:.2f}%"
                )
            crop = Image.open(root / "glass-comparison.png").convert("RGB")
            crop.thumbnail((cell_width, image_height), Image.Resampling.LANCZOS)
            x = row_label_width + column * (cell_width + gutter)
            text(draw, (x + 8, y + 8), f"SwiftUI | Godot   {score:.2f}%", "#b8b8c0", 14)
            sheet.paste(crop, (x, y + label_height))

    sheet.save(OUT / "background-matrix.png", optimize=True)
    (OUT / "background-metrics.json").write_text(json.dumps(report, indent=2) + "\n")
    if failures:
        raise SystemExit("visual acceptance failed:\n" + "\n".join(failures))


if __name__ == "__main__":
    main()
