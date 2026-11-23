extends Node
## State of the current run, shared by the day phase (slot machine, shop) and
## the night phase (battle). Registered as the `GameState` autoload.
##
## Numbers that upgrades can change are read through stat() (see Stats).

signal gold_changed(gold: int)
signal castle_hp_changed(hp: int, max_hp: int)
## The reel contents, symbol levels, rows or paylines changed.
signal machine_changed
## A run upgrade was bought (stats may have changed).
signal upgrades_changed
## Extra threat (spirits) the curse has added to tonight's wave.
signal curse_changed(threat: int)

const SYMBOLS_DIR := "res://data/symbols/"
const UPGRADE_DIRS := ["res://data/upgrades/meta/", "res://data/upgrades/merchant/"]
const CASTLES_DIR := "res://data/castles/"
const MACHINES_DIR := "res://data/machines/"
const SKULL_ID := &"skull"
## The cursed symbol the curse spreads every dawn.
const CURSE_ID := &"tombstone"
## Troop hp/damage bonus per symbol level above 1 (0.35 = +35%).
const LEVEL_POWER_BONUS := 0.35
## Reward bonus per row upgrade on machines with fixed rows (0.3 = +30%).
const ROW_REWARD_BONUS := 0.3
## Extra feature symbols needed per row above 3, as a share (hoard chests).
const TRIGGER_PER_ROW := 0.2

## Every symbol in the game, by id.
var symbols: Dictionary = {}
## Every upgrade in the game (META and RUN), by id.
var upgrades: Dictionary = {}
## Every castle on the map, in map order.
var castles: Array[CastleData] = []
## The castle this run is defending.
var castle: CastleData
## Every machine style, by id.
var machines: Dictionary = {}
## The slot machine used this run (picked in the Time Forge).
var machine: MachineStyle

var night := 1
var gold := 0
var castle_hp := 0
var castle_max_hp := 0
var machine_rows := 3
## Symbol id -> copies on the reels. More copies = more likely to land.
var pool: Dictionary = {}
## Symbol id -> level (starts at 1).
var levels: Dictionary = {}
## Pattern shapes owned (indices into the machine's line table). Each one pays
## at every height it fits on the machine, see active_paylines().
var shapes: Array[int] = []
## RUN upgrade id -> level bought this run.
var run_upgrades: Dictionary = {}
var kills := 0
## Threat points added to tonight's wave by cursed symbols.
var curse_threat := 0
## Rarity tokens left in the merchant's hidden bag (see MerchantRarity).
var merchant_bag: Array[int] = []


func _ready() -> void:
	symbols = _load_resources([SYMBOLS_DIR])
	upgrades = _load_resources(UPGRADE_DIRS)
	for loaded: CastleData in _load_resources([CASTLES_DIR]).values():
		castles.append(loaded)
	castles.sort_custom(func(a: CastleData, b: CastleData) -> bool: return a.order < b.order)
	castle = castles[0]
	machines = _load_resources([MACHINES_DIR])
	reset()


## Starts a fresh run at the given castle.
func start_run(at_castle: CastleData) -> void:
	castle = at_castle
	reset()


func max_nights() -> int:
	return castle.nights


func castle_index(of: CastleData) -> int:
	return castles.find(of)


## Resets the run at the current castle using base stats plus permanent upgrades.
func reset() -> void:
	night = 1
	kills = 0
	curse_threat = 0
	run_upgrades.clear()
	merchant_bag.clear()
	levels.clear()
	gold = stat_int(Stats.START_GOLD)
	castle_max_hp = stat_int(Stats.CASTLE_MAX_HP)
	castle_hp = castle_max_hp
	machine = selected_machine()
	machine_rows = machine.rows_for(stat_int(Stats.MACHINE_ROWS))
	_fill_starting_pool()
	_own_starting_shapes()
	gold_changed.emit(gold)
	castle_hp_changed.emit(castle_hp, castle_max_hp)
	machine_changed.emit()
	upgrades_changed.emit()


## Takes one rarity token out of the merchant's bag, refilling it when empty.
func draw_merchant_rarity() -> int:
	if merchant_bag.is_empty():
		merchant_bag = MerchantRarity.new_bag()
	return merchant_bag.pop_back()


# --- Stats ------------------------------------------------------------------

## Effective value of a stat: base + permanent upgrades + this run's upgrades.
func stat(key: StringName) -> float:
	var value: float = Stats.BASE.get(key, 0.0)
	for upgrade: UpgradeData in upgrades.values():
		if upgrade.stat == key:
			value += upgrade.value_per_level * upgrade_level(upgrade)
	if Stats.LIMITS.has(key):
		var limit: Vector2 = Stats.LIMITS[key]
		value = clampf(value, limit.x, limit.y)
	return value


func stat_int(key: StringName) -> int:
	return roundi(stat(key))


func upgrade_level(upgrade: UpgradeData) -> int:
	if upgrade.scope == UpgradeData.Scope.META:
		return MetaProgress.level_of(upgrade.id)
	return run_upgrades.get(upgrade.id, 0)


## Parent upgrade owned (tree) and, for tower conversions, a plain tower to convert.
func prerequisites_met(upgrade: UpgradeData) -> bool:
	if upgrade.requires and upgrade_level(upgrade.requires) < upgrade.requires_level:
		return false
	if upgrade.scope == UpgradeData.Scope.RUN and upgrade.stat in [Stats.MAGE_TOWERS, Stats.BALLISTA_TOWERS]:
		return plain_towers() > 0
	# Don't sell rows the machine can't hold.
	if upgrade.scope == UpgradeData.Scope.RUN and upgrade.stat == Stats.MACHINE_ROWS \
			and (machine.ignores_row_upgrades() or machine_rows >= int(Stats.LIMITS[Stats.MACHINE_ROWS].y)):
		return false
	return true


func get_upgrades(scope: UpgradeData.Scope) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade: UpgradeData in upgrades.values():
		if upgrade.scope == scope:
			result.append(upgrade)
	result.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.base_cost < b.base_cost)
	return result


## Buys one level of a RUN upgrade (gold already paid by the shop).
func add_run_upgrade(id: StringName) -> void:
	run_upgrades[id] = run_upgrades.get(id, 0) + 1
	_apply_stat_changes()
	upgrades_changed.emit()


## Keeps run state in sync after stats change mid-run (walls, rows...).
func _apply_stat_changes() -> void:
	var new_max := stat_int(Stats.CASTLE_MAX_HP)
	if new_max != castle_max_hp:
		castle_hp += maxi(0, new_max - castle_max_hp)
		castle_max_hp = new_max
		castle_hp = mini(castle_hp, castle_max_hp)
		castle_hp_changed.emit(castle_hp, castle_max_hp)
	var new_rows := machine.rows_for(stat_int(Stats.MACHINE_ROWS))
	if new_rows != machine_rows:
		machine_rows = new_rows  # every owned shape now fits at more heights
		machine_changed.emit()


## Watchtowers not yet upgraded to Mage or Ballista.
func plain_towers() -> int:
	return stat_int(Stats.EXTRA_TOWERS) - stat_int(Stats.MAGE_TOWERS) - stat_int(Stats.BALLISTA_TOWERS)


func spins_per_day() -> int:
	return stat_int(Stats.SPINS_PER_DAY) + machine.spins_per_day_bonus


# --- Machine style ----------------------------------------------------------

func is_machine_unlocked(style: MachineStyle) -> bool:
	return style.unlock_stat == &"" or stat(style.unlock_stat) >= 1.0


## Every machine the player can pick, in Time Forge order.
func unlocked_machines() -> Array[MachineStyle]:
	var result: Array[MachineStyle] = []
	for style: MachineStyle in machines.values():
		if is_machine_unlocked(style):
			result.append(style)
	result.sort_custom(func(a: MachineStyle, b: MachineStyle) -> bool: return a.order < b.order)
	return result


## The machine picked in the Time Forge, or the standard one if it is locked.
func selected_machine() -> MachineStyle:
	var picked: MachineStyle = machines.get(MetaProgress.selected_machine)
	if picked and is_machine_unlocked(picked):
		return picked
	return machines[MachineStyle.STANDARD_ID]


## The machine unlocked by this Time Forge upgrade, if any.
func machine_unlocked_by(upgrade: UpgradeData) -> MachineStyle:
	for style: MachineStyle in machines.values():
		if style.unlock_stat != &"" and style.unlock_stat == upgrade.stat:
			return style
	return null


## The castle whose conquest unlocks this machine (null = always available).
func machine_castle(style: MachineStyle) -> CastleData:
	for upgrade: UpgradeData in upgrades.values():
		if style.unlock_stat != &"" and upgrade.stat == style.unlock_stat and upgrade.is_castle_reward():
			return upgrade.unlock_castle
	return null


## The machine unlocked by conquering this castle, if any.
func machine_reward(of: CastleData) -> MachineStyle:
	for style: MachineStyle in machines.values():
		if machine_castle(style) == of:
			return style
	return null


## Reward multiplier for a match of `count` reels on the current machine.
## Can be fractional: volatile machines pay less in their base game. Machines
## that can't grow rows turn each row upgrade into ROW_REWARD_BONUS instead.
func match_multiplier(count: int) -> float:
	var multiplier: float = machine.match_multiplier.get(count, 1.0)
	if count == machine.reel_count and machine.top_match_stat != &"":
		multiplier += stat(machine.top_match_stat)
	return multiplier * (1.0 + ROW_REWARD_BONUS * unused_row_upgrades())


## Row upgrades the current machine can't use (fixed or variable rows).
func unused_row_upgrades() -> int:
	if not machine.ignores_row_upgrades():
		return 0
	return stat_int(Stats.MACHINE_ROWS) - int(Stats.BASE[Stats.MACHINE_ROWS])


## Free spins or respins the machine's feature gives.
func feature_length() -> int:
	var bonus := stat_int(machine.length_stat) if machine.length_stat != &"" else 0
	return machine.feature_length + bonus


## Feature symbols needed to start the machine's feature.
func feature_trigger() -> int:
	var ease := stat_int(machine.trigger_stat) if machine.trigger_stat != &"" else 0
	var count := float(machine.feature_count)
	if machine.trigger_scales_with_rows:
		count *= 1.0 + TRIGGER_PER_ROW * (machine_rows - 3)
	return maxi(1, roundi(count) - ease)


## The pattern shapes of the current machine.
func line_table() -> Array:
	return Paylines.table(machine.line_table)


# --- Curse ------------------------------------------------------------------

func add_curse_threat(amount: int) -> void:
	curse_threat += amount
	curse_changed.emit(curse_threat)


## Called when the night starts: the threat has been added to the wave.
func clear_curse_threat() -> void:
	curse_threat = 0
	curse_changed.emit(0)


## Every dawn from the castle's curse night on, more Tombstones appear.
## Returns how many were added.
func spread_curse() -> int:
	if night < castle.curse_start_night + stat_int(Stats.CURSE_DELAY) or castle.curses_per_dawn <= 0:
		return 0
	add_symbol(CURSE_ID, castle.curses_per_dawn)
	return castle.curses_per_dawn


# --- Gold -------------------------------------------------------------------

func add_gold(amount: int) -> void:
	if amount == 0:
		return
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# --- Castle -----------------------------------------------------------------

func damage_castle(amount: float) -> void:
	castle_hp = maxi(0, castle_hp - maxi(1, roundi(amount)))
	castle_hp_changed.emit(castle_hp, castle_max_hp)


func repair_castle(amount: int) -> void:
	castle_hp = mini(castle_max_hp, castle_hp + amount)
	castle_hp_changed.emit(castle_hp, castle_max_hp)


func is_castle_full() -> bool:
	return castle_hp >= castle_max_hp


# --- Slot machine -----------------------------------------------------------

func get_symbol(id: StringName) -> SymbolData:
	return symbols.get(id)


func level_of(id: StringName) -> int:
	return levels.get(id, 1)


## Stat multiplier for troops summoned by this symbol.
func power_for(id: StringName) -> float:
	return (1.0 + LEVEL_POWER_BONUS * (level_of(id) - 1)) * stat(Stats.TROOP_POWER)


func copies_of(id: StringName) -> int:
	return pool.get(id, 0)


func pool_total() -> int:
	var total := 0
	for id: StringName in pool:
		total += pool[id]
	return total


## Chance (0..1) that a given cell shows this symbol.
func chance_of(id: StringName) -> float:
	return float(copies_of(id)) / maxi(1, pool_total())


func add_symbol(id: StringName, copies: int = 1) -> void:
	pool[id] = copies_of(id) + copies
	machine_changed.emit()


## Removes one copy. The last symbol on the reels can never be removed.
func remove_symbol(id: StringName) -> void:
	if copies_of(id) <= 0 or pool_total() <= 1:
		return
	pool[id] -= 1
	if pool[id] <= 0:
		pool.erase(id)
	machine_changed.emit()


func upgrade_symbol(id: StringName) -> void:
	levels[id] = level_of(id) + 1
	machine_changed.emit()


## Every line that pays right now: owned shapes at every height they fit.
func active_paylines() -> Array[Payline]:
	return Paylines.lines_for(line_table(), shapes, machine_rows)


func unlock_shape(shape: int) -> void:
	if shape not in shapes:
		shapes.append(shape)
		machine_changed.emit()


## Next shape the merchant can sell (fits the rows and the castle's tier), or -1.
func next_locked_shape() -> int:
	var table := line_table()
	for shape in table.size():
		if shape in shapes:
			continue
		if Paylines.shape_height(table, shape) <= machine_rows and Paylines.shape_tier(table, shape) <= castle.payline_tier:
			return shape
	return -1


## Can the merchant sell this symbol here? (castle list or Time Forge unlock)
func is_symbol_available(symbol: SymbolData) -> bool:
	if not symbol.in_shop or night < symbol.min_night:
		return false
	if symbol.max_copies > 0 and copies_of(symbol.id) >= symbol.max_copies:
		return false
	if symbol in castle.merchant_symbols or symbol in machine.merchant_symbols:
		return true
	return symbol.unlock_stat != &"" and stat(symbol.unlock_stat) >= 1.0


## Picks a random symbol, weighted by the number of copies on the reels.
func roll_symbol() -> SymbolData:
	var roll := randi() % pool_total()
	for id: StringName in pool:
		roll -= pool[id]
		if roll < 0:
			return symbols[id]
	return symbols[pool.keys()[0]]


func _fill_starting_pool() -> void:
	pool.clear()
	var entries: Array[PoolEntry] = castle.starting_pool + machine.start_symbols
	for entry in entries:
		pool[entry.symbol.id] = copies_of(entry.symbol.id) + entry.copies
	if machine.signature_symbol and machine.signature_stat != &"":
		var extra := stat_int(machine.signature_stat)
		if extra > 0:
			pool[machine.signature_symbol.id] = copies_of(machine.signature_symbol.id) + extra
	var skulls := stat_int(Stats.STARTING_SKULLS)
	if skulls > 0:
		pool[SKULL_ID] = skulls


func _own_starting_shapes() -> void:
	shapes.clear()
	if not machine.uses_lines():
		return
	if machine.all_lines_owned:
		for shape in line_table().size():
			shapes.append(shape)
		return
	shapes.append(Paylines.STRAIGHT)
	for i in stat_int(Stats.START_PAYLINES):
		var shape := next_locked_shape()
		if shape >= 0:
			shapes.append(shape)


## Loads every resource with an `id` property from the given folders.
func _load_resources(dirs: Array) -> Dictionary:
	var result := {}
	for dir: String in dirs:
		for file in ResourceLoader.list_directory(dir):
			if file.ends_with(".tres"):
				var resource := load(dir + file)
				if resource and "id" in resource:
					result[resource.id] = resource
	return result
