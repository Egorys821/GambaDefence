"""Generates every pixel-art sprite used by Gamba Defence.

Usage (from the project root, needs Pillow):
    python tools/generate_art.py

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
        ".....rr.........",
        "....rRrkkk......",
        "....kkggggk.....",
        "....kgwgggGk....",
        "....kgkkkkGk....",
        "....kggggGGk....",
        "...kkkggggkk.kk.",
        "..kGgggggggGkgk.",
        ".knnkggggggGkgk.",
        ".knYnkgggggGkgk.",
        ".knnnkgggggkYYYk",
        "..knk.kgGgGk.k..",
        "...k..kgGgGk....",
        "......kgkkgk....",
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
    """Top-down battlefield: forest at the top, castle grounds, road south, graveyard at the bottom."""
    w, h = 640, 360
    castle_x, castle_bottom = 320, 104
    graveyard_top = 318
    rng = random.Random(11)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    px = img.load()
    d = ImageDraw.Draw(img)

    grass = [rgba("#4c9a40"), rgba("#58a848"), rgba("#64b450")]
    grave_ground = [rgba("#3c5848"), rgba("#465e4c"), rgba("#506850")]
    patches = _value_noise(w, h, 24, 5)

    def road_x(y: float) -> float:
        return castle_x + 22 * math.sin((y - castle_bottom) * 0.025)

    for y in range(h):
        for x in range(w):
            v = patches[y][x] + rng.uniform(-0.08, 0.08)
            shade = 0 if v < 0.38 else 1 if v < 0.66 else 2
            px[x, y] = (grave_ground if y > graveyard_top + rng.randint(-3, 3) else grass)[shade]

    # Castle courtyard and road.
    dirt, dirt_light, dirt_dark = rgba("#9a7a4c"), rgba("#b09060"), rgba("#7a5e3a")
    d.ellipse([castle_x - 92, castle_bottom - 24, castle_x + 92, castle_bottom + 18], fill=dirt)
    for y in range(castle_bottom, h):
        cx = road_x(y)
        for x in range(int(cx - 9), int(cx + 10)):
            edge = abs(x - cx) > 7
            px[x, y] = dirt_dark if edge else (dirt_light if rng.random() < 0.08 else dirt)

    # Details: tufts, flowers and rocks (not on the road or courtyard).
    def free(x: int, y: int) -> bool:
        return abs(x - road_x(y)) > 14 and not (abs(x - castle_x) < 100 and y < castle_bottom + 22)

    for _ in range(500):
        x, y = rng.randrange(4, w - 4), rng.randrange(30, graveyard_top - 4)
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

    # Trees: dense forest along the top, a few along the sides.
    def tree(cx: int, cy: int, r: int) -> None:
        d.rectangle([cx - 1, cy + r - 2, cx + 1, cy + r + 3], fill=PALETTE["B"])
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba("#2c6830"), outline=PALETTE["k"])
        d.ellipse([cx - r + 2, cy - r + 1, cx + r - 3, cy + r - 4], fill=rgba("#3c8038"))
        d.ellipse([cx - r + 3, cy - r + 2, cx - 1, cy - 1], fill=rgba("#58a048"))

    forest = [(x, rng.randint(-6, 14)) for x in range(-10, w + 10, 13)]
    forest += [(rng.randrange(0, 70), rng.randrange(30, 280)) for _ in range(9)]
    forest += [(rng.randrange(570, 640), rng.randrange(30, 280)) for _ in range(9)]
    for cx, cy in sorted(forest, key=lambda p: p[1]):
        tree(cx, cy, rng.randint(9, 13))

    # Graveyard: broken fence, tombstones, dead trees.
    for x in range(0, w, 9):
        if rng.random() < 0.8 and abs(x - road_x(graveyard_top)) > 14:
            d.rectangle([x, graveyard_top - 6, x + 1, graveyard_top], fill=rgba("#5a3a20"), outline=PALETTE["k"])
            if rng.random() < 0.7:
                d.line([x + 2, graveyard_top - 4, x + 8, graveyard_top - 4], fill=rgba("#5a3a20"))
    stone_light, stone_dark = rgba("#a8a8b4"), rgba("#6a6a78")
    for _ in range(46):
        x, y = rng.randrange(8, w - 12), rng.randrange(graveyard_top + 8, h - 10)
        if abs(x - road_x(y)) < 14:
            continue
        if rng.random() < 0.7:
            d.rectangle([x, y, x + 6, y + 8], fill=stone_light, outline=PALETTE["k"])
            d.line([x + 1, y + 1, x + 5, y + 1], fill=rgba("#c8c8d4"))
            d.line([x + 3, y + 3, x + 3, y + 6], fill=stone_dark)
            d.line([x + 2, y + 4, x + 4, y + 4], fill=stone_dark)
        else:
            d.rectangle([x + 2, y, x + 4, y + 9], fill=stone_light, outline=PALETTE["k"])
            d.rectangle([x, y + 2, x + 6, y + 4], fill=stone_light, outline=PALETTE["k"])
        d.line([x - 1, y + 9, x + 7, y + 9], fill=rgba("#2a3a30"))
    for cx in (rng.randrange(40, 200), rng.randrange(440, 600)):
        cy = rng.randrange(graveyard_top + 22, h - 4)
        branch = rgba("#3a2a28")
        d.line([cx, cy, cx, cy - 18], fill=branch, width=2)
        d.line([cx, cy - 10, cx - 7, cy - 17], fill=branch)
        d.line([cx, cy - 13, cx + 6, cy - 21], fill=branch)
        d.line([cx - 4, cy - 14, cx - 8, cy - 13], fill=branch)
    return img


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


MACHINE_ART = {
    "symbols/jester.png": jester_symbol,
    "symbols/crown.png": crown_symbol,
    "symbols/tome.png": tome_symbol,
    "symbols/chest.png": chest_symbol,
    "ui/machine_standard.png": slot_machine_icon,
    "ui/machine_halls.png": halls_icon,
}


def machine_art() -> None:
    for rel_path, build in MACHINE_ART.items():
        save(build(), rel_path)


def forest_tile() -> Image.Image:
    """Seamless 64x64 tile of dense forest, used around the battlefield."""
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


if __name__ == "__main__":
    main()
