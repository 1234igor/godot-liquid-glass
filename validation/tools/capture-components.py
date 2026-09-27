#!/usr/bin/env python3
"""Capture the production addon. Set GODOT to a background-safe launcher if needed."""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main():
    for background in ("harbour", "city-night", "prism", "facade"):
        for variant in ("regular", "clear", "regular-tinted", "clear-tinted", "identity"):
            output = ROOT / "validation/captures/raw/components" / background / f"{variant}.png"
            output.parent.mkdir(parents=True, exist_ok=True)
            output.unlink(missing_ok=True)
            process = subprocess.Popen([
                os.environ.get("GODOT", "godot"), "--path", str(ROOT),
                "--script", "res://validation/godot/scripts/capture_component.gd", "--",
                f"--variant={variant}", f"--background={background}", f"--shot={output}",
            ])
            try:
                status = process.wait(timeout=90)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                raise
            if status != 0:
                raise RuntimeError(f"capture exited with {status}: {output}")
            if not output.is_file():
                raise RuntimeError(f"capture missing: {output}")


if __name__ == "__main__":
    main()
