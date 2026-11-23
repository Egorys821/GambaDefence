class_name Paylines
extends RefCounted
## Pattern shapes for the slot machines and the rules for placing them.
##
## Each machine style pays on one table of shapes (MachineStyle.line_table).
## A shape lists, for each reel, a row offset (0 = its top row). Owning a
## shape gives one line at every height where it fits on the machine, e.g.
## Valley (3 rows tall) gives 1 line on a 3-row machine and 3 lines on a
## 5-row machine. See Payline for one concrete line.
##
## The merchant sells shapes in table order, when the castle's payline tier and
## the machine's rows allow them ("tier" defaults to 1).

## Every table starts with its straight row.
const STRAIGHT := 0

## 5 reels: the standard machine, Tome of Ages and Dragon's Hoard.
const STANDARD := [
	{"name": "Straight", "offsets": [0, 0, 0, 0, 0]},
	{"name": "Valley", "offsets": [0, 1, 2, 1, 0]},
	{"name": "Peak", "offsets": [2, 1, 0, 1, 2]},
	{"name": "Crown", "offsets": [1, 0, 0, 0, 1]},
	{"name": "Cup", "offsets": [0, 1, 1, 1, 0]},
	{"name": "Stairs Down", "offsets": [0, 0, 1, 2, 2]},
	{"name": "Stairs Up", "offsets": [2, 2, 1, 0, 0]},
	{"name": "Snake", "offsets": [0, 1, 0, 1, 0], "tier": 2},
	{"name": "Wave", "offsets": [1, 0, 1, 0, 1], "tier": 2},
	{"name": "Hook", "offsets": [0, 0, 0, 1, 2], "tier": 2},
	{"name": "Swoop", "offsets": [2, 1, 0, 0, 0], "tier": 2},
	{"name": "Fangs", "offsets": [0, 2, 0, 2, 0], "tier": 3},
	{"name": "Spikes", "offsets": [2, 0, 2, 0, 2], "tier": 3},
	{"name": "Arrowhead", "offsets": [1, 0, 2, 0, 1], "tier": 3},
	{"name": "Lantern", "offsets": [1, 2, 0, 2, 1], "tier": 3},
	# Tall shapes: only fit machines with 4-5 rows.
	{"name": "Deep V", "offsets": [0, 2, 3, 2, 0]},
	{"name": "Lightning", "offsets": [0, 1, 2, 3, 4]},
	{"name": "Thunder", "offsets": [4, 3, 2, 1, 0]},
]

## 4 reels x 3 rows: Jester's 81. All owned from the start: 3 rows + 4 shapes = 7 lines.
const JESTER := [
	{"name": "Straight", "offsets": [0, 0, 0, 0]},
	{"name": "Dip", "offsets": [0, 2, 2, 0]},
	{"name": "Bump", "offsets": [2, 0, 0, 2]},
	{"name": "Slide", "offsets": [0, 1, 2, 2]},
	{"name": "Climb", "offsets": [2, 1, 0, 0]},
]

## 3 reels x 3 rows: Old Cellar. The classic 5 lines: 3 rows + 2 diagonals.
const CELLAR := [
	{"name": "Straight", "offsets": [0, 0, 0]},
	{"name": "Diagonal", "offsets": [0, 1, 2]},
	{"name": "Rise", "offsets": [2, 1, 0]},
]

const TABLES := {
	&"standard": STANDARD,
	&"jester": JESTER,
	&"cellar": CELLAR,
}

const COLORS := [
	Color("#f8d038"), Color("#ff6060"), Color("#60d8f8"), Color("#80f060"),
	Color("#f080f0"), Color("#ffa040"), Color("#a0a0ff"), Color("#ffffff"),
	Color("#40f0c0"), Color("#f0a0a0"), Color("#c0f080"), Color("#80c0ff"),
	Color("#ffd0a0"), Color("#d0a0ff"), Color("#a0ffd0"), Color("#ff9090"),
	Color("#90ff90"), Color("#ffc060"),
]


## The shapes of a table, or none for machines that don't use lines.
static func table(table_id: StringName) -> Array:
	return TABLES.get(table_id, [])


static func shape_name(shapes: Array, shape: int) -> String:
	return shapes[shape]["name"]


static func shape_offsets(shapes: Array, shape: int) -> Array:
	return shapes[shape]["offsets"]


static func shape_tier(shapes: Array, shape: int) -> int:
	return shapes[shape].get("tier", 1)


static func shape_color(shape: int) -> Color:
	return COLORS[shape % COLORS.size()]


## Rows the shape spans.
static func shape_height(shapes: Array, shape: int) -> int:
	var deepest := 0
	for offset: int in shape_offsets(shapes, shape):
		deepest = maxi(deepest, offset)
	return deepest + 1


## Every placement of `shape` on a machine with `rows` rows (top to bottom).
static func lines_of(shapes: Array, shape: int, rows: int) -> Array[Payline]:
	var lines: Array[Payline] = []
	for shift in rows - shape_height(shapes, shape) + 1:
		lines.append(Payline.new(shapes, shape, shift))
	return lines


## All lines for a set of owned shapes.
static func lines_for(shapes: Array, owned: Array[int], rows: int) -> Array[Payline]:
	var lines: Array[Payline] = []
	for shape in owned:
		lines.append_array(lines_of(shapes, shape, rows))
	return lines
