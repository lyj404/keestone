"""Generate per-seed tray/window icons from the master app icon.

Recolors the indigo background to each ThemeSeed primary while keeping the
white keyhole glyph and rounded-square alpha mask.
"""
from __future__ import annotations

import colorsys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "icons" / "app_icon.png"
OUT_DIR = ROOT / "assets" / "icons" / "seeds"

# primary / primaryDark from lib/core/theme/theme_seed.dart
SEEDS = {
    "indigo": (0x4F46E5, 0x4338CA),
    "emerald": (0x059669, 0x047857),
    "sky": (0x0284C7, 0x0369A1),
    "amber": (0xD97706, 0xB45309),
    "slate": (0x475569, 0x334155),
    "rose": (0xE11D48, 0xBE123C),
}

# Source background samples (dark indigo) — map luminance onto seed ramp.
SRC_A = (0x2B, 0x0D, 0x9A)
SRC_B = (0x1C, 0x0F, 0xAE)


def hex_rgb(value: int) -> tuple[int, int, int]:
    return ((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)


def luma(rgb: tuple[int, int, int]) -> float:
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        round(a[0] + (b[0] - a[0]) * t),
        round(a[1] + (b[1] - a[1]) * t),
        round(a[2] + (b[2] - a[2]) * t),
    )


def recolor(img: Image.Image, primary: int, primary_dark: int) -> Image.Image:
    src = img.convert("RGBA")
    out = src.copy()
    px_src = src.load()
    px_out = out.load()
    w, h = src.size
    c0 = hex_rgb(primary_dark)
    c1 = hex_rgb(primary)
    src_l0 = luma(SRC_A)
    src_l1 = luma(SRC_B)

    for y in range(h):
        for x in range(w):
            r, g, b, a = px_src[x, y]
            if a < 8:
                continue
            # White glyph (keyhole / ring highlights).
            if r > 200 and g > 200 and b > 200:
                continue
            # Skip near-black noise if any.
            if r < 8 and g < 8 and b < 8:
                continue
            # Map source diagonal gradient onto seed ramp.
            t = (x + y) / float(w + h - 2)
            seed_col = mix(c0, c1, t)
            # Preserve slight source variation around the ramp midpoint.
            src_mid = mix(SRC_A, SRC_B, t)
            dr = r - src_mid[0]
            dg = g - src_mid[1]
            db = b - src_mid[2]
            nr = max(0, min(255, seed_col[0] + dr))
            ng = max(0, min(255, seed_col[1] + dg))
            nb = max(0, min(255, seed_col[2] + db))
            px_out[x, y] = (nr, ng, nb, a)
    return out


def save_variants(img: Image.Image, stem: str) -> None:
    png_path = OUT_DIR / f"{stem}.png"
    img.resize((256, 256), Image.Resampling.LANCZOS).save(png_path, optimize=True)

    ico_path = OUT_DIR / f"{stem}.ico"
    sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (256, 256)]
    img.resize((256, 256), Image.Resampling.LANCZOS).save(
        ico_path,
        format="ICO",
        sizes=sizes,
    )
    print(f"wrote {png_path.name} ({png_path.stat().st_size} B), {ico_path.name} ({ico_path.stat().st_size} B)")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE)
    if source.size != (1024, 1024):
        source = source.resize((1024, 1024), Image.Resampling.LANCZOS)
    for name, (primary, dark) in SEEDS.items():
        colored = recolor(source, primary, dark)
        save_variants(colored, name)
    print(f"done: {len(SEEDS)} seeds -> {OUT_DIR}")


if __name__ == "__main__":
    main()
