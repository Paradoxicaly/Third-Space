#!/usr/bin/env python3
"""Generate a provisional native open-field-guide icon without third-party dependencies."""
from pathlib import Path
import struct
import zlib

SIZE = 1024
CREAM = bytes.fromhex("F7F5EC")
FOREST = bytes.fromhex("488C42")
PAPER = bytes.fromhex("FFFDF7")
INK = bytes.fromhex("285A2D")


def pixel(x, y):
    if 170 <= x < 854 and 210 <= y < 810:
        if 252 <= x < 772 and 300 <= y < 705:
            # Two pages, with a sloping bottom edge and a clear dark binding.
            page_bottom = 675 + abs(x - 512) * 0.12
            if y < page_bottom:
                return INK if abs(x - 512) < 8 else PAPER
        return FOREST
    return CREAM


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def main():
    rows = b"".join(b"\x00" + b"".join(pixel(x, y) for x in range(SIZE)) for y in range(SIZE))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
    target = Path(__file__).resolve().parents[1] / "ThirdSpace/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    target.write_bytes(png)
    print(f"Generated {target}: {SIZE}x{SIZE}, RGB, opaque")


if __name__ == "__main__":
    main()
