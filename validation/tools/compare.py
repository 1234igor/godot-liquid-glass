#!/usr/bin/env python3
import json
import io
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageCms, ImageDraw, ImageEnhance, ImageFont, ImageStat


SRGB_PROFILE = ImageCms.createProfile("sRGB")


def normalized_srgb(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    profile = image.info.get("icc_profile")
    if not profile:
        return rgb
    source_profile = ImageCms.ImageCmsProfile(io.BytesIO(profile))
    return ImageCms.profileToProfile(rgb, source_profile, SRGB_PROFILE, outputMode="RGB")


def label(image: Image.Image, text: str) -> Image.Image:
    band = Image.new("RGB", (image.width, 42), "#111114")
    draw = ImageDraw.Draw(band)
    draw.text((14, 11), text, fill="white", font=ImageFont.load_default(size=16))
    result = Image.new("RGB", (image.width, image.height + band.height), "#111114")
    result.paste(band, (0, 0))
    result.paste(image.convert("RGB"), (0, band.height))
    return result


def side_by_side(images: list[Image.Image]) -> Image.Image:
    result = Image.new("RGB", (sum(image.width for image in images), max(image.height for image in images)))
    x = 0
    for image in images:
        result.paste(image, (x, 0))
        x += image.width
    return result


def metrics(reference: Image.Image, replica: Image.Image) -> dict[str, float]:
    difference = ImageChops.difference(reference.convert("RGB"), replica.convert("RGB"))
    stat = ImageStat.Stat(difference)
    mae = sum(stat.mean) / 3.0
    rms = (sum(value * value for value in stat.rms) / 3.0) ** 0.5
    return {
        "mae_0_255": round(mae, 4),
        "rms_0_255": round(rms, 4),
        "similarity_percent": round((1.0 - mae / 255.0) * 100.0, 4),
    }


def validate_capture_geometry(reference: Image.Image, replica: Image.Image) -> tuple[int, int]:
    if reference.size != replica.size:
        raise ValueError(
            f"capture size mismatch: SwiftUI is {reference.size}, Godot is {replica.size}"
        )
    width, height = reference.size
    if (width, height) != (2400, 1600):
        raise ValueError(f"expected a 2400x1600 Retina capture, got {width}x{height}")
    return reference.size


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("usage: compare.py <swiftui.png> <godot.png> <output-dir>")
    reference_source = Image.open(sys.argv[1])
    replica_source = Image.open(sys.argv[2])
    try:
        capture_size = validate_capture_geometry(reference_source, replica_source)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    reference = normalized_srgb(reference_source)
    replica = normalized_srgb(replica_source)

    output = Path(sys.argv[3])
    output.mkdir(parents=True, exist_ok=True)
    glass_box = (700, 1132, 1700, 1460)
    control_box = (760, 1204, 1640, 1408)
    native_glass = reference.crop(glass_box)
    godot_glass = replica.crop(glass_box)
    native_control = reference.crop(control_box)
    godot_control = replica.crop(control_box)
    difference = ImageChops.difference(reference.convert("RGB"), replica.convert("RGB"))
    amplified = ImageEnhance.Contrast(difference).enhance(4.0)

    label(reference, "SwiftUI native glass").save(output / "native-labeled.png")
    label(replica, "Godot live shader").save(output / "godot-labeled.png")
    side_by_side([
        label(reference, "SwiftUI native glass"),
        label(replica, "Godot live shader"),
    ]).save(output / "comparison.png")
    side_by_side([
        label(native_glass, "SwiftUI glass crop"),
        label(godot_glass, "Godot glass crop"),
    ]).save(output / "glass-comparison.png")
    label(amplified, "Absolute RGB difference, contrast x4").save(output / "difference-x4.png")

    report = {
        "capture_size": capture_size,
        "comparison_color_space": "sRGB",
        "whole_window": metrics(reference, replica),
        "glass_crop": metrics(native_glass, godot_glass),
        "control_bounds": metrics(native_control, godot_control),
        "glass_crop_pixels": glass_box,
        "control_bounds_pixels": control_box,
    }
    (output / "metrics.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
