class_name Paylines
extends RefCounted
## Payline shapes for the slot machine (5 reels, 3 to 5 rows).
## Each line lists the row it passes through on every reel (0 = top).
##
## Row lines ("row" key) are owned automatically for every row the machine has.
## The other lines are sold by the merchant in this order, once the machine has
## enough rows and the castle's payline tier allows them ("tier", default 1).

const ALL := [
	{"name": "Top Row", "rows": [0, 0, 0, 0, 0], "row": 0},
	{"name": "Middle Row", "rows": [1, 1, 1, 1, 1], "row": 1},
	{"name": "Bottom Row", "rows": [2, 2, 2, 2, 2], "row": 2},
	{"name": "Fourth Row", "rows": [3, 3, 3, 3, 3], "row": 3},
	{"name": "Fifth Row", "rows": [4, 4, 4, 4, 4], "row": 4},
	# Tier 1: every castle.
	{"name": "Valley", "rows": [0, 1, 2, 1, 0]},
	{"name": "Peak", "rows": [2, 1, 0, 1, 2]},
	{"name": "Stairs Down", "rows": [0, 0, 1, 2, 2]},
	{"name": "Stairs Up", "rows": [2, 2, 1, 0, 0]},
	{"name": "Crown", "rows": [1, 0, 0, 0, 1]},
	{"name": "Chalice", "rows": [1, 2, 2, 2, 1]},
	# Tier 2: Frostpeak Citadel and later.
	{"name": "Bridge", "rows": [0, 1, 1, 1, 0], "tier": 2},
	{"name": "Hammock", "rows": [2, 1, 1, 1, 2], "tier": 2},
	{"name": "Snake", "rows": [0, 1, 0, 1, 0], "tier": 2},
	{"name": "Wave", "rows": [2, 1, 2, 1, 2], "tier": 2},
	# Tier 3: Ashen Throne.
	{"name": "Fangs", "rows": [0, 2, 0, 2, 0], "tier": 3},
	{"name": "Spikes", "rows": [2, 0, 2, 0, 2], "tier": 3},
	{"name": "Arrowhead", "rows": [1, 0, 2, 0, 1], "tier": 3},
	{"name": "Lantern", "rows": [1, 2, 0, 2, 1], "tier": 3},
	# Need 4-5 rows.
	{"name": "Deep Valley", "rows": [1, 2, 3, 2, 1]},
	{"name": "Zigzag", "rows": [3, 2, 3, 2, 3]},
	{"name": "Lightning", "rows": [0, 1, 2, 3, 4]},
	{"name": "Thunder", "rows": [4, 3, 2, 1, 0]},
]

## Symbols must match starting from the leftmost reel. Reward multiplier by match length.
const MIN_MATCH := 3
const MATCH_MULTIPLIER := {3: 1, 4: 2, 5: 4}

const COLORS := [
	Color("#f8d038"), Color("#ff6060"), Color("#60d8f8"), Color("#80f060"),
	Color("#f080f0"), Color("#ffa040"), Color("#a0a0ff"), Color("#ffffff"),
	Color("#40f0c0"), Color("#f0a0a0"), Color("#c0f080"), Color("#80c0ff"),
	Color("#ffd0a0"), Color("#d0a0ff"), Color("#a0ffd0"), Color("#ff9090"),
	Color("#90ff90"), Color("#9090ff"), Color("#ffff90"), Color("#ff90ff"),
	Color("#90ffff"), Color("#ffc060"), Color("#c0c0c0"), Color("#60ffa0"),
]


static func rows_of(index: int) -> Array:
	return ALL[index]["rows"]


static func name_of(index: int) -> String:
	return ALL[index]["name"]


static func color_of(index: int) -> Color:
	return COLORS[index % COLORS.size()]


static func tier_of(index: int) -> int:
	return ALL[index].get("tier", 1)


static func is_row_line(index: int) -> bool:
	return ALL[index].has("row")


## Rows the machine needs for this line.
static func height_of(index: int) -> int:
	var deepest := 0
	for row: int in rows_of(index):
		deepest = maxi(deepest, row)
	return deepest + 1


## Row lines for a machine with `row_count` rows.
static func row_lines(row_count: int) -> Array[int]:
	var result: Array[int] = []
	for i in ALL.size():
		if is_row_line(i) and ALL[i]["row"] < row_count:
			result.append(i)
	return result
