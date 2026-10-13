#!/usr/bin/env python3
"""Verify DESIGN.md's exact opaque sRGB token pairs (no third-party packages).

JSON holds named pairs only: color values come from DESIGN.md frontmatter. The
restricted frontmatter reader intentionally rejects complex YAML color values;
keep colors as flat, quoted #RRGGBB tokens or extend/test this parser.
"""

from __future__ import annotations

import argparse
from decimal import Decimal
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
COLOR_LINE = re.compile(r'^  ([A-Za-z][A-Za-z0-9._-]*): "(#[0-9A-Fa-f]{6})"$')
BRAND = {
    "brand.forest": "#488C42",
    "brand.moss": "#698C46",
    "brand.leaf": "#428C56",
    "brand.olive": "#868C42",
    "brand.teal": "#428C6F",
}
D = Decimal
TEXT = "text"
NON_TEXT = "nontext"


def required_pairs() -> set[tuple[str, str, str]]:
    light_surfaces = ("background.canvas", "background.surface")
    light_text = ("text.primary", "text.secondary", "action.strong", "text.community", "status.warning", "status.destructive")
    dark_text = ("dark.text.primary", "dark.text.secondary")
    required = {(fg, bg, TEXT) for fg in light_text for bg in light_surfaces}
    required |= {(fg, bg, TEXT) for fg in dark_text for bg in ("dark.canvas", "dark.surface")}
    required |= {
        ("text.onAction", "action.strong", TEXT),
        ("text.onAction", "status.destructive", TEXT),
        ("action.strong", "surface.selected", TEXT),
        ("text.primary", "surface.selected", TEXT),
        ("dark.canvas", "dark.action", TEXT),
    }
    required |= {(fg, "dark.surface", TEXT) for fg in ("dark.action", "dark.community", "dark.warning", "dark.destructive")}
    required |= {("border.control", bg, NON_TEXT) for bg in (*light_surfaces, "surface.selected")}
    required |= {("action.strong", "surface.selected", NON_TEXT),
                 ("background.canvas", "brand.forest", NON_TEXT),
                 ("dark.border.control", "dark.surface", NON_TEXT)}
    required |= {(brand, bg, NON_TEXT) for brand in BRAND for bg in (*light_surfaces, "dark.surface")}
    return required


def load_colors(path: Path) -> dict[str, str]:
    source = path.read_text(encoding="utf-8")
    if not source.startswith("---\n"):
        raise ValueError("DESIGN.md must start with YAML frontmatter")
    parts = source.split("---\n", 2)
    if len(parts) < 3:
        raise ValueError("unclosed DESIGN.md frontmatter")
    colors: dict[str, str] = {}
    in_colors = False
    found = False
    for line in parts[1].splitlines():
        if line == "colors:":
            if found:
                raise ValueError("duplicate colors: section")
            found = in_colors = True
            continue
        if in_colors and line and not line.startswith(" "):
            in_colors = False
        if not in_colors or not line.strip():
            continue
        match = COLOR_LINE.fullmatch(line)
        if not match:
            raise ValueError(f"invalid color definition (use flat quoted #RRGGBB): {line!r}")
        name, value = match.groups()
        if name in colors:
            raise ValueError(f"duplicate color token: {name}")
        colors[name] = value.upper()
    if not colors:
        raise ValueError("no DESIGN.md colors found")
    for name, value in BRAND.items():
        if colors.get(name) != value:
            raise ValueError(f"exact identity color {name} must remain {value}")
    return colors


def unique_object(items: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in items:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def luminance(hex_color: str) -> Decimal:
    channels = [D(int(hex_color[i:i + 2], 16)) / D(255) for i in (1, 3, 5)]
    linear = [c / D("12.92") if c <= D("0.04045") else ((c + D("0.055")) / D("1.055")) ** D("2.4") for c in channels]
    return sum((weight * value for weight, value in zip((D("0.2126"), D("0.7152"), D("0.0722")), linear)), D(0))


def contrast(foreground: str, background: str) -> Decimal:
    a, b = luminance(foreground), luminance(background)
    return (max(a, b) + D("0.05")) / (min(a, b) + D("0.05"))


def verify(design: Path, pairs_file: Path) -> tuple[int, list[str]]:
    colors = load_colors(design)
    document = json.loads(pairs_file.read_text(encoding="utf-8"), object_pairs_hook=unique_object)
    if not isinstance(document, dict) or document.get("schema_version") != 1 or document.get("source") != "DESIGN.md#colors":
        raise ValueError("unsupported contrast-pairs schema/source")
    pairs = document.get("pairs")
    if not isinstance(pairs, list) or not pairs:
        raise ValueError("pairs must be a nonempty list")
    errors: list[str] = []
    seen_ids: set[str] = set()
    seen_pairs: set[tuple[str, str, str]] = set()
    raw_brand = set(BRAND.values())
    for position, pair in enumerate(pairs, 1):
        if not isinstance(pair, dict) or set(pair) != {"id", "foreground", "background", "kind"}:
            errors.append(f"pair {position}: expected id, foreground, background, kind only")
            continue
        ident, fg, bg, kind = (pair[key] for key in ("id", "foreground", "background", "kind"))
        if not all(isinstance(item, str) and item for item in (ident, fg, bg, kind)):
            errors.append(f"pair {position}: fields must be nonempty strings")
            continue
        if ident in seen_ids:
            errors.append(f"{ident}: duplicate id")
        seen_ids.add(ident)
        key = (fg, bg, kind)
        if key in seen_pairs:
            errors.append(f"{ident}: duplicate pair {key}")
        seen_pairs.add(key)
        if kind not in (TEXT, NON_TEXT):
            errors.append(f"{ident}: unknown kind {kind!r}")
            continue
        if fg not in colors or bg not in colors:
            errors.append(f"{ident}: unknown token(s): {fg!r}, {bg!r}")
            continue
        if kind == TEXT and (fg.startswith("brand.") or bg.startswith("brand.") or colors[fg] in raw_brand or colors[bg] in raw_brand):
            errors.append(f"{ident}: raw brand color/alias cannot be text OR a labelled fill")
            continue
        ratio = contrast(colors[fg], colors[bg])
        minimum = D("4.5") if kind == TEXT else D("3")
        # Do not round the ratio before comparing with the normative threshold.
        if ratio < minimum:
            errors.append(f"{ident}: {fg} {colors[fg]} on {bg} {colors[bg]} = {ratio:.4f}:1 < {minimum}:1")
    missing = required_pairs() - seen_pairs
    if missing:
        errors.append(f"required coverage missing ({len(missing)}): " + ", ".join(str(p) for p in sorted(missing)))
    return len(pairs), errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--design", type=Path, default=ROOT / "DESIGN.md")
    parser.add_argument("--pairs", type=Path, default=ROOT / "docs/design/contrast-pairs.json")
    args = parser.parse_args()
    try:
        count, errors = verify(args.design, args.pairs)
    except (OSError, ValueError, TypeError, json.JSONDecodeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    if errors:
        print(f"FAIL: {len(errors)} issue(s) across {count} pair(s)", file=sys.stderr)
        return 1
    print(f"PASS: {count} DESIGN.md token pairs; unrounded WCAG sRGB thresholds (text >=4.5:1, essential nontext >=3:1); brand text/fill misuse excluded")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
