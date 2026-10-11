#!/usr/bin/env python3
"""Regenerate the Android adaptive-icon foreground layers.

The master logo (`assets/app_icons/icon.png`) is a white eye on a transparent
1024x1024 canvas, the eye occupying ~65% of it.  Adaptive icons only guarantee a
66/108 safe zone, so this script re-pads the eye to ~62% and writes one
foreground PNG per density.  The dark background comes from
`@color/ic_launcher_background`; without an adaptive icon Android 12+ wraps the
legacy transparent icon in the system's default *white* shape — the white box
seen at launch.

Usage:  python3 scripts/generate_adaptive_icon.py
Requires: pillow
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER = os.path.join(ROOT, "assets/app_icons/icon.png")
RES = os.path.join(ROOT, "android/app/src/main/res")

# 108dp * density
DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
TARGET_FRACTION = 0.62  # eye width as a fraction of the adaptive canvas
BASE = 1024


def main() -> None:
    src = Image.open(MASTER).convert("RGBA")
    eye = src.crop(src.split()[3].getbbox())
    scale = (BASE * TARGET_FRACTION) / max(eye.size)
    eye = eye.resize(
        (max(1, round(eye.width * scale)), max(1, round(eye.height * scale))),
        Image.LANCZOS,
    )
    canvas = Image.new("RGBA", (BASE, BASE), (0, 0, 0, 0))
    canvas.paste(eye, ((BASE - eye.width) // 2, (BASE - eye.height) // 2), eye)

    # Committed source for flutter_launcher_icons' adaptive_icon_foreground.
    # Kept outside assets/ so it is never bundled into the app.
    master_out = os.path.join(ROOT, "scripts/icon_foreground.png")
    canvas.save(master_out)
    print("wrote", master_out)

    for name, size in DENSITIES.items():
        out = os.path.join(RES, f"mipmap-{name}/launcher_icon_foreground.png")
        canvas.resize((size, size), Image.LANCZOS).save(out)
        print("wrote", out)


if __name__ == "__main__":
    main()
