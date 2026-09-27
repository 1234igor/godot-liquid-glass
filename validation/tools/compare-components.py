#!/usr/bin/env python3
"""Compare real addon captures with GPUI and SwiftUI in sRGB. Requires NumPy and Pillow."""
import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view
from PIL import Image, ImageCms, ImageDraw, ImageFont, PngImagePlugin

PNG_INFO = PngImagePlugin.PngInfo()
PNG_INFO.add(b"sRGB", b"\x00")
ROOT = Path(__file__).resolve().parents[2]
CAPTURES = ROOT / "validation/captures"
BOX = (760, 1204, 1640, 1396)  # The control itself, not the surrounding photograph.
VARIANTS = ("regular", "clear", "regular-tinted", "clear-tinted")
BACKGROUNDS = ("harbour", "city-night", "prism", "facade")


def load(path):
    with Image.open(path) as image:
        if image.size != (2400, 1600):
            raise ValueError(f"{path}: expected 2400x1600, got {image.size}")
        rgb = image.convert("RGB")
        if image.info.get("icc_profile"):
            rgb = ImageCms.profileToProfile(rgb,
                ImageCms.ImageCmsProfile(io.BytesIO(image.info["icc_profile"])),
                ImageCms.createProfile("sRGB"), outputMode="RGB")
        return rgb


def ssim(a, b):
    # Gaussian-window SSIM: sigma=1.5, 11x11 window, population covariance,
    # K1=.01, K2=.03, data range 255; average channels and valid window centers.
    kernel = np.exp(-np.arange(-5, 6) ** 2 / (2 * 1.5 ** 2))
    kernel /= kernel.sum()

    def blur(value):
        value = np.einsum("...k,k->...", sliding_window_view(value, 11, axis=0), kernel)
        return np.einsum("...k,k->...", sliding_window_view(value, 11, axis=1), kernel)

    u, v = blur(a), blur(b)
    va, vb, cov = blur(a * a) - u * u, blur(b * b) - v * v, blur(a * b) - u * v
    return float(np.mean(((2 * u * v + 2.55 ** 2) * (2 * cov + 7.65 ** 2)) /
                         ((u * u + v * v + 2.55 ** 2) * (va + vb + 7.65 ** 2))))


def metrics(reference, output):
    a = np.asarray(reference.crop(BOX), dtype=np.float64)
    b = np.asarray(output.crop(BOX), dtype=np.float64)
    delta = np.abs(a - b)
    return {"rgb_ssim": round(ssim(a, b), 6), "mae_0_255": round(float(delta.mean()), 4),
            "pixels_over_64_percent": round(float(np.mean(delta.max(axis=2) > 64) * 100), 4)}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("gpui_captures", type=Path, help="GPUI validation/captures/raw/backgrounds directory")
    args = parser.parse_args()
    report = {"color_space": "sRGB", "control_bounds": BOX,
              "method": "11x11 Gaussian RGB SSIM, sigma 1.5, population covariance; not percent matching pixels",
              "reference": "Stored GPUI and native SwiftUI captures; current Godot production addon",
              "cases": {}}
    sheet = Image.new("RGB", (1600, 1152), "#111317")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=22)
    for background in BACKGROUNDS:
        for index, variant in enumerate(VARIANTS):
            godot_path = CAPTURES / "raw/components" / background / f"{variant}.png"
            gpui_path = args.gpui_captures / background / variant / "gpui.png"
            native_path = CAPTURES / "raw/backgrounds" / background / variant / "swiftui.png"
            godot, gpui, native = load(godot_path), load(gpui_path), load(native_path)
            report["cases"][f"{background}/{variant}"] = {
                "vs_gpui": metrics(gpui, godot), "vs_native": metrics(native, godot),
                "sha256": {"godot": digest(godot_path), "gpui": digest(gpui_path), "native": digest(native_path)}}
            if background == "harbour":
                for col, (label, frame) in enumerate((("GPUI", gpui), ("Godot component", godot))):
                    x, y = 40 + col * 780, index * 288
                    draw.text((x, y + 8), f"{variant.replace('-', ' ').title()} / {label}", font=font, fill="white")
                    crop = frame.crop((700, 1132, 1700, 1460)).resize((740, 243), Image.Resampling.LANCZOS)
                    sheet.paste(crop, (x, y + 38))
    scores = [case["vs_gpui"]["rgb_ssim"] for case in report["cases"].values()]
    report["gpui_ssim_summary"] = {"mean": round(float(np.mean(scores)), 6), "min": min(scores), "max": max(scores)}
    (CAPTURES / "component-metrics.json").write_text(json.dumps(report, indent=2) + "\n")
    sheet.save(CAPTURES / "component-comparison.png", optimize=True,
               pnginfo=PNG_INFO)
    print(json.dumps(report["gpui_ssim_summary"]))


if __name__ == "__main__":
    main()
