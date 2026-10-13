#!/usr/bin/env python3
"""Generate abstract SYNTHETIC test images for the native fixtures (no third-party dependencies).

These are deliberately non-photographic patterns: they exercise image layout, credit and alt-text
paths without inventing a picture of a real venue. Never replace them with stock or generated scenes.
"""
from pathlib import Path
import json
import math
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ThirdSpace/Resources/Assets.xcassets/SyntheticMedia"
W, H = 800, 600


def hex_rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


CREAM, PAPER, FOREST, MOSS, LEAF, OLIVE, TEAL, INK = map(hex_rgb, (
    "F7F5EC", "FFFDF7", "488C42", "698C46", "428C56", "868C42", "428C6F", "285A2D"))
SAND, CLAY, SKY = hex_rgb("E9DFC7"), hex_rgb("C9A27A"), hex_rgb("CFE0D6")


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shelves(x, y):
    # Reading room: horizontal shelf bands of varied "spines".
    band = y // 100
    if y % 100 < 10:
        return INK
    spine = (x + band * 37) // (28 + band * 3)
    return (FOREST, MOSS, OLIVE, SAND, TEAL, CLAY)[(spine + band) % 6]


def window(x, y):
    # Reading room, second view: a window grid with soft light.
    light = mix(SKY, PAPER, y / H)
    if 120 < x < 680 and 80 < y < 520:
        if (x - 120) % 140 < 10 or (y - 80) % 110 < 10:
            return INK
        return light
    return mix(SAND, CLAY, (x + y) / (W + H))


def tables(x, y):
    # Library/social space: round tables on a warm floor.
    for cx, cy, r in ((200, 200, 90), (560, 180, 70), (380, 420, 110), (680, 470, 60)):
        d = math.hypot(x - cx, y - cy)
        if d < r:
            return TEAL if d < r - 14 else INK
    return mix(SAND, CREAM, y / H)


def hills(x, y):
    # Garden: layered hills under a sun.
    if math.hypot(x - 620, y - 140) < 70:
        return hex_rgb("E4CE83")
    # Nearest hill first, so the front layer wins where they overlap.
    for base, amp, freq, color in ((480, 25, 0.022, FOREST), (400, 30, 0.015, LEAF), (330, 40, 0.010, MOSS)):
        if y > base + amp * math.sin(x * freq + base):
            return color
    return mix(SKY, CREAM, min(1, y / 330))


def stripes(x, y):
    # Workshop: diagonal work-surface stripes and tool blocks.
    if 90 < x < 330 and 360 < y < 520:
        return OLIVE
    if 470 < x < 720 and 90 < y < 230:
        return CLAY
    return INK if ((x + y) // 40) % 2 == 0 else mix(SAND, PAPER, x / W)


IMAGES = {
    "synthetic-media-reading-room": shelves,
    "synthetic-media-reading-room-window": window,
    "synthetic-media-library": tables,
    "synthetic-media-garden": hills,
    "synthetic-media-workshop": stripes,
}


def png(pixel):
    raw = bytearray()
    for y in range(H):
        raw.append(0)
        for x in range(W):
            raw.extend(pixel(x, y))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    for name, pixel in IMAGES.items():
        folder = OUT / f"{name}.imageset"
        folder.mkdir(exist_ok=True)
        (folder / f"{name}.png").write_bytes(png(pixel))
        contents = {"images": [{"filename": f"{name}.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}
        (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
        print(f"wrote {folder.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
