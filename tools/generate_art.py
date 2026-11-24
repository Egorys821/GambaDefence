"""Generates every pixel-art sprite used by Gamba Defence.

Usage (from the project root, needs Pillow):
    python tools/generate_art.py            # everything
    python tools/generate_art.py machines   # only machine symbols and cabinet skins
    python tools/generate_art.py ui         # only the button and panel kit

Sprites are described as ASCII maps (one character = one pixel, see PALETTE)
or drawn procedurally. Edit a map, re-run the script and Godot re-imports the PNG.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets" / "sprites"

PALETTE_HEX = {
    "k": "#1a1220",  # outline
    "w": "#f4f4f4",  # white
    "g": "#b8b8c8",  # light steel
    "G": "#6a6a80",  # dark steel
    "y": "#f8d038",  # gold
    "Y": "#c08820",  # dark gold
    "o": "#e07818",  # orange
    "r": "#d03838",  # red
    "R": "#7a1c28",  # dark red
    "b": "#9a6a34",  # wood
    "B": "#5a3418",  # dark wood
    "s": "#f0c090",  # skin
    "n": "#3868d0",  # blue
    "N": "#203878",  # dark blue
    "c": "#60d8f8",  # cyan / magic
    "p": "#9050d0",  # purple
    "P": "#502880",  # dark purple
    "l": "#58b048",  # green
    "L": "#2c6830",  # dark green
    "m": "#d0f4ec",  # ghost
    "M": "#80c4c4",  # ghost shade
    "e": "#ff4060",  # evil eye glow
}


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    h = hex_color.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), alpha


PALETTE = {key: rgba(value) for key, value in PALETTE_HEX.items()}


def from_map(name: str, rows: list[str], width: int = 16) -> Image.Image:
    """Builds an image from an ASCII map. '.' is transparent."""
    img = Image.new("RGBA", (width, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        if len(row) != width:
            print(f"warning: {name} row {y} is {len(row)} px wide (expected {width})")
        for x, ch in enumerate(row[:width]):
            if ch != ".":
                img.putpixel((x, y), PALETTE[ch])
    return img


def save(img: Image.Image, rel_path: str) -> None:
    path = SPRITES / rel_path
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"wrote {path.relative_to(ROOT)}")


# --------------------------------------------------------------------------
# Slot machine symbols (16x16)
# --------------------------------------------------------------------------
SYMBOLS = {
    "coin": [
        "................",
        ".....kkkkkk.....",
        "...kkYYYYYYkk...",
        "..kYyyyyyyyyYk..",
        ".kYyywyyyyyyyYk.",
        ".kYywyyYYYyyyYk.",
        "kYyyyyYyyyYyyyYk",
        "kYyyyYyyyyyYyyYk",
        "kYyyyYyyyyyYyyYk",
        "kYyyyYyyyyyYyyYk",
        "kYyyyyYyyyYyyyYk",
        ".kYyyyyYYYyyyYk.",
        ".kYyyyyyyyyyyYk.",
        "..kYyyyyyyyyYk..",
        "...kkYYYYYYkk...",
        ".....kkkkkk.....",
    ],
    "sword": [
        "..............kk",
        ".............kgk",
        "............kgwk",
        "...........kgwk.",
        "..........kgwk..",
        ".........kgwk...",
        "........kgwk....",
        "..kk...kgwk.....",
        "..kYk.kgwk......",
        "...kYkgwk.......",
        "....kYwk........",
        "....kbYYk.......",
        "...kbk.kYk......",
        "..kbk...kk......",
        ".kYk............",
        "..k.............",
    ],
    "bow": [
        "......kkk.......",
        ".....kbbBk......",
        "....kbk.kgk.....",
        "....kbk..g......",
        "...kbk...g......",
        "...kbk...g...k..",
        "...kbk...g...kk.",
        "rrkbkbbbbbbbbbgk",
        "...kbk...g...kk.",
        "...kbk...g...k..",
        "...kbk...g......",
        "....kbk..g......",
        "....kbk.kgk.....",
        ".....kbbBk......",
        "......kkk.......",
        "................",
    ],
    "hammer": [
        "................",
        "...kkkkkkkkkk...",
        "..kGgggggggggk..",
        "..kGgwwwwwwggk..",
        "..kGgggggggggk..",
        "...kkkkbbkkkk...",
        "......kbBk......",
        "......kbBk......",
        "......kbBk......",
        "......kbBk......",
        "......kbBk......",
        "......kbBk......",
        "......kbBk......",
        ".....kYYYYk.....",
        "......kkkk......",
        "................",
    ],
    "helm": [
        "......rrr.......",
        ".....rRrrk......",
        "......kkkk......",
        "....kkggggkk....",
        "...kgwwgggggk...",
        "..kgwggggggGGk..",
        "..kgggggggggGk..",
        "..kkkkkkkkkkkk..",
        "..kgkkgkkgkkGk..",
        "..kggggggggGGk..",
        "..kgggggggggGk..",
        "...kgggggggGk...",
        "...kkggggGGkk...",
        "....kkkkkkkk....",
        "................",
        "................",
    ],
    "staff": [
        "...........kkk..",
        "..........kcwck.",
        ".........kcwwcck",
        ".........kccccPk",
        "..........kcPPk.",
        ".........kbkkk..",
        "........kbk.....",
        ".......kbk......",
        "......kbk.......",
        ".....kbk........",
        "....kbk.........",
        "...kbk..........",
        "..kbk...........",
        ".kbk............",
        ".kk.............",
        "................",
    ],
    "skull": [
        "................",
        "....kkkkkkkk....",
        "...kwwwwwwwwk...",
        "..kwwwwwwwwwgk..",
        "..kwwwwwwwwwgk..",
        "..kwkkkwwkkkgk..",
        "..kwkkkwwkkkgk..",
        "..kwkkkwwkkkgk..",
        "..kwwwwkkwwwgk..",
        "...kwwwkkwwgk...",
        "....kwwwwwgk....",
        "....kwkwkwkk....",
        "....kkwkwkgk....",
        ".....kkkkkk.....",
        "................",
        "................",
    ],
    "rune": [
        ".......kk.......",
        "......kcck......",
        ".....kcwcck.....",
        "....kcwcccpk....",
        "...kcwcccpppk...",
        "..kcccccppppPk..",
        ".kcccccpppppPPk.",
        "kpppppppPPPPPPPk",
        ".kpppppPPPPPPPk.",
        "..kppppPPPPPPk..",
        "...kpppPPPPPk...",
        "....kppPPPPk....",
        ".....kpPPPk.....",
        "......kPPk......",
        ".......kk.......",
        "................",
    ],
}

# --------------------------------------------------------------------------
# Troops (16x16, facing right)
# --------------------------------------------------------------------------
UNITS = {
    "swordsman": [
        ".............k..",
        ".....kkkkk..kwk.",
        "....kgggggk.kwk.",
        "....kgwggGk.kwk.",
        "....kkssssk.kwk.",
        "....ksssksk.kwk.",
        ".....kssssk.kwk.",
        "....kknnnnkkYYYk",
        "...knnnnnnkssk..",
        "...knknnnnkbk...",
        "...ksknnnnk.....",
        "....kkYYYYk.....",
        ".....knnnnk.....",
        ".....knkknk.....",
        ".....kBk.kBk....",
        ".....kkk.kkk....",
    ],
    "archer": [
        "................",
        ".....kkkkk......",
        "....kLlllLk.....",
        "...kLlllllLk.bk.",
        "...kLkssssk.w.bk",
        "....ksssksk.w.bk",
        ".....kssssk.w.bk",
        "....kklllkkkwkbk",
        "...kllllllsssbbk",
        "...klklllkk.w.bk",
        "...ksklllk..w.bk",
        "....kkBBBk...bk.",
        ".....klllk......",
        ".....klkkLk.....",
        ".....kBk.kBk....",
        ".....kkk.kkk....",
    ],
    "knight": [
        "......rr........",
        ".....rRrr.......",
        "....kkkkkk......",
        "...kgwgggGk.....",
        "...kgggggGk..k..",
        "...kkkkkkGk.kwk.",
        "...kgGgGgGk.kwk.",
        "...kkggggkk.kwk.",
        ".kkkkgwgggGkkwk.",
        "knyynkgggggGYYYk",
        "kyyyykgggggGksk.",
        "knyynkYYYYYk....",
        ".knnk.kgGgGk....",
        "..kk..kgk.kgk...",
        ".....kGGk.kGGk..",
        ".....kkkk.kkkk..",
    ],
    "mage": [
        "......k......kk.",
        ".....kPk....kcck",
        ".....kpPk...kwck",
        "....kpppPk...kk.",
        "...kpppppPk.kbk.",
        "..kkkkkkkkkkkbk.",
        "....kssssk..kbk.",
        "....ksksskk.kbk.",
        "....kwwwwk.kssk.",
        "...kppkwwkppkbk.",
        "...kpppkkppppbk.",
        "..kpppppppppkbk.",
        "..kpPpppppPpkbk.",
        "..kPPPPPPPPPkbk.",
        "...kkkkkkkkk.bk.",
        ".............k..",
    ],
}

# --------------------------------------------------------------------------
# Evil spirits (16x16, facing left)
# --------------------------------------------------------------------------
ENEMIES = {
    "orc_catapult": [
        "................",
        "..kkk...........",
        ".kGGGk..........",
        ".kbbbk..........",
        "..kbbbk.........",
        "....kbbk...kkk..",
        ".....kbbk.kLlLk.",
        "......kbbkkleLk.",
        "...kkkkkbbkkLLk.",
        "..kbbbbbbbbkRRk.",
        "..kBkkkkkkBkRRk.",
        "..kbk....kbklLk.",
        ".kkkkkkkkkkkkkk.",
        ".kBBBBBBBBBBBBk.",
        "..kGk.....kGk...",
        "...k.......k....",
    ],
    "zombie_miner": [
        "................",
        ".......kkkkk....",
        "......kyYyyyk...",
        "....kwkYyyyyyk..",
        "......kkkkkkkk..",
        "kGGGk.kleLllk...",
        ".kbk..klllkLk...",
        "..kbk..kLLLk....",
        "...kbkkBBBBBk...",
        "....klkBbBBBBk..",
        ".....kkBBBBBBk..",
        "......kNNkNNk...",
        "......kNNkNNk...",
        "......kLk.kLk...",
        ".....kBBk.kBBk..",
        ".....kkkk.kkkk..",
    ],
    "greed_monster": [
        "................",
        ".....kkkkkk.....",
        "....kpppppPk....",
        "...kppeppepPk...",
        "...kppppppppk...",
        "..kpkkkkkkkpPk..",
        "..kpkyYyYykpPk..",
        "..kpkwkwkwkpPk..",
        ".kkppppppppppPk.",
        "kyykpppppppppkyk",
        "kyYkpppppppppkYk",
        ".kk.kppppppPPk..",
        "....kpPpppPpPk..",
        "....kpk..kpk....",
        "...kYYk..kYYk...",
        "...kkkk..kkkk...",
    ],
    "ghost": [
        "................",
        ".....kkkkkk.....",
        "....kmmmmmmk....",
        "...kmmmmmmmMk...",
        "..kmkkmmkkmmMk..",
        "..kmkekmkekmMk..",
        "..kmmmmmmmmmMk..",
        "..kmmmkkkmmmMk..",
        "..kmmmmmmmmmMk..",
        ".kmmmmmmmmmmMk..",
        "kmmkmmmmmmmMMk..",
        ".kk.kmmmmmmMMk..",
        "....kmmmmmmMMk..",
        "...kmmMmmMmmMk..",
        "...kmk.kmk.kmk..",
        "...kk..kk...kk..",
    ],
    "wraith": [
        "................",
        "......kkkk......",
        ".....kPPPPk.....",
        "....kPPPPPPk....",
        "....kPkkkkPk....",
        "....kPekekPk....",
        "....kPkkkkPk....",
        "...kPPPkkPPPk...",
        "..kPpPPPPPPpPk..",
        ".kgkPpPPPPPpPk..",
        "kgk.kPpPPPpPk...",
        "gk..kPPpPPpPk...",
        "....kPPPpPPk....",
        ".....kPkPkPk....",
        "......k.k.k.....",
        "................",
    ],
    "ghoul": [
        "................",
        "......kkkkk.....",
        ".....klllllk....",
        "....kllllllLk...",
        "....kekllekLk...",
        "....klllllllk...",
        "....klkwkwklk...",
        "...kkLlllllkk...",
        "..klkBBBBBBkLk..",
        ".kllkBbBBbBkLLk.",
        ".kl.kBBBBBBk.lk.",
        ".k..kBbBBbBk..k.",
        "....kLLkkLLk....",
        "....kLlk.kLlk...",
        "...kLLk..kLLk...",
        "...kkk...kkk....",
    ],
    "lich": [
        ".kk...y.y.y.....",
        "kcck..yyyyy.....",
        "kcwk.kkkkkkk....",
        ".kk..kwwwwwk....",
        ".kbk.kekwekk....",
        ".kbk.kwwwwwk....",
        ".kbk..kwkwk.....",
        ".kbkkkPPPPPkk...",
        ".kwkPPpPPPpPPk..",
        ".kbkPPpPPPpPPk..",
        ".kbk.kPpPPpPk...",
        ".kbk.kPpPPpPPk..",
        ".kbk.kPPpPPpPk..",
        ".kbk.kPPpPPpPPk.",
        ".kbkkPPPPPPPPPPk",
        "..k.kkkkkkkkkkk.",
    ],
}

# --------------------------------------------------------------------------
# Shop / UI icons (16x16)
# --------------------------------------------------------------------------
UI_ICONS = {
    "extra_spin": [
        "...........kkk..",
        "..........krrrk.",
        "..........krwrk.",
        "..........krrrk.",
        "...........kkk..",
        "...kkk.....kgk..",
        "...klk.....kgk..",
        ".kkklkkk...kgk..",
        ".klllllk...kgk..",
        ".kkklkkk...kgk..",
        "...klk.....kgk..",
        "...kkk..kkkkgkkk",
        "........kYYYYYYk",
        "........kYyyyyYk",
        "........kYYYYYYk",
        "........kkkkkkkk",
    ],
}


UPGRADE_ICONS = {
    "shard": [
        ".......kk.......",
        "......kwck......",
        ".....kwccck.....",
        "....kwcccnck....",
        "...kwccccnnck...",
        "..kwcccccnnnck..",
        "..kccccccnnnnk..",
        "..kcccccnnnnNk..",
        "..kcccccnnnnNk..",
        "..kccccnnnnNNk..",
        "...kcccnnnNNk...",
        "....kccnnNNk....",
        ".....kcnNNk.....",
        "......kNNk......",
        ".......kk.......",
        "................",
    ],
    "heart": [
        "................",
        "................",
        "...kkk...kkk....",
        "..krrrk.krrrk...",
        ".krwrrrkrrrrrk..",
        ".krwrrrrrrrrrk..",
        ".krrrrrrrrrrrk..",
        ".krrrrrrrrrrRk..",
        "..krrrrrrrrRk...",
        "...krrrrrrRk....",
        "....krrrrRk.....",
        ".....krrRk......",
        "......kRk.......",
        ".......k........",
        "................",
        "................",
    ],
    "rows": [
        "................",
        ".kkkkkkkkkkkkkk.",
        ".kYYYYYYYYYYYYk.",
        ".kYkkkkkkkkkkYk.",
        ".kYkwwkwwkwwkYk.",
        ".kYkkkkkkkkkkYk.",
        ".kYkwwkwwkwwkYk.",
        ".kYkkkkkkkkkkYk.",
        ".kYkwwkwwkwwkYk.",
        ".kYkkkkkkkkkkYk.",
        ".kYkllkllkllkYk.",
        ".kYkkkkkkkkkkYk.",
        ".kYYYYYYYYYYYYk.",
        ".kkkkkkkkkkkkkk.",
        "................",
        "................",
    ],
    "wall": [
        "................",
        ".kkkk.kkkk.kkkk.",
        ".kggk.kggk.kggk.",
        ".kggkkkggkkkggk.",
        ".kggggggggggggk.",
        ".kGGkGGGGkGGGGk.",
        ".kggkggggkggggk.",
        ".kkkkkkkkkkkkkk.",
        ".kggggkggggkggk.",
        ".kGGGGkGGGGkGGk.",
        ".kkkkkkkkkkkkkk.",
        ".kggkggggkggggk.",
        ".kGGkGGGGkGGGGk.",
        ".kkkkkkkkkkkkkk.",
        "................",
        "................",
    ],
    "bag": [
        "................",
        "......kkkk......",
        ".....kbBBbk.....",
        "......kYYk......",
        ".....kbbbbk.....",
        "....kbbbbbbk....",
        "...kbbbYYbbbk...",
        "..kbbbYyyYbbbk..",
        "..kbbbYyyYbbbk..",
        "..kbbbbYYbbbbk..",
        "..kbbbbbbbbbBk..",
        "...kbbbbbbbBk...",
        "....kkkkkkkk....",
        "................",
        "................",
        "................",
    ],
    "cart": [
        "................",
        "................",
        "...kkkkkkkkkk...",
        "..krrrrrrrrrrk..",
        "..kRrRrRrRrRrk..",
        "..kkkkkkkkkkkk..",
        "..kbbbbbbbbbbk..",
        "..kbYbbbbbbYbk..",
        "..kbbbbbbbbbbk..",
        "..kkkkkkkkkkkk..",
        "...kkk....kkk...",
        "..kGgGk..kGgGk..",
        "..kgkgk..kgkgk..",
        "..kGgGk..kGgGk..",
        "...kkk....kkk...",
        "................",
    ],
}


def bolts_icon() -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for offset in (0, 4):
        d.line([2 + offset, 13, 11 + offset, 4], fill=PALETTE["k"], width=3)
        d.line([2 + offset, 13, 11 + offset, 4], fill=PALETTE["b"], width=1)
        d.polygon([(10 + offset, 2), (14 + offset, 2), (13 + offset, 6)], fill=PALETTE["g"], outline=PALETTE["k"])
        img.putpixel((2 + offset, 13), PALETTE["r"])
        img.putpixel((3 + offset, 13), PALETTE["r"])
    return img


def watchtower() -> Image.Image:
    """Small stone watchtower for the field (16x32), origin at the bottom centre."""
    w, h = 16, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outline, stone, mortar = PALETTE["k"], rgba("#a8a8b6"), rgba("#74748a")
    d.rectangle([3, 12, 12, 31], fill=stone)
    for i, y in enumerate(range(15, 31, 4)):
        d.line([3, y, 12, y], fill=mortar)
        for x in range(3 + (2 if i % 2 else 0), 12, 4):
            d.line([x, y - 3, x, y - 1], fill=mortar)
    d.rectangle([3, 12, 12, 31], outline=outline)
    d.rectangle([1, 8, 14, 12], fill=rgba("#8a8a9a"), outline=outline)
    for x in (1, 6, 11):
        d.rectangle([x, 5, x + 2, 8], fill=rgba("#8a8a9a"), outline=outline)
    d.rectangle([7, 17, 8, 21], fill=rgba("#2a1a2a"))
    d.line([7, 0, 7, 5], fill=outline)
    d.polygon([(8, 0), (13, 1), (8, 3)], fill=PALETTE["n"])
    d.rectangle([6, 26, 9, 31], fill=PALETTE["B"], outline=outline)
    return img


def payline_icon() -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 1, 15, 14], fill=rgba("#e8d8b0"), outline=PALETTE["k"])
    rows = [0, 1, 2, 1, 0]
    points = [(2 + col * 3, 4 + row * 4) for col, row in enumerate(rows)]
    for col in range(5):
        for row in range(3):
            img.putpixel((2 + col * 3, 4 + row * 4), rgba("#a08868"))
    d.line(points, fill=PALETTE["r"], width=1)
    for p in points:
        img.putpixel(p, PALETTE["Y"])
    return img


def projectile_images() -> dict[str, Image.Image]:
    arrow = from_map("arrow", [
        "w......g.",
        "wbbbbbbgg",
        "w......g.",
    ], width=9)
    bolt = from_map("bolt", [
        "rr.......Y.",
        "kbbbbbbbbYY",
        "rr.......Y.",
    ], width=11)
    magic = from_map("magic_orb", [
        ".cccc.",
        "ccwwcc",
        "cwwwwc",
        "cwwwwc",
        "ccwwcc",
        ".cccc.",
    ], width=6)
    dark = from_map("dark_orb", [
        ".pppp.",
        "pPPPPp",
        "pPeePp",
        "pPeePp",
        "pPPPPp",
        ".pppp.",
    ], width=6)
    return {"arrow": arrow, "bolt": bolt, "magic_orb": magic, "dark_orb": dark}


# --------------------------------------------------------------------------
# Environment
# --------------------------------------------------------------------------
def castle() -> Image.Image:
    """Castle seen from the front (3/4 view): keep, curtain wall, two towers, gate facing south."""
    w, h = 120, 84
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outline = PALETTE["k"]
    stone = rgba("#9a9aa8")
    stone_light = rgba("#b4b4c2")
    stone_dark = rgba("#80808e")
    mortar = rgba("#6a6a7a")
    window = rgba("#f8d038")

    def bricks(x0: int, y0: int, x1: int, y1: int, base) -> None:
        d.rectangle([x0, y0, x1, y1], fill=base)
        for i, y in enumerate(range(y0 + 4, y1, 5)):
            d.line([x0, y, x1, y], fill=mortar)
            offset = 0 if i % 2 == 0 else 4
            for x in range(x0 + offset, x1, 8):
                d.line([x, y - 4, x, y - 1], fill=mortar)
        d.rectangle([x0, y0, x1, y1], outline=outline)

    def crenels(x0: int, x1: int, y: int, base) -> None:
        for x in range(x0, x1 - 2, 6):
            d.rectangle([x, y - 4, x + 3, y], fill=base, outline=outline)

    def lit_window(x: int, y: int) -> None:
        d.rectangle([x, y, x + 3, y + 5], fill=window, outline=outline)

    # Keep (behind the wall) with banner.
    crenels(37, 83, 16, stone_dark)
    bricks(36, 16, 83, 60, stone_dark)
    lit_window(46, 26)
    lit_window(58, 26)
    lit_window(70, 26)
    d.line([60, 0, 60, 12], fill=outline)
    d.polygon([(61, 0), (70, 2), (61, 5)], fill=PALETTE["n"], outline=outline)
    # Curtain wall.
    crenels(13, 107, 46, stone)
    bricks(12, 46, 107, 83, stone)
    # Front towers with roofs.
    for tx in (0, 100):
        bricks(tx, 30, tx + 19, 83, stone_light)
        d.polygon([(tx - 1, 30), (tx + 9, 10), (tx + 10, 10), (tx + 20, 30)], fill=PALETTE["r"], outline=outline)
        d.line([tx + 10, 12, tx + 17, 28], fill=PALETTE["R"])
        d.rectangle([tx + 8, 40, tx + 10, 46], fill=rgba("#2a1a2a"))
        lit_window(tx + 8, 58)
    # Gate.
    wood = PALETTE["B"]
    d.rectangle([50, 62, 69, 83], fill=wood)
    d.pieslice([50, 52, 69, 72], 180, 360, fill=wood)
    for x in range(52, 69, 3):
        d.line([x, 56, x, 83], fill=rgba("#2a1a10"))
    for y in range(64, 83, 5):
        d.line([50, y, 69, y], fill=rgba("#2a1a10"))
    d.arc([50, 52, 69, 72], 180, 360, fill=outline)
    d.line([50, 62, 50, 83], fill=outline)
    d.line([69, 62, 69, 83], fill=outline)
    # Torches beside the gate.
    for x in (44, 74):
        d.rectangle([x, 62, x + 1, 66], fill=PALETTE["B"])
        d.rectangle([x, 59, x + 1, 61], fill=PALETTE["o"])
        img.putpixel((x, 58), PALETTE["y"])
    return img


def _value_noise(w: int, h: int, cell: int, seed: int) -> list:
    """Smooth random field in 0..1, used for grass patches."""
    r = random.Random(seed)
    gw, gh = w // cell + 2, h // cell + 2
    grid = [[r.random() for _ in range(gw)] for _ in range(gh)]
    field = [[0.0] * w for _ in range(h)]
    for y in range(h):
        gy, fy = int(y / cell), (y / cell) % 1
        fy = fy * fy * (3 - 2 * fy)
        for x in range(w):
            gx, fx = int(x / cell), (x / cell) % 1
            fx = fx * fx * (3 - 2 * fx)
            top = grid[gy][gx] * (1 - fx) + grid[gy][gx + 1] * fx
            bottom = grid[gy + 1][gx] * (1 - fx) + grid[gy + 1][gx + 1] * fx
            field[y][x] = top * (1 - fy) + bottom * fy
    return field


def background() -> Image.Image:
    """Top-down battlefield ground: grass, the castle courtyard and the forest behind the castle.

    Graveyards, trails and terrain (rivers, mountains...) differ per castle and are
    drawn by the game from the castle's BattleLayout (src/battle/layout_view.gd)."""
    w, h = 640, 360
    castle_x, castle_bottom = 320, 104
    rng = random.Random(11)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    px = img.load()
    d = ImageDraw.Draw(img)

    grass = [rgba("#4c9a40"), rgba("#58a848"), rgba("#64b450")]
    patches = _value_noise(w, h, 24, 5)
    for y in range(h):
        for x in range(w):
            v = patches[y][x] + rng.uniform(-0.08, 0.08)
            shade = 0 if v < 0.38 else 1 if v < 0.66 else 2
            px[x, y] = grass[shade]

    # Castle courtyard.
    dirt = rgba("#9a7a4c")
    d.ellipse([castle_x - 92, castle_bottom - 24, castle_x + 92, castle_bottom + 18], fill=dirt)

    # Details: tufts, flowers and rocks (not on the courtyard).
    def free(x: int, y: int) -> bool:
        return not (abs(x - castle_x) < 100 and y < castle_bottom + 22)

    for _ in range(620):
        x, y = rng.randrange(4, w - 4), rng.randrange(30, h - 4)
        if not free(x, y):
            continue
        kind = rng.random()
        if kind < 0.55:
            px[x, y] = rgba("#3c8034")
            px[x + 1, y - 1] = rgba("#3c8034")
            px[x - 1, y - 1] = rgba("#3c8034")
        elif kind < 0.85:
            px[x, y] = rng.choice([rgba("#f8f0a0"), rgba("#f4f4f4"), rgba("#f06080"), rgba("#a0b0ff")])
        else:
            d.rectangle([x, y, x + 2, y + 1], fill=rgba("#8a8a96"))
            px[x, y] = rgba("#b4b4c0")

    # Dense forest along the top, behind the castle.
    forest = [(x, rng.randint(-6, 14)) for x in range(-10, w + 10, 13)]
    for cx, cy in sorted(forest, key=lambda p: p[1]):
        _draw_tree(d, cx, cy, rng.randint(9, 13))
    return img


def _draw_tree(d: ImageDraw.ImageDraw, cx: int, cy: int, r: int) -> None:
    d.rectangle([cx - 1, cy + r - 2, cx + 1, cy + r + 3], fill=PALETTE["B"])
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba("#2c6830"), outline=PALETTE["k"])
    d.ellipse([cx - r + 2, cy - r + 1, cx + r - 3, cy + r - 4], fill=rgba("#3c8038"))
    d.ellipse([cx - r + 3, cy - r + 2, cx - 1, cy - 1], fill=rgba("#58a048"))


# --------------------------------------------------------------------------
# Battlefield terrain (tiles fill the layout shapes, props are scattered on them)
# --------------------------------------------------------------------------
def _seamless_tile(size: int, base: str, blobs: list, seed: int) -> Image.Image:
    """Tile filled with `base` plus wrapped random blobs: (colour, count, min_r, max_r)."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (size, size), rgba(base))
    d = ImageDraw.Draw(img)
    for color, count, r_min, r_max in blobs:
        for _ in range(count):
            cx, cy, r = rng.randrange(size), rng.randrange(size), rng.randint(r_min, r_max)
            for ox in (-size, 0, size):
                for oy in (-size, 0, size):
                    d.ellipse([cx + ox - r, cy + oy - r * 0.7, cx + ox + r, cy + oy + r * 0.7], fill=rgba(color))
    return img


def _wrapped_line(d: ImageDraw.ImageDraw, size: int, points: list, color, width: int = 1) -> None:
    for ox in (-size, 0, size):
        for oy in (-size, 0, size):
            d.line([(x + ox, y + oy) for x, y in points], fill=color, width=width)


def rock_tile() -> Image.Image:
    size = 32
    img = _seamless_tile(size, "#7a7684", [("#686474", 9, 3, 6), ("#8c8898", 7, 2, 4), ("#9c98a8", 4, 1, 2)], 31)
    d = ImageDraw.Draw(img)
    rng = random.Random(32)
    for _ in range(5):
        x, y = rng.randrange(size), rng.randrange(size)
        pts = [(x, y)]
        for _ in range(3):
            x += rng.randint(1, 4)
            y += rng.randint(-2, 2)
            pts.append((x, y))
        _wrapped_line(d, size, pts, rgba("#4a4656"))
    return img


def water_tile() -> Image.Image:
    size = 32
    img = _seamless_tile(size, "#3a72c8", [("#2e60b0", 8, 3, 7), ("#4682d4", 5, 2, 4)], 41)
    d = ImageDraw.Draw(img)
    rng = random.Random(42)
    for _ in range(7):
        x, y, length = rng.randrange(size), rng.randrange(size), rng.randint(2, 5)
        _wrapped_line(d, size, [(x, y), (x + length, y)], rgba("#7aaae8"))
        if rng.random() < 0.4:
            _wrapped_line(d, size, [(x + 1, y), (x + 2, y)], rgba("#b4d8f8"))
    return img


def lava_tile() -> Image.Image:
    size = 32
    img = _seamless_tile(size, "#c8400c", [("#e86818", 9, 3, 6), ("#f8a830", 6, 1, 3), ("#fce070", 3, 1, 1)], 51)
    d = ImageDraw.Draw(img)
    rng = random.Random(52)
    for _ in range(6):
        x, y = rng.randrange(size), rng.randrange(size)
        pts = [(x, y)]
        for _ in range(3):
            x += rng.randint(-3, 3)
            y += rng.randint(1, 3)
            pts.append((x, y))
        _wrapped_line(d, size, pts, rgba("#6a1c0c"))
    return img


def ruin_tile() -> Image.Image:
    """Grey stone blocks in staggered rows (walls and crypts)."""
    size = 32
    img = Image.new("RGBA", (size, size), rgba("#4a4652"))
    d = ImageDraw.Draw(img)
    rng = random.Random(61)
    for row in range(size // 8):
        y = row * 8
        shift = 0 if row % 2 == 0 else 5
        for col in range(-1, size // 10 + 1):
            x = col * 10 + shift
            face = rng.choice(["#8a8494", "#7c7686", "#948ea0"])
            for ox in (-size, 0, size):
                d.rectangle([x + ox, y, x + ox + 8, y + 6], fill=rgba(face))
                d.line([x + ox, y, x + ox + 8, y], fill=rgba("#aca6b8"))
    return img


def plank_tile() -> Image.Image:
    """Bridge planks: one 4 px plank per row, running across the texture."""
    size = 16
    img = Image.new("RGBA", (size, size), rgba("#3a2410"))
    d = ImageDraw.Draw(img)
    for i, color in enumerate(["#9a6a34", "#8a5c2c", "#a4743c", "#94642e"]):
        y = i * 4
        d.rectangle([0, y, size - 1, y + 2], fill=rgba(color))
        d.point([(3 + i * 3) % size, y + 1], fill=rgba("#5a3418"))
    return img


def peak(w: int, h: int, seed: int) -> Image.Image:
    """A rocky peak with a lit west face, a shaded east face and a snow cap."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top = (w // 2 + rng.randint(-2, 2), 1)
    left, right = (1, h - 1), (w - 2, h - 1)
    mid = (top[0] + rng.randint(-1, 1), h - 1)
    d.polygon([top, left, mid], fill=rgba("#9894a4"))
    d.polygon([top, mid, right], fill=rgba("#625e70"))
    snow_y = 1 + h // 4
    t = (snow_y - 1) / (h - 2)
    d.polygon([top, (top[0] + (left[0] - top[0]) * t, snow_y), (top[0] + 1, snow_y + 1),
               (top[0] + (right[0] - top[0]) * t, snow_y)], fill=rgba("#eeeef6"))
    d.line([top, left], fill=PALETTE["k"])
    d.line([top, right], fill=PALETTE["k"])
    d.line([left, right], fill=PALETTE["k"])
    for _ in range(2):
        x = rng.randint(w // 4, w * 3 // 4)
        y = rng.randint(h // 2, h - 4)
        d.line([(x, y), (x + rng.randint(-2, 2), y + 3)], fill=rgba("#4a4656"))
    return img


def boulder() -> Image.Image:
    img = Image.new("RGBA", (10, 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 1, 9, 7], fill=rgba("#7a7684"), outline=PALETTE["k"])
    d.ellipse([2, 2, 5, 4], fill=rgba("#a4a0b0"))
    return img


def terrain_tree() -> Image.Image:
    img = Image.new("RGBA", (20, 24), (0, 0, 0, 0))
    _draw_tree(ImageDraw.Draw(img), 10, 9, 8)
    return img


def reeds() -> Image.Image:
    img = Image.new("RGBA", (7, 9), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x, top in ((1, 2), (3, 0), (5, 3)):
        d.line([(x, top), (x, 8)], fill=rgba("#3c7a34"))
    d.point([(3, 0), (3, 1)], fill=rgba("#7a4a20"))
    d.point([(1, 2)], fill=rgba("#7a4a20"))
    return img


def dead_tree() -> Image.Image:
    img = Image.new("RGBA", (13, 17), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    branch = rgba("#3a2a28")
    d.line([(6, 16), (6, 5)], fill=branch, width=2)
    d.line([(6, 9), (1, 3)], fill=branch)
    d.line([(6, 7), (11, 1)], fill=branch)
    d.line([(3, 5), (1, 6)], fill=branch)
    return img


def ember_rock() -> Image.Image:
    img = Image.new("RGBA", (9, 7), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 1, 8, 6], fill=rgba("#3a2a2a"), outline=PALETTE["k"])
    d.line([(2, 4), (4, 3), (6, 4)], fill=rgba("#f88828"))
    return img


TERRAIN_ART = {
    "rock_tile": rock_tile,
    "water_tile": water_tile,
    "lava_tile": lava_tile,
    "ruin_tile": ruin_tile,
    "plank_tile": plank_tile,
    "peak_large": lambda: peak(28, 24, 71),
    "peak_small": lambda: peak(18, 15, 72),
    "boulder": boulder,
    "tree": terrain_tree,
    "reeds": reeds,
    "dead_tree": dead_tree,
    "ember_rock": ember_rock,
}


# --------------------------------------------------------------------------
# Variants: new troops and spirits made by recolouring / editing base maps
# --------------------------------------------------------------------------
def recolor(rows: list[str], mapping: dict[str, str]) -> list[str]:
    return ["".join(mapping.get(ch, ch) for ch in row) for row in rows]


def set_pixel(rows: list[str], x: int, y: int, ch: str) -> None:
    rows[y] = rows[y][:x] + ch + rows[y][x + 1:]


def pikeman_rows() -> list[str]:
    rows = recolor(UNITS["swordsman"], {"n": "o", "N": "R"})
    rows[0] = "............kgk."
    rows[1] = rows[1][:12] + "kgk."
    for y in range(2, 13):
        if rows[y][13] in ".wkY":
            set_pixel(rows, 13, y, "b")
    rows[7] = rows[7][:12] + "kbk" + rows[7][15:]
    return rows


TROOP_VARIANTS = {
    "pikeman": pikeman_rows,
    "crossbowman": lambda: recolor(UNITS["archer"], {"l": "r", "L": "R", "b": "G"}),
    "cleric": lambda: recolor(UNITS["mage"], {"p": "w", "P": "g", "c": "y"}),
}

ENEMY_VARIANTS = {
    "banshee": lambda: recolor(ENEMIES["ghost"], {"m": "p", "M": "P", "e": "c"}),
    "bone_knight": lambda: recolor(ENEMIES["ghoul"], {"l": "w", "L": "g", "B": "N", "b": "n", "e": "r"}),
    "frost_king": lambda: recolor(ENEMIES["lich"], {"P": "N", "p": "n", "c": "w", "y": "c", "e": "c"}),
    "imp": lambda: recolor(ENEMIES["wraith"], {"P": "R", "p": "r", "g": "y", "e": "y"}),
    "demon": lambda: recolor(ENEMIES["ghoul"], {"l": "r", "L": "R", "B": "k", "b": "B", "e": "y", "w": "y"}),
    "demon_lord": lambda: recolor(ENEMIES["lich"], {"P": "R", "p": "r", "w": "o", "c": "y", "y": "o", "e": "y"}),
    "rune_warden": lambda: recolor(ENEMIES["ghoul"], {"l": "c", "L": "n", "B": "G", "b": "c", "e": "w", "w": "c"}),
    "dread_howler": lambda: recolor(ENEMIES["ghost"], {"m": "r", "M": "R", "e": "y"}),
    "shade_assassin": lambda: recolor(ENEMIES["wraith"], {"P": "G", "p": "k", "g": "r", "e": "r"}),
}

HOLY_SYMBOL = [
    "................",
    "......kkkk......",
    "......kwyk......",
    "......kyyk......",
    "...kkkkyykkkk...",
    "...kwyyyyyyyk...",
    "...kyyyyyyyYk...",
    "...kkkkyykkkk...",
    "......kyyk......",
    "......kyyk......",
    "......kyYk......",
    "......kyYk......",
    "......kYYk......",
    "......kYYk......",
    "......kkkk......",
    "................",
]


def pike_symbol() -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line([1, 15, 11, 5], fill=PALETTE["k"], width=3)
    d.line([1, 15, 11, 5], fill=PALETTE["b"], width=1)
    d.polygon([(9, 4), (15, 0), (12, 7)], fill=PALETTE["g"], outline=PALETTE["k"])
    img.putpixel((13, 2), PALETTE["w"])
    d.line([7, 7, 10, 10], fill=PALETTE["o"])
    return img


def crossbow_symbol() -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([7, 3, 8, 15], fill=PALETTE["b"], outline=PALETTE["k"])
    d.arc([1, 2, 14, 12], 200, 340, fill=PALETTE["k"], width=3)
    d.arc([1, 2, 14, 12], 200, 340, fill=PALETTE["G"], width=1)
    d.line([2, 6, 7, 9], fill=PALETTE["w"])
    d.line([13, 6, 8, 9], fill=PALETTE["w"])
    d.polygon([(6, 0), (9, 0), (7, 2)], fill=PALETTE["g"], outline=PALETTE["k"])
    return img


def fire_orb() -> Image.Image:
    return from_map("fire_orb", [
        ".oooo.",
        "orrrro",
        "oryyro",
        "oryyro",
        "orrrro",
        ".oooo.",
    ], width=6)


TOMBSTONE_SYMBOL = [
    "................",
    ".....kkkkkk.....",
    "....kggggggk....",
    "...kgwgggggGk...",
    "...kgggkgggGk...",
    "...kggkkkggGk...",
    "...kgggkgggGk...",
    "...kgggkgggGk...",
    "...kgkgggegGk...",
    "...kgekggkgGk...",
    "...kgggkgggGk...",
    "...kGGGGGGGGk...",
    "..kkkkkkkkkkkk..",
    ".kLlLLlLLlLLlLk.",
    ".kkkkkkkkkkkkkk.",
    "................",
]


def cursed_coin() -> Image.Image:
    """A Gold Coin gone bad: tarnished purple-gold with a glowing red eye."""
    rows = recolor(SYMBOLS["coin"], {"y": "p", "Y": "P", "w": "c"})
    img = from_map("cursed_coin", rows)
    for x, y in [(7, 7), (8, 7), (7, 8), (8, 8)]:
        img.putpixel((x, y), PALETTE["e"])
    for x, y in [(6, 6), (9, 6), (6, 9), (9, 9)]:
        img.putpixel((x, y), PALETTE["y"])
    return img


BOULDER = [
    ".kkk.",
    "kGgGk",
    "kgGGk",
    "kGGGk",
    ".kkk.",
]


def empty_slot() -> Image.Image:
    """A blank reel slot: dark recess with a dashed outline (pays nothing)."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    dark = (40, 32, 44, 255)
    dash = (110, 96, 110, 255)
    for y in range(2, 14):
        for x in range(2, 14):
            img.putpixel((x, y), dark)
    for i in range(2, 14):
        if i % 3 != 1:
            for x, y in [(i, 2), (i, 13), (2, i), (13, i)]:
                img.putpixel((x, y), dash)
    return img


def purple_tombstone() -> Image.Image:
    """The Tombstone recoloured in cursed purple (worth double the curse)."""
    img = from_map("tombstone", TOMBSTONE_SYMBOL)
    stone = {"g": (150, 70, 190, 255), "G": (95, 40, 130, 255), "w": (230, 180, 255, 255),
             "e": (255, 90, 220, 255), "L": (70, 45, 85, 255), "l": (110, 70, 130, 255)}
    for y, row in enumerate(TOMBSTONE_SYMBOL):
        for x, ch in enumerate(row):
            if ch in stone:
                img.putpixel((x, y), stone[ch])
    return img


def mage_tower() -> Image.Image:
    """Watchtower with a purple spire and a glowing orb (16x34)."""
    base = watchtower()
    img = Image.new("RGBA", (16, 34), (0, 0, 0, 0))
    img.alpha_composite(base.crop((0, 8, 16, 32)), (0, 10))
    d = ImageDraw.Draw(img)
    d.polygon([(1, 11), (8, 1), (14, 11)], fill=PALETTE["p"], outline=PALETTE["k"])
    d.line([8, 3, 12, 10], fill=PALETTE["P"])
    d.ellipse([5, -1, 10, 4], fill=PALETTE["c"], outline=PALETTE["k"])
    img.putpixel((7, 0), PALETTE["w"])
    d.rectangle([7, 18, 8, 22], fill=PALETTE["c"])
    return img


def ballista_tower() -> Image.Image:
    """Wooden siege platform with a big crossbow on top (20x32)."""
    w, h = 20, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outline, wood, dark = PALETTE["k"], PALETTE["b"], PALETTE["B"]
    for x in (3, 15):
        d.rectangle([x, 14, x + 2, 31], fill=wood, outline=outline)
    d.line([4, 30, 16, 16], fill=dark, width=2)
    d.line([16, 30, 4, 16], fill=dark, width=2)
    d.rectangle([1, 11, 18, 14], fill=wood, outline=outline)
    d.rectangle([8, 5, 11, 11], fill=dark, outline=outline)
    d.arc([0, 1, 19, 12], 200, 340, fill=outline, width=3)
    d.arc([0, 1, 19, 12], 200, 340, fill=PALETTE["G"], width=1)
    d.line([2, 5, 9, 8], fill=PALETTE["w"])
    d.line([17, 5, 10, 8], fill=PALETTE["w"])
    d.polygon([(8, 0), (11, 0), (9, 3)], fill=PALETTE["g"], outline=outline)
    return img


def _wild_frame(d: ImageDraw.ImageDraw, color) -> None:
    """Rounded gem-like backdrop so every wild reads as 'special'."""
    d.rounded_rectangle([0, 0, 15, 15], radius=4, fill=color, outline=PALETTE["k"])


def quiver_symbol() -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _wild_frame(d, rgba("#3a6a40"))
    for x, top in ((5, 1), (8, 2), (11, 1)):
        d.line([x, top + 3, x, 9], fill=PALETTE["b"])
        d.polygon([(x - 1, top + 2), (x + 1, top + 2), (x, top)], fill=PALETTE["g"])
    d.rectangle([3, 7, 12, 14], fill=PALETTE["B"], outline=PALETTE["k"])
    d.line([4, 10, 11, 10], fill=PALETTE["Y"])
    img.putpixel((7, 12), PALETTE["y"])
    return img


def banner_symbol() -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _wild_frame(d, rgba("#5a3a6a"))
    d.line([3, 1, 3, 15], fill=PALETTE["b"], width=2)
    d.polygon([(4, 2), (14, 2), (14, 10), (9, 8), (4, 10)], fill=PALETTE["r"], outline=PALETTE["k"])
    d.line([6, 4, 11, 4], fill=PALETTE["y"])
    d.line([8, 3, 8, 7], fill=PALETTE["y"])
    img.putpixel((3, 0), PALETTE["y"])
    return img


def sigil_symbol() -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _wild_frame(d, rgba("#2a2a5a"))
    d.ellipse([2, 2, 13, 13], outline=PALETTE["c"])
    star = [(8, 3), (9, 7), (13, 8), (9, 9), (8, 13), (7, 9), (3, 8), (7, 7)]
    d.polygon(star, fill=PALETTE["p"], outline=PALETTE["c"])
    img.putpixel((8, 8), PALETTE["w"])
    return img


# --------------------------------------------------------------------------
# Machine styles: feature symbols and machine icons (see data/machines/)
# --------------------------------------------------------------------------
def jester_symbol() -> Image.Image:
    """Jester's 81 wild: a grinning jester with a red and gold hat."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _wild_frame(d, rgba("#5a1020"))
    d.polygon([(2, 8), (4, 2), (8, 6)], fill=PALETTE["r"], outline=PALETTE["k"])
    d.polygon([(14, 8), (12, 2), (8, 6)], fill=PALETTE["y"], outline=PALETTE["k"])
    for x, y in ((4, 1), (12, 1)):
        d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=PALETTE["y"], outline=PALETTE["k"])
    d.ellipse([4, 6, 12, 14], fill=PALETTE["s"], outline=PALETTE["k"])
    img.putpixel((6, 9), PALETTE["k"])
    img.putpixel((10, 9), PALETTE["k"])
    d.arc([5, 9, 11, 13], 20, 160, fill=PALETTE["R"])
    return img


def crown_symbol() -> Image.Image:
    """Old Cellar's x2 wild: a gold crown on a royal blue gem."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _wild_frame(d, rgba("#203878"))
    d.polygon([(2, 12), (2, 5), (5, 9), (8, 3), (11, 9), (14, 5), (14, 12)], fill=PALETTE["y"], outline=PALETTE["k"])
    d.line([3, 11, 13, 11], fill=PALETTE["Y"])
    for x in (5, 8, 11):
        img.putpixel((x, 10), PALETTE["r"])
    img.putpixel((8, 3), PALETTE["w"])
    return img


def tome_symbol() -> Image.Image:
    """Tome of Ages wild + scatter: an open glowing book."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _wild_frame(d, rgba("#3a2410"))
    d.ellipse([3, 1, 13, 9], fill=rgba("#f8e080"))
    d.polygon([(1, 5), (8, 7), (8, 14), (1, 12)], fill=rgba("#f0e0b8"), outline=PALETTE["k"])
    d.polygon([(15, 5), (8, 7), (8, 14), (15, 12)], fill=rgba("#e4d0a0"), outline=PALETTE["k"])
    for y in (8, 10):
        d.line([3, y, 6, y + 1], fill=PALETTE["B"])
        d.line([10, y + 1, 13, y], fill=PALETTE["B"])
    d.line([8, 7, 8, 14], fill=PALETTE["Y"])
    return img


def chest_symbol() -> Image.Image:
    """Dragon's Hoard bonus: a treasure chest spilling gold."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 7, 14, 14], fill=PALETTE["b"], outline=PALETTE["k"])
    d.pieslice([1, 1, 14, 13], 180, 360, fill=PALETTE["B"], outline=PALETTE["k"])
    d.line([1, 7, 14, 7], fill=PALETTE["k"])
    d.rectangle([1, 9, 14, 10], fill=PALETTE["Y"])
    d.rectangle([6, 7, 9, 11], fill=PALETTE["y"], outline=PALETTE["k"])
    img.putpixel((7, 9), PALETTE["k"])
    for x, y in ((3, 6), (5, 5), (11, 5), (12, 6)):
        img.putpixel((x, y), PALETTE["y"])
    return img


def slot_machine_icon() -> Image.Image:
    """The standard machine: a little cabinet with three reels and a lever."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, 12, 15], radius=2, fill=PALETTE["r"], outline=PALETTE["k"])
    d.rectangle([3, 4, 10, 9], fill=rgba("#e8d8b0"), outline=PALETTE["k"])
    d.line([5, 4, 5, 9], fill=PALETTE["k"])
    d.line([8, 4, 8, 9], fill=PALETTE["k"])
    for x in (4, 6, 9):
        img.putpixel((x, 6), PALETTE["y"])
    d.rectangle([3, 11, 10, 13], fill=PALETTE["Y"], outline=PALETTE["k"])
    d.line([14, 3, 14, 10], fill=PALETTE["g"])
    d.ellipse([13, 1, 15, 3], fill=PALETTE["r"], outline=PALETTE["k"])
    return img


def halls_icon() -> Image.Image:
    """Shifting Halls: a stone arch with uneven glowing columns."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _wild_frame(d, rgba("#1c1c28"))
    for i, top in enumerate((9, 5, 7, 4)):
        x = 2 + i * 3
        d.rectangle([x, top, x + 2, 14], fill=rgba("#a8a8b6"))
        d.line([x, top, x + 2, top], fill=PALETTE["c"])
    d.arc([1, 0, 14, 8], 180, 360, fill=PALETTE["c"])
    return img


# --------------------------------------------------------------------------
# Machine skins: cabinet art for each machine style (src/slot_machine/machine_skin.gd)
# Every skin has: frame (32x32 nine-patch, 8 px margins), reel (16x16 tile
# behind the symbols), marquee (48x20 three-slice, 14 px caps), crest (the
# ornament on top of the marquee) and wing (24x24 nine-patch, 6 px margins,
# the side panels that show feature counters).
# --------------------------------------------------------------------------
SKIN_COLORS = {
    "standard": {"body": "#6a3c1c", "dark": "#3a2010", "light": "#9a6a34", "trim": "#c08820",
                 "shine": "#f8d038", "reel": "#e8d8b0", "mark": "#dccaa0", "plate": "#2a1408"},
    "old_cellar": {"body": "#7a828c", "dark": "#40464e", "light": "#c8ced6", "trim": "#a0a8b0",
                   "shine": "#f4f4f4", "reel": "#f0f0e8", "mark": "#dedcd2", "plate": "#141418"},
    "jester_81": {"body": "#a02030", "dark": "#5a1020", "light": "#d84850", "trim": "#e0b030",
                  "shine": "#f8e070", "reel": "#f2e2c4", "mark": "#e6d0aa", "plate": "#3a0814"},
    "dragons_hoard": {"body": "#1e6a40", "dark": "#0c3020", "light": "#40b070", "trim": "#d8a830",
                      "shine": "#f8d038", "reel": "#e2eedc", "mark": "#cee0c4", "plate": "#08200f"},
    "tome_of_ages": {"body": "#6a3418", "dark": "#381808", "light": "#8c4c24", "trim": "#c09040",
                     "shine": "#f8e0a0", "reel": "#f2e6c8", "mark": "#e0cfa8", "plate": "#f0e0b8"},
    "shifting_halls": {"body": "#5c5c6e", "dark": "#30303e", "light": "#8a8aa0", "trim": "#40d8f0",
                       "shine": "#c0f8ff", "reel": "#dcdce8", "mark": "#c6c6d6", "plate": "#22222e"},
}


def _skin(name: str) -> dict:
    return {key: rgba(value) for key, value in SKIN_COLORS[name].items()}


def _bevel_box(d: ImageDraw.ImageDraw, box: list, c: dict) -> None:
    """Outlined box with a light top-left and dark bottom-right bevel."""
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=c["body"], outline=PALETTE["k"])
    d.line([x0 + 1, y0 + 1, x1 - 1, y0 + 1], fill=c["light"])
    d.line([x0 + 1, y0 + 1, x0 + 1, y1 - 1], fill=c["light"])
    d.line([x0 + 1, y1 - 1, x1 - 1, y1 - 1], fill=c["dark"])
    d.line([x1 - 1, y0 + 1, x1 - 1, y1 - 1], fill=c["dark"])


def skin_frame(name: str) -> Image.Image:
    c = _skin(name)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _bevel_box(d, [0, 0, 31, 31], c)
    # Inner lip around the reel window.
    d.rectangle([6, 6, 25, 25], outline=c["dark"])
    d.rectangle([7, 7, 24, 24], outline=PALETTE["k"])
    corners = ((3, 3), (28, 3), (3, 28), (28, 28))
    if name == "standard":
        d.rectangle([3, 3, 28, 28], outline=c["trim"])
        for x, y in corners:
            d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=c["shine"], outline=PALETTE["k"])
    elif name == "old_cellar":
        d.line([2, 4, 29, 4], fill=c["light"])
        d.line([2, 27, 29, 27], fill=c["dark"])
        for x, y in corners:
            d.ellipse([x - 2, y - 2, x + 1, y + 1], fill=c["light"], outline=c["dark"])
            img.putpixel((x - 1, y - 1), c["shine"])
    elif name == "jester_81":
        d.rectangle([2, 2, 29, 29], outline=c["dark"])
        d.rectangle([4, 4, 27, 27], outline=c["trim"])
        for x, y in corners:
            d.polygon([(x, y - 3), (x + 3, y), (x, y + 3), (x - 3, y)], fill=c["trim"], outline=PALETTE["k"])
            img.putpixel((x, y), c["shine"])
    elif name == "dragons_hoard":
        d.rectangle([3, 3, 28, 28], outline=c["trim"])
        d.rectangle([4, 4, 27, 27], outline=c["dark"])
        for x, y in corners:
            d.polygon([(x, y - 3), (x + 3, y), (x, y + 3), (x - 3, y)], fill=rgba("#30c070"), outline=c["trim"])
            img.putpixel((x - 1, y - 1), PALETTE["w"])
    elif name == "tome_of_ages":
        d.rectangle([3, 3, 28, 28], outline=c["dark"])
        # Gold book corners.
        for sx, sy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            x0 = 1 if sx == 0 else 23
            y0 = 1 if sy == 0 else 23
            cx = x0 if sx == 0 else x0 + 7
            cy = y0 if sy == 0 else y0 + 7
            d.polygon([(cx, cy), (cx + (7 if sx == 0 else -7), cy), (cx, cy + (7 if sy == 0 else -7))],
                      fill=c["trim"], outline=PALETTE["k"])
            img.putpixel((cx + (2 if sx == 0 else -2), cy + (2 if sy == 0 else -2)), c["shine"])
    elif name == "shifting_halls":
        # Stone blocks in the corners, a glowing rune line around the window.
        for x, y in ((1, 1), (24, 1), (1, 24), (24, 24)):
            d.rectangle([x, y, x + 6, y + 6], fill=c["light"], outline=c["dark"])
        d.rectangle([5, 5, 26, 26], outline=c["trim"])
        for x, y in corners:
            img.putpixel((x + 1, y), c["trim"])
            img.putpixel((x, y + 1), c["trim"])
    return img


def skin_reel(name: str) -> Image.Image:
    c = _skin(name)
    img = Image.new("RGBA", (16, 16), c["reel"])
    d = ImageDraw.Draw(img)
    mark = c["mark"]
    if name == "standard":
        for x, y in ((3, 4), (11, 12), (12, 3), (5, 13)):
            img.putpixel((x, y), mark)
    elif name == "old_cellar":
        for y in range(0, 16, 4):
            d.line([0, y, 15, y], fill=mark)
    elif name == "jester_81":
        d.line([0, 8, 8, 0], fill=mark)
        d.line([8, 0, 15, 7], fill=mark)
        d.line([15, 8, 8, 15], fill=mark)
        d.line([8, 15, 0, 8], fill=mark)
    elif name == "dragons_hoard":
        for ox, oy in ((0, 0), (8, 8), (-8, 8), (16, 0)):
            d.arc([ox - 4, oy - 4, ox + 4, oy + 4], 0, 180, fill=mark)
        d.arc([4, 4, 12, 12], 0, 180, fill=mark)
        d.arc([-4, 12, 4, 20], 0, 180, fill=mark)
        d.arc([12, 12, 20, 20], 0, 180, fill=mark)
    elif name == "tome_of_ages":
        d.line([0, 6, 15, 6], fill=mark)
        d.line([0, 14, 15, 14], fill=mark)
        for x, y in ((3, 2), (12, 10), (7, 11)):
            img.putpixel((x, y), mark)
    elif name == "shifting_halls":
        d.line([0, 0, 15, 0], fill=mark)
        d.line([0, 8, 15, 8], fill=mark)
        d.line([0, 0, 0, 7], fill=mark)
        d.line([8, 8, 8, 15], fill=mark)
    return img


def skin_marquee(name: str) -> Image.Image:
    c = _skin(name)
    img = Image.new("RGBA", (48, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if name == "tome_of_ages":
        # A parchment scroll with rolled ends.
        d.rectangle([4, 3, 43, 16], fill=c["plate"], outline=PALETTE["k"])
        d.line([5, 4, 42, 4], fill=rgba("#fff4d8"))
        d.line([5, 15, 42, 15], fill=rgba("#d8c49c"))
        for x in (0, 40):
            d.rounded_rectangle([x, 1, x + 7, 18], radius=3, fill=c["light"], outline=PALETTE["k"])
            d.line([x + 2, 3, x + 2, 16], fill=rgba("#b07040"))
            d.line([x + 5, 3, x + 5, 16], fill=c["dark"])
        return img
    _bevel_box(d, [0, 1, 47, 18], c)
    d.rectangle([3, 4, 44, 15], fill=c["plate"], outline=PALETTE["k"])
    if name == "standard":
        d.rectangle([2, 3, 45, 16], outline=c["trim"])
    elif name == "old_cellar":
        d.line([4, 5, 43, 5], fill=rgba("#2a2a32"))
    elif name == "jester_81":
        d.rectangle([2, 3, 45, 16], outline=c["trim"])
        for x in (1, 46):
            d.polygon([(x, 4), (x + (4 if x < 10 else -4), 9), (x, 14)], fill=c["trim"], outline=PALETTE["k"])
    elif name == "dragons_hoard":
        d.rectangle([2, 3, 45, 16], outline=c["trim"])
        for x in (5, 42):
            img.putpixel((x, 9), c["shine"])
            img.putpixel((x, 10), c["shine"])
    elif name == "shifting_halls":
        d.line([4, 14, 43, 14], fill=c["trim"])
        for x in (8, 39):
            d.line([x, 2, x, 17], fill=c["dark"])
    return img


def skin_wing(name: str) -> Image.Image:
    c = _skin(name)
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if name == "tome_of_ages":
        d.rectangle([0, 0, 23, 23], fill=c["plate"], outline=PALETTE["k"])
        d.rectangle([1, 1, 22, 22], outline=c["trim"])
        d.line([2, 21, 21, 21], fill=rgba("#d8c49c"))
        return img
    _bevel_box(d, [0, 0, 23, 23], c)
    d.rectangle([3, 3, 20, 20], fill=c["plate"], outline=PALETTE["k"])
    if name in ("standard", "jester_81", "dragons_hoard"):
        d.rectangle([2, 2, 21, 21], outline=c["trim"])
    elif name == "shifting_halls":
        d.rectangle([4, 4, 19, 19], outline=rgba("#205868"))
    return img


def coin_crest() -> Image.Image:
    img = from_map("coin", SYMBOLS["coin"])
    return img


def cellar_crest() -> Image.Image:
    """Old Cellar: a red siren lamp on a steel base (lights up on wins)."""
    img = Image.new("RGBA", (16, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.pieslice([2, 0, 13, 13], 180, 360, fill=rgba("#a01828"), outline=PALETTE["k"])
    d.arc([4, 2, 9, 7], 190, 260, fill=rgba("#ff8080"))
    d.rectangle([1, 7, 14, 11], fill=rgba("#a0a8b0"), outline=PALETTE["k"])
    d.line([2, 8, 13, 8], fill=rgba("#e0e4e8"))
    return img


def jester_crest() -> Image.Image:
    """Jester's 81: a three-pointed jester hat with bells."""
    img = Image.new("RGBA", (28, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(6, 15), (1, 3), (11, 10)], fill=PALETTE["r"], outline=PALETTE["k"])
    d.polygon([(22, 15), (27, 3), (17, 10)], fill=PALETTE["r"], outline=PALETTE["k"])
    d.polygon([(8, 15), (14, 1), (20, 15)], fill=rgba("#e0b030"), outline=PALETTE["k"])
    d.rectangle([5, 12, 22, 15], fill=rgba("#5a1020"), outline=PALETTE["k"])
    for x, y in ((1, 3), (14, 1), (27, 3)):
        d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=PALETTE["y"], outline=PALETTE["k"])
    return img


def hoard_crest() -> Image.Image:
    """Dragon's Hoard: a horned dragon head. Eyes at (12, 9) and (19, 9)
    (left pixel of each 2 px eye) glow from code."""
    img = Image.new("RGBA", (32, 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    green, dark, light = rgba("#30a060"), rgba("#145030"), rgba("#60d090")
    # Horns.
    d.polygon([(9, 7), (3, 0), (11, 4)], fill=rgba("#e8d8b0"), outline=PALETTE["k"])
    d.polygon([(22, 7), (28, 0), (20, 4)], fill=rgba("#e8d8b0"), outline=PALETTE["k"])
    # Frills.
    d.polygon([(7, 8), (0, 12), (8, 14)], fill=dark, outline=PALETTE["k"])
    d.polygon([(24, 8), (31, 12), (23, 14)], fill=dark, outline=PALETTE["k"])
    # Head and snout.
    d.rounded_rectangle([8, 4, 23, 14], radius=4, fill=green, outline=PALETTE["k"])
    d.rounded_rectangle([10, 11, 21, 19], radius=3, fill=green, outline=PALETTE["k"])
    d.line([10, 5, 21, 5], fill=light)
    d.line([12, 7, 14, 8], fill=PALETTE["k"])
    d.line([19, 8, 21, 7], fill=PALETTE["k"])
    for x in (12, 19):
        d.rectangle([x, 9, x + 1, 10], fill=PALETTE["y"])
    for x in (13, 18):
        img.putpixel((x, 15), PALETTE["k"])
    d.line([12, 18, 19, 18], fill=dark)
    for x in (12, 19):
        img.putpixel((x, 19), PALETTE["w"])
    return img


def tome_crest() -> Image.Image:
    """Tome of Ages: an open book with glowing pages."""
    img = Image.new("RGBA", (24, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([5, 0, 19, 8], fill=rgba("#f8e080"))
    d.polygon([(1, 4), (12, 6), (12, 13), (1, 11)], fill=rgba("#f0e0b8"), outline=PALETTE["k"])
    d.polygon([(23, 4), (12, 6), (12, 13), (23, 11)], fill=rgba("#e4d0a0"), outline=PALETTE["k"])
    for y in (7, 9):
        d.line([3, y, 9, y + 1], fill=PALETTE["B"])
        d.line([15, y + 1, 21, y], fill=PALETTE["B"])
    d.line([12, 6, 12, 13], fill=PALETTE["Y"])
    return img


def halls_crest() -> Image.Image:
    """Shifting Halls: a stone keystone carved with a rune."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(1, 0), (14, 0), (11, 15), (4, 15)], fill=rgba("#7a7a8c"), outline=PALETTE["k"])
    d.line([2, 1, 13, 1], fill=rgba("#a0a0b4"))
    d.line([8, 3, 8, 12], fill=PALETTE["c"])
    d.line([5, 5, 8, 8], fill=PALETTE["c"])
    d.line([11, 5, 8, 8], fill=PALETTE["c"])
    return img


def lever_base() -> Image.Image:
    """Old Cellar / Gamba Machine side lever housing (8x14)."""
    img = Image.new("RGBA", (8, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, 7, 13], radius=2, fill=rgba("#7a828c"), outline=PALETTE["k"])
    d.line([1, 2, 1, 11], fill=rgba("#c8ced6"))
    d.ellipse([2, 4, 5, 7], fill=PALETTE["k"])
    return img


def lever_arm() -> Image.Image:
    """The lever's arm and knob (8x30). Pivots at its bottom centre."""
    img = Image.new("RGBA", (8, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([3, 6, 4, 29], fill=rgba("#c8ced6"), outline=None)
    d.line([3, 6, 3, 29], fill=rgba("#f4f4f4"))
    d.line([5, 6, 5, 29], fill=PALETTE["k"])
    d.line([2, 6, 2, 29], fill=PALETTE["k"])
    d.ellipse([0, 0, 7, 7], fill=PALETTE["r"], outline=PALETTE["k"])
    d.point([(2, 2), (3, 2), (2, 3)], fill=rgba("#ff9090"))
    return img


def cobweb() -> Image.Image:
    img = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    web = rgba("#e8e8f0", 150)
    for end in ((11, 0), (11, 5), (8, 9), (3, 11), (0, 11)):
        d.line([0, 0, end[0], end[1]], fill=web)
    for r in (4, 7, 10):
        d.arc([-r, -r, r, r], 0, 90, fill=web)
    return img


def card_image(face: str) -> Image.Image:
    """Jester's gamble card (18x26): 'back', 'red' or 'black'."""
    img = Image.new("RGBA", (18, 26), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if face == "back":
        d.rounded_rectangle([0, 0, 17, 25], radius=2, fill=rgba("#5a1020"), outline=PALETTE["k"])
        d.rectangle([2, 2, 15, 23], outline=rgba("#e0b030"))
        for y in range(4, 23, 4):
            for x in range(4 + (y // 4 % 2) * 2, 15, 4):
                d.polygon([(x, y - 1), (x + 1, y), (x, y + 1), (x - 1, y)], fill=PALETTE["r"])
        d.polygon([(9, 8), (13, 13), (9, 18), (5, 13)], fill=rgba("#e0b030"), outline=PALETTE["k"])
        return img
    d.rounded_rectangle([0, 0, 17, 25], radius=2, fill=PALETTE["w"], outline=PALETTE["k"])
    ink = PALETTE["r"] if face == "red" else PALETTE["k"]
    if face == "red":  # heart
        d.ellipse([3, 7, 9, 13], fill=ink)
        d.ellipse([8, 7, 14, 13], fill=ink)
        d.polygon([(3, 11), (14, 11), (9, 19)], fill=ink)
    else:  # spade
        d.polygon([(9, 5), (3, 13), (14, 13)], fill=ink)
        d.ellipse([3, 10, 9, 16], fill=ink)
        d.ellipse([8, 10, 14, 16], fill=ink)
        d.polygon([(9, 14), (6, 20), (12, 20)], fill=ink)
    for x, y in ((2, 2), (15, 23)):
        d.rectangle([x - 1, y - 1, x, y], fill=ink)
    return img


def dragon_wing() -> Image.Image:
    """Dragon's Hoard cabinet wing (left side, 44x38): a bat-like wing whose
    root is the bottom-right corner (it hides behind the cabinet's top
    corner). Flipped for the right side."""
    img = Image.new("RGBA", (44, 38), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    membrane, shade, bone, claw = rgba("#2a8a50"), rgba("#1e6a40"), rgba("#d8a830"), rgba("#f4f0e0")
    root = (40, 34)
    elbow = (26, 6)
    tips = [(2, 2), (0, 16), (6, 28), (18, 36)]
    # Membrane between the fingers, scalloped towards the root.
    outline = [root, elbow, tips[0], (8, 11), tips[1], (11, 23), tips[2], (19, 30), tips[3], (32, 37)]
    d.polygon(outline, fill=membrane, outline=PALETTE["k"])
    d.polygon([elbow, tips[1], (11, 23), tips[2], (19, 30), tips[3], root], fill=shade)
    for tip in tips[1:]:
        d.line([elbow, tip], fill=rgba("#145030"))
    # Arm bone: root to elbow to the first finger, with a claw on the elbow.
    d.line([root, elbow], fill=bone, width=2)
    d.line([elbow, tips[0]], fill=bone, width=1)
    d.polygon([(elbow[0] - 1, elbow[1]), (elbow[0] + 2, elbow[1] - 5), (elbow[0] + 3, elbow[1] + 1)], fill=claw, outline=PALETTE["k"])
    d.ellipse([root[0] - 3, root[1] - 3, root[0] + 3, root[1] + 3], fill=bone, outline=PALETTE["k"])
    return img


def dragon_egg(lit: bool) -> Image.Image:
    """Respin counter lamp: a dragon egg (9x11), glowing when lit."""
    img = Image.new("RGBA", (9, 11), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if lit:
        d.ellipse([0, 0, 8, 10], fill=rgba("#f8a830"), outline=PALETTE["k"])
        d.ellipse([2, 2, 5, 6], fill=rgba("#fff0a0"))
        d.point([(5, 7), (6, 5), (3, 8)], fill=rgba("#c06010"))
    else:
        d.ellipse([0, 0, 8, 10], fill=rgba("#2c4034"), outline=PALETTE["k"])
        d.point([(3, 3), (5, 6)], fill=rgba("#40584a"))
    return img


def candle() -> Image.Image:
    """Tome of Ages candle (6x14); the flame is drawn from code."""
    img = Image.new("RGBA", (6, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 3, 4, 12], fill=rgba("#f0e8d0"), outline=PALETTE["k"])
    d.line([2, 4, 2, 11], fill=PALETTE["w"])
    d.line([1, 5, 1, 7], fill=rgba("#f0e8d0"))
    d.rectangle([0, 12, 5, 13], fill=rgba("#c09040"), outline=PALETTE["k"])
    img.putpixel((2, 2), PALETTE["k"])
    return img


RUNE_STROKES = [
    [(3, 0, 3, 6), (0, 2, 3, 0), (6, 2, 3, 0)],
    [(1, 0, 1, 6), (1, 0, 5, 2), (5, 2, 1, 4)],
    [(0, 0, 6, 6), (6, 0, 0, 6), (3, 0, 3, 2)],
    [(1, 0, 1, 6), (5, 0, 5, 6), (1, 3, 5, 3)],
]


def rune(index: int) -> Image.Image:
    """Shifting Halls rune glyph (7x7, white: tinted from code)."""
    img = Image.new("RGBA", (7, 7), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for stroke in RUNE_STROKES[index]:
        d.line(stroke, fill=PALETTE["w"])
    return img


def skin_art() -> dict:
    art = {}
    for name in SKIN_COLORS:
        art[f"machines/{name}/frame.png"] = lambda n=name: skin_frame(n)
        art[f"machines/{name}/reel.png"] = lambda n=name: skin_reel(n)
        art[f"machines/{name}/marquee.png"] = lambda n=name: skin_marquee(n)
        art[f"machines/{name}/wing.png"] = lambda n=name: skin_wing(n)
    art.update({
        "machines/standard/crest.png": coin_crest,
        "machines/old_cellar/crest.png": cellar_crest,
        "machines/jester_81/crest.png": jester_crest,
        "machines/dragons_hoard/crest.png": hoard_crest,
        "machines/tome_of_ages/crest.png": tome_crest,
        "machines/shifting_halls/crest.png": halls_crest,
        "machines/parts/lever_base.png": lever_base,
        "machines/parts/lever_arm.png": lever_arm,
        "machines/parts/cobweb.png": cobweb,
        "machines/parts/card_back.png": lambda: card_image("back"),
        "machines/parts/card_red.png": lambda: card_image("red"),
        "machines/parts/card_black.png": lambda: card_image("black"),
        "machines/parts/dragon_wing.png": dragon_wing,
        "machines/parts/egg_lit.png": lambda: dragon_egg(True),
        "machines/parts/egg_dark.png": lambda: dragon_egg(False),
        "machines/parts/candle.png": candle,
    })
    for i in range(len(RUNE_STROKES)):
        art[f"machines/parts/rune_{i}.png"] = lambda i=i: rune(i)
    return art


MACHINE_ART = {
    "symbols/jester.png": jester_symbol,
    "symbols/crown.png": crown_symbol,
    "symbols/tome.png": tome_symbol,
    "symbols/chest.png": chest_symbol,
    "ui/machine_standard.png": slot_machine_icon,
    "ui/machine_halls.png": halls_icon,
    **skin_art(),
}


def machine_art() -> None:
    for rel_path, build in MACHINE_ART.items():
        save(build(), rel_path)


def forest_tile() -> Image.Image:
    """Seamless 64x64 tile of dense forest, used around the battlefield and for groves on it."""
    size = 64
    rng = random.Random(21)
    img = Image.new("RGBA", (size, size), rgba("#24502a"))
    d = ImageDraw.Draw(img)
    trees = [(rng.randrange(size), rng.randrange(size), rng.randint(8, 12)) for _ in range(14)]
    for cx, cy, r in sorted(trees, key=lambda t: t[1]):
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                x, y = cx + ox, cy + oy
                d.ellipse([x - r, y - r, x + r, y + r], fill=rgba("#2c6830"), outline=PALETTE["k"])
                d.ellipse([x - r + 2, y - r + 1, x + r - 3, y + r - 4], fill=rgba("#3c8038"))
                d.ellipse([x - r + 3, y - r + 2, x - 1, y - 1], fill=rgba("#58a048"))
    return img


# --------------------------------------------------------------------------
# UI kit: nine-patch buttons and panels used by assets/theme/main_theme.tres
# (16x16, 5 px margins, 6 px at the bottom of buttons for the raised lip).
# --------------------------------------------------------------------------
BUTTON_STYLES = {
    # fill, highlight, lip (shadow under the face), trim (inner border)
    "normal": ("#74471f", "#a06a34", "#3e2410", "#b0802c"),
    "hover": ("#8c5828", "#c08848", "#4a2c12", "#f8d038"),
    "pressed": ("#5a3418", "#5a3418", "#5a3418", "#a07028"),
    "disabled": ("#3a302a", "#4a4038", "#2a221e", "#54483c"),
    # Call to action (Play, March, Face the Night): gold.
    "accent_normal": ("#d8a030", "#f8d870", "#8a5a14", "#fff0a0"),
    "accent_hover": ("#f0bc40", "#fff0a0", "#9a6618", "#ffffff"),
    "accent_pressed": ("#b88420", "#b88420", "#b88420", "#f8d870"),
    # Neutral grey, tinted from code (machine SPIN buttons).
    "tint_normal": ("#c8c8c8", "#f4f4f4", "#707070", "#ffffff"),
    "tint_hover": ("#e0e0e0", "#ffffff", "#808080", "#ffffff"),
    "tint_pressed": ("#a8a8a8", "#a8a8a8", "#a8a8a8", "#e0e0e0"),
    "tint_disabled": ("#6a6a6a", "#7a7a7a", "#4a4a4a", "#808080"),
}


def ui_button(style: str) -> Image.Image:
    """A raised pixel button: dark outline, rounded corners, highlight on top,
    a 2 px lip below. Pressed buttons sit 2 px lower without the lip."""
    fill, light, lip, trim = (rgba(c) for c in BUTTON_STYLES[style])
    pressed = style.endswith("pressed")
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top = 2 if pressed else 0
    face_bottom = 15 if pressed else 13
    if not pressed:
        d.rounded_rectangle([0, 2, 15, 15], radius=2, fill=PALETTE["k"])
        d.rectangle([1, 12, 14, 14], fill=lip)
    d.rounded_rectangle([0, top, 15, face_bottom], radius=2, fill=fill, outline=PALETTE["k"])
    d.rectangle([1, top + 1, 14, face_bottom - 1], outline=trim)
    if not pressed:
        d.line([2, top + 2, 13, top + 2], fill=light)
    else:
        shade = tuple(int(c * 0.7) for c in fill[:3]) + (255,)
        d.line([2, top + 1, 13, top + 1], fill=shade)
    return img


def ui_panel(kind: str) -> Image.Image:
    """Panels: 'card' (wares, details), 'panel' (screens, tooltips) and
    'side' (the see-through side columns of the day screen)."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if kind == "card":
        d.rectangle([0, 0, 15, 15], fill=rgba("#3f2e20"), outline=PALETTE["k"])
        d.rectangle([1, 1, 14, 14], outline=rgba("#9e7538"))
        d.line([2, 2, 13, 2], fill=rgba("#4e3a28"))
        for x, y in ((1, 1), (14, 1), (1, 14), (14, 14)):
            img.putpixel((x, y), rgba("#f8d038"))
    elif kind == "panel":
        d.rectangle([0, 0, 15, 15], fill=rgba("#2a1e18", 248), outline=PALETTE["k"])
        d.rectangle([1, 1, 14, 14], outline=rgba("#8a5c2c"))
        d.rectangle([2, 2, 13, 13], outline=rgba("#4a3020"))
        for x, y in ((1, 1), (14, 1), (1, 14), (14, 14)):
            img.putpixel((x, y), rgba("#c08820"))
    elif kind == "side":
        d.rectangle([0, 0, 15, 15], fill=rgba("#140c08", 150), outline=rgba("#1a1220", 200))
        d.rectangle([1, 1, 14, 14], outline=rgba("#9e7538", 170))
        for x, y in ((1, 1), (14, 1), (1, 14), (14, 14)):
            img.putpixel((x, y), rgba("#f8d038", 220))
    return img


def ui_kit() -> dict:
    art = {f"ui/kit/button_{name}.png": (lambda n=name: ui_button(n)) for name in BUTTON_STYLES}
    for kind in ("card", "panel", "side"):
        art[f"ui/kit/panel_{kind}.png"] = lambda k=kind: ui_panel(k)
    return art


def slider_grabber(highlight: bool) -> Image.Image:
    """Gold knob for the volume sliders (10x14)."""
    img = Image.new("RGBA", (10, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    face = PALETTE["y"] if highlight else rgba("#d8a830")
    d.rounded_rectangle([0, 0, 9, 13], radius=3, fill=face, outline=PALETTE["k"])
    d.line([2, 2, 2, 10], fill=rgba("#fff0a0") if highlight else PALETTE["y"])
    d.line([4, 4, 4, 9], fill=PALETTE["Y"])
    d.line([6, 4, 6, 9], fill=PALETTE["Y"])
    return img


def main() -> None:
    for name, rows in SYMBOLS.items():
        save(from_map(name, rows), f"symbols/{name}.png")
    for name, rows in UNITS.items():
        save(from_map(name, rows), f"units/{name}.png")
    for name, rows in ENEMIES.items():
        save(from_map(name, rows), f"enemies/{name}.png")
    for name, rows in UI_ICONS.items():
        save(from_map(name, rows), f"ui/{name}.png")
    save(payline_icon(), "ui/payline.png")
    save(slider_grabber(False), "ui/slider_grabber.png")
    save(slider_grabber(True), "ui/slider_grabber_highlight.png")
    for rel_path, build in ui_kit().items():
        save(build(), rel_path)
    for name, rows in UPGRADE_ICONS.items():
        save(from_map(name, rows), f"ui/{name}.png")
    save(bolts_icon(), "ui/bolts.png")
    save(watchtower(), "environment/tower.png")
    for name, build in TROOP_VARIANTS.items():
        save(from_map(name, build()), f"units/{name}.png")
    for name, build in ENEMY_VARIANTS.items():
        save(from_map(name, build()), f"enemies/{name}.png")
    save(from_map("holy", HOLY_SYMBOL), "symbols/holy.png")
    save(pike_symbol(), "symbols/pike.png")
    save(crossbow_symbol(), "symbols/crossbow.png")
    save(fire_orb(), "projectiles/fire_orb.png")
    save(from_map("tombstone", TOMBSTONE_SYMBOL), "symbols/tombstone.png")
    save(purple_tombstone(), "symbols/purple_tombstone.png")
    save(empty_slot(), "symbols/empty_slot.png")
    save(from_map("boulder", BOULDER, 5), "projectiles/boulder.png")
    save(cursed_coin(), "symbols/cursed_coin.png")
    save(quiver_symbol(), "symbols/quiver.png")
    save(banner_symbol(), "symbols/banner.png")
    save(sigil_symbol(), "symbols/sigil.png")
    machine_art()
    save(mage_tower(), "environment/mage_tower.png")
    save(ballista_tower(), "environment/ballista_tower.png")
    save(from_map("coin", SYMBOLS["coin"]).resize((64, 64), Image.NEAREST), "ui/icon.png")
    for name, img in projectile_images().items():
        save(img, f"projectiles/{name}.png")
    save(castle(), "environment/castle.png")
    save(background(), "environment/background.png")
    save(forest_tile(), "environment/forest_tile.png")
    for name, build in TERRAIN_ART.items():
        save(build(), f"environment/terrain/{name}.png")


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["machines"]:
        machine_art()  # only the machine symbols, icons and cabinet skins
    elif sys.argv[1:] == ["orc_catapult"]:
        save(from_map("orc_catapult", ENEMIES["orc_catapult"]), "enemies/orc_catapult.png")
        save(from_map("boulder", BOULDER, 5), "projectiles/boulder.png")
    elif sys.argv[1:] == ["empty_slot"]:
        save(empty_slot(), "symbols/empty_slot.png")
    elif sys.argv[1:] == ["purple_tombstone"]:
        save(purple_tombstone(), "symbols/purple_tombstone.png")
    elif sys.argv[1:] == ["curse_art"]:  # Cursed Coin, Greed Monster and the Knight
        save(cursed_coin(), "symbols/cursed_coin.png")
        save(from_map("greed_monster", ENEMIES["greed_monster"]), "enemies/greed_monster.png")
        save(from_map("knight", UNITS["knight"]), "units/knight.png")
    elif sys.argv[1:] == ["zombie_miner"]:
        save(from_map("zombie_miner", ENEMIES["zombie_miner"]), "enemies/zombie_miner.png")
    elif sys.argv[1:] == ["ui"]:
        for rel_path, build in ui_kit().items():  # only the button and panel kit
            save(build(), rel_path)
    else:
        main()
