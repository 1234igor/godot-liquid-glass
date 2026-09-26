#!/usr/bin/env python3
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat


ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "captures" / "raw" / "interactions"
OUT = ROOT / "captures"
STATES = ["rest", "hover", "pressed"]
CONTROL_BOX = (760, 1204, 1640, 1408)


def difference_mae(first: Image.Image, second: Image.Image) -> float:
    difference = ImageChops.difference(first.convert("RGB"), second.convert("RGB"))
    return round(sum(ImageStat.Stat(difference).mean) / 3.0, 4)


def main() -> None:
    crops = []
    images = {}
    for state in STATES:
        image = Image.open(RAW / f"{state}.png").convert("RGB")
        if image.size != (2400, 1600):
            raise SystemExit(f"{state} capture is {image.size}, expected 2400x1600")
        images[state] = image.crop(CONTROL_BOX)
        crop = images[state].resize((660, 153), Image.Resampling.LANCZOS)
        labeled = Image.new("RGB", (crop.width, crop.height + 42), "#111114")
        labeled.paste(crop, (0, 42))
        draw = ImageDraw.Draw(labeled)
        draw.text((14, 11), state.capitalize(), fill="white", font=ImageFont.load_default(size=16))
        crops.append(labeled)

    report = {
        "capture_size_pixels": [2400, 1600],
        "control_bounds_pixels": list(CONTROL_BOX),
        "rest_to_hover_mae_0_255": difference_mae(images["rest"], images["hover"]),
        "hover_to_pressed_mae_0_255": difference_mae(images["hover"], images["pressed"]),
        "rest_to_pressed_mae_0_255": difference_mae(images["rest"], images["pressed"]),
    }
    if min(report[key] for key in report if key.endswith("mae_0_255")) <= 0.05:
        raise SystemExit("interaction captures are not visibly distinct")

    sheet = Image.new("RGB", (sum(crop.width for crop in crops), max(crop.height for crop in crops)), "#111114")
    x = 0
    for crop in crops:
        sheet.paste(crop, (x, 0))
        x += crop.width
    sheet.save(OUT / "interaction-states.png", optimize=True)
    (OUT / "interaction-metrics.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
