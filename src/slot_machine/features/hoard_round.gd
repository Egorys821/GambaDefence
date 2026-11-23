class_name HoardRound
extends RefCounted
## Dragon's Hoard hold-and-win round (pure). Chests lock in place; each respin
## the empty cells may land new chests. A new chest refills the respins, a
## miss uses one up. The round ends when respins run out or the grid is full
## (the Grand prize).

## Chance per empty cell per respin, for a 15-cell grid (scaled by size).
const BASE_CHEST_CHANCE := 0.07
const BASE_CELLS := 15
## Hoard troops are capped like other big wins.
const MAX_TROOPS := 16

var reels: int
var rows: int
var max_respins: int
var respins_left: int
## Locked cell (Vector2i) -> HoardPrize.
var prizes: Dictionary = {}


func _init(p_reels: int, p_rows: int, p_respins: int) -> void:
	reels = p_reels
	rows = p_rows
	max_respins = p_respins
	respins_left = p_respins


func lock(cell: Vector2i, prize: HoardPrize) -> void:
	prizes[cell] = prize


func empty_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for reel in reels:
		for row in rows:
			if not prizes.has(Vector2i(reel, row)):
				cells.append(Vector2i(reel, row))
	return cells


func chest_chance() -> float:
	return BASE_CHEST_CHANCE * BASE_CELLS / float(reels * rows)


## One respin: each empty cell lands a chest with `chance`; `roll_prize`
## returns the HoardPrize for a new chest. Returns the newly locked cells.
func respin(chance: float, rng: RandomNumberGenerator, roll_prize: Callable) -> Array[Vector2i]:
	var landed: Array[Vector2i] = []
	for cell in empty_cells():
		if rng.randf() < chance:
			lock(cell, roll_prize.call())
			landed.append(cell)
	respins_left = max_respins if not landed.is_empty() else respins_left - 1
	return landed


func is_full() -> bool:
	return prizes.size() >= reels * rows


func is_over() -> bool:
	return is_full() or respins_left <= 0


## The round's rewards as wins: all gold together, troops per unit, repairs,
## plus `grand` when the grid is full. `full_repair` is the castle's max HP;
## `gold_bonus` adds a share of the gold (0.25 = +25%).
func payout(chest: SymbolData, full_repair: int, grand: HoardPrize = null, gold_bonus: float = 0.0) -> Array[SlotWin]:
	var all: Array[HoardPrize] = []
	all.assign(prizes.values())
	if grand and is_full():
		all.append(grand)
	var gold := 0
	var repair := 0
	var troops := {}  # unit symbol -> count
	for prize in all:
		gold += prize.gold
		repair += full_repair if prize.repair < 0 else prize.repair
		if prize.troops > 0:
			troops[prize.unit_symbol] = troops.get(prize.unit_symbol, 0) + prize.troops
	var cells: Array[Vector2i] = []
	cells.assign(prizes.keys())
	var wins: Array[SlotWin] = []
	gold = roundi(gold * (1.0 + gold_bonus))
	if gold > 0:
		wins.append(SlotWin.prize(SymbolData.Effect.GOLD, gold, chest, cells, "Hoard: %d chests" % prizes.size()))
	for unit_symbol: SymbolData in troops:
		var count := mini(troops[unit_symbol], MAX_TROOPS)
		wins.append(SlotWin.prize(SymbolData.Effect.SPAWN_UNIT, count, unit_symbol, cells, "Hoard: %s" % unit_symbol.display_name))
	if repair > 0:
		wins.append(SlotWin.prize(SymbolData.Effect.REPAIR, repair, chest, cells, "Hoard: repairs"))
	return wins
