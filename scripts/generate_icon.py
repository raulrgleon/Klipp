#!/usr/bin/env python3
"""Generate Klipp app icons: amber clipboard on a dark squircle."""

from __future__ import annotations

import math
import struct
import subprocess
import zlib
from pathlib import Path


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + rgba[y * width * 4 : (y + 1) * width * 4] for y in range(height))
    payload = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(payload)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
    )


def rounded_box(px: float, py: float, x: float, y: float, w: float, h: float, r: float, aa: float = 0.004) -> float:
    cx = x + w * 0.5
    cy = y + h * 0.5
    hx = w * 0.5 - r
    hy = h * 0.5 - r
    dx = abs(px - cx) - hx
    dy = abs(py - cy) - hy
    outside = math.hypot(max(dx, 0.0), max(dy, 0.0)) + min(max(dx, dy), 0.0) - r
    if outside <= 0:
        return 1.0
    if outside >= aa:
        return 0.0
    return 1.0 - outside / aa


def generate(size: int = 1024) -> bytes:
    pixels = bytearray(size * size * 4)
    bg_dark = (20, 20, 24)
    bg_mid = (40, 34, 28)
    clip = (245, 165, 36)
    clip_dark = (186, 108, 16)
    paper = (252, 246, 234)
    line = (214, 196, 160)
    metal = (255, 216, 128)
    metal_dark = (210, 150, 48)

    for y in range(size):
        fy = (y + 0.5) / size
        for x in range(size):
            fx = (x + 0.5) / size
            bg = mix(bg_dark, bg_mid, (fx * 0.35) + (fy * 0.65))
            alpha = rounded_box(fx, fy, 0.06, 0.06, 0.88, 0.88, 0.21)
            color = bg

            body = rounded_box(fx, fy, 0.28, 0.24, 0.44, 0.56, 0.065)
            if body > 0:
                shade = mix(clip, clip_dark, max(0.0, (fy - 0.24) / 0.56))
                color = mix(color, shade, body)

            paper_a = rounded_box(fx, fy, 0.325, 0.34, 0.35, 0.40, 0.035)
            if paper_a > 0:
                color = mix(color, paper, paper_a)
                for ly, right in ((0.43, 0.64), (0.50, 0.64), (0.57, 0.60), (0.64, 0.56)):
                    if abs(fy - ly) < 0.007 and 0.365 < fx < right:
                        color = mix(color, line, paper_a * 0.85)

            clip_top = rounded_box(fx, fy, 0.405, 0.145, 0.19, 0.155, 0.055)
            hole = rounded_box(fx, fy, 0.445, 0.175, 0.11, 0.08, 0.03)
            if clip_top > 0:
                color = mix(color, mix(metal, metal_dark, fy * 0.4), clip_top)
            if hole > 0:
                color = mix(color, clip_dark, hole)

            idx = (y * size + x) * 4
            pixels[idx : idx + 4] = bytes([color[0], color[1], color[2], int(255 * alpha)])

    return bytes(pixels)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    iconset = root / "Klipp" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
    iconset.mkdir(parents=True, exist_ok=True)
    master_path = iconset / "icon_1024.png"
    write_png(master_path, 1024, 1024, generate(1024))

    sizes = {
        "icon_16.png": 16,
        "icon_16@2x.png": 32,
        "icon_32.png": 32,
        "icon_32@2x.png": 64,
        "icon_128.png": 128,
        "icon_128@2x.png": 256,
        "icon_256.png": 256,
        "icon_256@2x.png": 512,
        "icon_512.png": 512,
        "icon_512@2x.png": 1024,
    }
    for name, dim in sizes.items():
        dest = iconset / name
        if dim == 1024:
            dest.write_bytes(master_path.read_bytes())
        else:
            subprocess.run(
                ["sips", "-z", str(dim), str(dim), str(master_path), "--out", str(dest)],
                check=True,
                capture_output=True,
            )

    (iconset / "Contents.json").write_text(
        """{
  "images" : [
    { "filename" : "icon_16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
""",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
