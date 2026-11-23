class_name MachineStyle
extends Resource
## One kind of slot machine: its layout, how wins are counted and its bonus
## feature. Instances live in res://data/machines/ and are loaded by GameState.
## The player unlocks and picks machines in the Time Forge ("Machines" branch).
## See docs/SLOT_MACHINE_STYLES.md for the design of each machine.

enum Eval {
	LINES,          ## Paylines, matched from the left reel.
	WAYS,           ## Every left-to-right combination of adjacent reels, any row.
	LINES_OR_WAYS,  ## Lines, but WAYS on any spin that shows a `ways_trigger` symbol.
}

enum Feature {
	NONE,
	GAMBLE,        ## After a gold win: double or nothing (Jester's 81).
	NUDGE,         ## After a losing spin: shift one reel down a row (Old Cellar).
	FREE_SPINS,    ## Scatters start free spins with an expanding symbol (Tome of Ages).
	HOLD_AND_WIN,  ## Bonus chests lock in place for respins (Dragon's Hoard).
	CASCADE,       ## Winning symbols vanish and new ones drop in (Shifting Halls).
}

const STANDARD_ID := &"standard"

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export_multiline var description: String
## One line for the paytable: how this machine pays.
@export_multiline var rules_hint: String
@export var order: int = 0
## Stat that must be at least 1 to pick this machine. Empty = always available.
@export var unlock_stat: StringName

@export_group("Layout")
@export var reel_count: int = 5
## Rows on every reel. 0 = rows come from Stats.MACHINE_ROWS (the row upgrades).
@export var fixed_rows: int = 0
## Each reel rolls its own height in [min_rows, max_rows] every spin.
@export var variable_rows: bool = false
@export var min_rows: int = 2
@export var max_rows: int = 6
## Stat added to min_rows (Shifting Halls upgrade).
@export var min_rows_stat: StringName

@export_group("Wins")
@export var eval_mode: Eval = Eval.LINES
## Key in Paylines.TABLES: the pattern shapes this machine pays on and sells.
@export var line_table: StringName = &"standard"
## Every shape of the table is owned from the start (the merchant sells none).
@export var all_lines_owned: bool = false
@export var min_match: int = 3
## Match length -> reward multiplier (fractions pay less, rounded, at least 1).
@export var match_multiplier: Dictionary = {3: 1, 4: 2, 5: 4}
## Ways or lines paid at once multiply a reward up to this (1 = never).
@export var ways_cap: int = 3
## Stat added to the multiplier of a match across every reel.
@export var top_match_stat: StringName
## LINES_OR_WAYS: one visible copy turns the spin into a ways spin.
@export var ways_trigger: SymbolData
## Shortest match a ways spin pays (0 = min_match). Jester's 81 ways pay only 4.
@export var ways_min_match: int = 0
## Three different symbols of the same SymbolData.group pay as the weakest.
@export var group_pays: bool = false
## A Gold Coin on the first reel of a losing line pays Stats.CONSOLATION_GOLD.
@export var consolation_coin: bool = false

@export_group("Feature")
@export var feature: Feature = Feature.NONE
## FREE_SPINS: the scatter that starts them. HOLD_AND_WIN: the bonus chest.
@export var feature_symbol: SymbolData
## Count at most one feature symbol per reel (classic scatter rule).
@export var one_per_reel: bool = false
## Copies needed to start the feature, minus `trigger_stat`.
@export var feature_count: int = 3
## feature_count is for 3 rows; each extra row needs a few more (hoard chests).
@export var trigger_scales_with_rows: bool = false
@export var trigger_stat: StringName
## Free spins or respins, plus `length_stat`.
@export var feature_length: int = 10
@export var length_stat: StringName
@export var spins_per_day_bonus: int = 0

@export_group("Reels")
## Added to the castle's starting reels.
@export var start_symbols: Array[PoolEntry] = []
## One extra copy of this symbol per point of `signature_stat` at run start.
@export var signature_symbol: SymbolData
@export var signature_stat: StringName
## Sold by the merchant in every castle while this machine is used.
@export var merchant_symbols: Array[SymbolData] = []

@export_group("Look")
@export var frame_color: Color = Color("#c08820")
@export var bg_color: Color = Color("#3a2414")
@export var reel_colors: PackedColorArray = PackedColorArray([Color("#e8d8b0"), Color("#dccaa0")])


## Feature symbols that count on this grid.
func feature_symbols_on(grid: Array) -> int:
	if not one_per_reel:
		return GridOps.count(grid, feature_symbol)
	var reels := 0
	for column: Array in grid:
		if GridOps.count([column], feature_symbol) > 0:
			reels += 1
	return reels


func ways_match() -> int:
	return ways_min_match if ways_min_match > 0 else min_match


func uses_lines() -> bool:
	return eval_mode != Eval.WAYS


## Match lengths that can pay, shortest first (paytable columns).
func match_counts() -> Array[int]:
	var counts: Array[int] = []
	for count in range(min_match, reel_count + 1):
		counts.append(count)
	return counts


## Rows used when the player has `stat_rows` rows from upgrades.
func rows_for(stat_rows: int) -> int:
	if variable_rows:
		return max_rows
	return fixed_rows if fixed_rows > 0 else stat_rows


## True if the row upgrades do nothing on this machine.
func ignores_row_upgrades() -> bool:
	return variable_rows or fixed_rows > 0
