class_name SlotWin
extends RefCounted
## One win from a spin: a payline, a ways combination, an expanded symbol, a
## hoard prize... DayPhase turns it into gold, troops, repairs or curse spirits.

## Ways multiply a reward only a little (up to MachineStyle.ways_cap), and
## ways, chains and multiplier wilds together are capped, so one lucky spin
## can't flood the battlefield or the treasury.
const TROOP_WAYS_CAP := 2
const VALUE_SCALE_CAP := 12
const TROOP_SCALE_CAP := 3
const WAYS_COLOR := Color("#f8f8f8")

var symbol: SymbolData
## Reels matched (the key into the machine's match multipliers).
var count := 0
## (reel, row) of every cell that is part of the win, left to right.
var cells: Array[Vector2i] = []
## Combinations paid at once (ways wins, expanded symbols on many lines).
var ways := 1
## Multiplier wilds, gamble, cascade chains...
var extra_mult := 1
## Share of the paytable reward (mixed group wins pay half), rounded, at least 1.
var reward_scale := 1.0
## Set for line wins only.
var payline: Payline
var label := ""
var color := WAYS_COLOR
## Pays exactly `fixed_amount` (hoard prizes, coins, gambles) instead of the
## paytable. Negative gold is a lost gamble.
var fixed := false
var fixed_amount := 0
var fixed_effect: SymbolData.Effect = SymbolData.Effect.NONE


static func line(p_payline: Payline, p_symbol: SymbolData, p_count: int) -> SlotWin:
	var win := SlotWin.new()
	win.payline = p_payline
	win.symbol = p_symbol
	win.count = p_count
	win.label = p_payline.display_name()
	win.color = p_payline.color()
	for reel in p_count:
		win.cells.append(Vector2i(reel, p_payline.rows[reel]))
	return win


static func combo(p_symbol: SymbolData, p_count: int, p_ways: int, p_cells: Array[Vector2i]) -> SlotWin:
	var win := SlotWin.new()
	win.symbol = p_symbol
	win.count = p_count
	win.ways = p_ways
	win.cells = p_cells
	win.label = "%d way%s" % [p_ways, "" if p_ways == 1 else "s"]
	return win


static func prize(effect: SymbolData.Effect, amount: int, p_symbol: SymbolData, p_cells: Array[Vector2i], p_label: String) -> SlotWin:
	var win := SlotWin.new()
	win.symbol = p_symbol
	win.fixed = true
	win.fixed_effect = effect
	win.fixed_amount = amount
	win.cells = p_cells
	win.label = p_label
	win.color = Color("#f8d038")
	return win


func effect() -> SymbolData.Effect:
	return fixed_effect if fixed else symbol.effect


## Gold, troops, HP or spirits this win gives with the current symbol levels.
func amount() -> int:
	if fixed:
		return fixed_amount
	var base := maxi(1, roundi(symbol.reward_amount(count, GameState.level_of(symbol.id)) * reward_scale))
	var cap := GameState.machine.ways_cap
	if effect() == SymbolData.Effect.SPAWN_UNIT:
		return base * mini(mini(ways, mini(cap, TROOP_WAYS_CAP)) * extra_mult, TROOP_SCALE_CAP)
	return base * mini(mini(ways, cap) * extra_mult, VALUE_SCALE_CAP)


## Gold this win pays (0 for troops, repairs and curses).
func gold() -> int:
	return amount() if effect() in [SymbolData.Effect.GOLD, SymbolData.Effect.WILD] else 0


## Where reward effects start: the right-most cell of the win.
func last_cell() -> Vector2i:
	var last := cells[0]
	for cell in cells:
		if cell.x > last.x or (cell.x == last.x and cell.y > last.y):
			last = cell
	return last


## "Row 2: 3x Sword", "9 ways: 4x Coin", "Vault: Mini".
func headline() -> String:
	if fixed:
		return label
	var text := "%s: %dx %s" % [label, count, symbol.display_name]
	if extra_mult > 1:
		text += " (x%d)" % extra_mult
	return text
