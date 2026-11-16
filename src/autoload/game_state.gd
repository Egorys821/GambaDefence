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
const UPGRADE_DIRS := ["res://data/upgrades/meta/", "res://data/upgrades/run/"]
const CASTLES_DIR := "res://data/castles/"
const SKULL_ID := &"skull"
## The cursed symbol the curse spreads every dawn.
const CURSE_ID := &"tombstone"
## Troop hp/damage bonus per symbol level above 1 (0.35 = +35%).
const LEVEL_POWER_BONUS := 0.35

## Every symbol in the game, by id.
var symbols: Dictionary = {}
## Every upgrade in the game (META and RUN), by id.
var upgrades: Dictionary = {}
## Every castle on the map, in map order.
var castles: Array[CastleData] = []
## The castle this run is defending.
var castle: CastleData

var night := 1
var gold := 0
var castle_hp := 0
var castle_max_hp := 0
var machine_rows := 3
## Symbol id -> copies on the reels. More copies = more likely to land.
var pool: Dictionary = {}
## Symbol id -> level (starts at 1).
var levels: Dictionary = {}
## Indices into Paylines.ALL that currently pay out.
var paylines: Array[int] = []
## RUN upgrade id -> level bought this run.
var run_upgrades: Dictionary = {}
var kills := 0
## Threat points added to tonight's wave by cursed symbols.
var curse_threat := 0


func _ready() -> void:
	symbols = _load_resources([SYMBOLS_DIR])
	upgrades = _load_resources(UPGRADE_DIRS)
	for loaded: CastleData in _load_resources([CASTLES_DIR]).values():
		castles.append(loaded)
	castles.sort_custom(func(a: CastleData, b: CastleData) -> bool: return a.order < b.order)
	castle = castles[0]
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
	levels.clear()
	gold = stat_int(Stats.START_GOLD)
	castle_max_hp = stat_int(Stats.CASTLE_MAX_HP)
	castle_hp = castle_max_hp
	machine_rows = stat_int(Stats.MACHINE_ROWS)
	pool.clear()
	for entry in castle.starting_pool:
		pool[entry.symbol.id] = pool.get(entry.symbol.id, 0) + entry.copies
	var skulls := stat_int(Stats.STARTING_SKULLS)
	if skulls > 0:
		pool[SKULL_ID] = skulls
	paylines.assign(Paylines.row_lines(machine_rows))
	for i in stat_int(Stats.START_PAYLINES):
		var line := next_locked_payline()
		if line >= 0:
			paylines.append(line)
	gold_changed.emit(gold)
	castle_hp_changed.emit(castle_hp, castle_max_hp)
	machine_changed.emit()
	upgrades_changed.emit()


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
	var new_rows := stat_int(Stats.MACHINE_ROWS)
	if new_rows != machine_rows:
		machine_rows = new_rows
		for line in Paylines.row_lines(machine_rows):
			if line not in paylines:
				paylines.append(line)
		machine_changed.emit()


## Watchtowers not yet upgraded to Mage or Ballista.
func plain_towers() -> int:
	return stat_int(Stats.EXTRA_TOWERS) - stat_int(Stats.MAGE_TOWERS) - stat_int(Stats.BALLISTA_TOWERS)


func spins_per_day() -> int:
	return stat_int(Stats.SPINS_PER_DAY)


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


func unlock_payline(index: int) -> void:
	if index not in paylines:
		paylines.append(index)
		machine_changed.emit()


## Next payline the merchant can sell (fits the rows and the castle's tier), or -1.
func next_locked_payline() -> int:
	for i in Paylines.ALL.size():
		if i in paylines or Paylines.is_row_line(i):
			continue
		if Paylines.height_of(i) <= machine_rows and Paylines.tier_of(i) <= castle.payline_tier:
			return i
	return -1


## Can the merchant sell this symbol here? (castle list or Time Forge unlock)
func is_symbol_available(symbol: SymbolData) -> bool:
	if not symbol.in_shop or night < symbol.min_night:
		return false
	if symbol in castle.merchant_symbols:
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
