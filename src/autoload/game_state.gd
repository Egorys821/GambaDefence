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
## A rule the player should learn about happened (main.gd shows its popup once):
## &"empty_slots" or &"hunger".
signal mechanic_triggered(id: StringName)

const SYMBOLS_DIR := "res://data/symbols/"
const UPGRADE_DIRS := ["res://data/upgrades/meta/", "res://data/upgrades/merchant/"]
const CASTLES_DIR := "res://data/castles/"
const MACHINES_DIR := "res://data/machines/"
const SKULL_ID := &"skull"
## The cursed symbol the curse spreads every dawn.
const CURSE_ID := &"tombstone"
## Blank symbol filling the reels when they hold fewer symbols than the machine has cells.
const EMPTY_SLOT_ID := &"empty_slot"
## Trading Post "Remove" stops at this many symbols (or the cell count, if smaller).
const MIN_KEPT_SYMBOLS := 10
## Below this many symbols the machine hungers: every spin adds spirits tonight...
const HUNGER_BELOW := 10
## ...this many for each missing symbol.
const HUNGER_PER_MISSING := 2
## Sometimes the curse spreads a Cursed Coin instead of a Tombstone.
const CURSED_COIN_ID := &"cursed_coin"
const CURSED_COIN_CHANCE := 0.35
## From this night on, every dawn spreads at least this many cursed symbols.
const LATE_CURSE_NIGHT := 5
const LATE_CURSES_PER_DAWN := 2
## Troop hp/damage bonus per symbol level above 1 (0.35 = +35%).
const LEVEL_POWER_BONUS := 0.35
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
## Greed Monsters (and other win_spirit spirits) joining tonight's wave.
var greed_spirits := 0
## Symbols on the reels when this run began (Empty Slots never go above it).
var start_symbols := 0
## Rarity tokens left in the merchant's hidden bag (see MerchantRarity).
var merchant_bag: Array[int] = []
## The merchant's Trading Post was bought this run (see TradeRules).
var trade_unlocked := false
## The results screen's "Upgrade Tree" button: open the Time Forge right after
## the scene reloads (main.gd clears it).
var open_forge_next := false


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
	greed_spirits = 0
	run_upgrades.clear()
	merchant_bag.clear()
	trade_unlocked = stat(Stats.TRADE_CHARTER) >= 1.0
	levels.clear()
	gold = stat_int(Stats.START_GOLD)
	castle_max_hp = stat_int(Stats.CASTLE_MAX_HP)
	castle_hp = castle_max_hp
	machine = selected_machine()
	machine_rows = machine.rows_for(stat_int(Stats.MACHINE_ROWS))
	_fill_starting_pool()
	start_symbols = pool_total()
	_level_starting_troops()
	_own_starting_shapes()
	gold_changed.emit(gold)
	castle_hp_changed.emit(castle_hp, castle_max_hp)
	machine_changed.emit()
	upgrades_changed.emit()


## Takes one rarity token out of the merchant's bag, refilling it when empty.
## Merchant luck (Time Forge) adds better tokens to every new bag.
func draw_merchant_rarity() -> int:
	if merchant_bag.is_empty():
		var luck := stat_int(Stats.MERCHANT_LUCK)
		merchant_bag = MerchantRarity.new_bag({
			MerchantRarity.Tier.RARE: 2 * luck,
			MerchantRarity.Tier.MYTHIC: luck,
			MerchantRarity.Tier.LEGENDARY: stat_int(Stats.LEGENDARY_LUCK),
		})
	return merchant_bag.pop_back()


# --- Stats ------------------------------------------------------------------

## Effective value of a stat: base + permanent upgrades + this run's upgrades.
func stat(key: StringName) -> float:
	var value: float = Stats.BASE.get(key, 0.0)
	for upgrade: UpgradeData in upgrades.values():
		if upgrade.stat == key and applies(upgrade):
			value += upgrade.value_per_level * upgrade_level(upgrade)
	if Stats.LIMITS.has(key):
		var limit: Vector2 = Stats.LIMITS[key]
		value = clampf(value, limit.x, limit.y)
	return value


## False for an upgrade that belongs to another machine than the one in use.
func applies(upgrade: UpgradeData) -> bool:
	if upgrade.machine == &"":
		return true
	var current := machine if machine else selected_machine()
	return current.id == upgrade.machine


func stat_int(key: StringName) -> int:
	return roundi(stat(key))


func upgrade_level(upgrade: UpgradeData) -> int:
	if upgrade.scope == UpgradeData.Scope.META:
		return MetaProgress.level_of(upgrade.id)
	return run_upgrades.get(upgrade.id, 0)


## Parent upgrade owned (tree), its castle conquered and, for tower
## conversions, a plain tower to convert.
func prerequisites_met(upgrade: UpgradeData) -> bool:
	if upgrade.requires and upgrade_level(upgrade.requires) < upgrade.requires_level:
		return false
	if upgrade.requires_castle and not MetaProgress.is_conquered(upgrade.requires_castle):
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


## The machine unlocked by this Time Forge upgrade (or that the node stands
## for, like the Gamba Machine's), if any.
func machine_unlocked_by(upgrade: UpgradeData) -> MachineStyle:
	if upgrade.is_machine_node():
		return machines.get(upgrade.machine)
	for style: MachineStyle in machines.values():
		if style.unlock_stat != &"" and style.unlock_stat == upgrade.stat:
			return style
	return null


## The machine's node in the Time Forge: its unlock, or its own node.
func machine_node(style: MachineStyle) -> UpgradeData:
	var unlock := machine_unlock(style)
	if unlock:
		return unlock
	for upgrade: UpgradeData in upgrades.values():
		if upgrade.is_machine_node() and upgrade.machine == style.id:
			return upgrade
	return null


## The Time Forge node that unlocks this machine (null = always available).
func machine_unlock(style: MachineStyle) -> UpgradeData:
	for upgrade: UpgradeData in upgrades.values():
		if style.unlock_stat != &"" and upgrade.stat == style.unlock_stat:
			return upgrade
	return null


## The castle that must be conquered before this machine can be bought (null = none).
func machine_castle(style: MachineStyle) -> CastleData:
	var unlock := machine_unlock(style)
	return unlock.requires_castle if unlock else null


## The machine that conquering this castle lets you buy, if any.
func machine_reward(of: CastleData) -> MachineStyle:
	for style: MachineStyle in machines.values():
		if machine_castle(style) == of:
			return style
	return null


## Reward multiplier for a match of `count` reels on the current machine.
## Can be fractional: volatile machines pay less in their base game.
func match_multiplier(count: int) -> float:
	var multiplier: float = machine.match_multiplier.get(count, 1.0)
	if count == machine.reel_count and machine.top_match_stat != &"":
		multiplier += stat(machine.top_match_stat)
	return multiplier


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


## A winning line through a Cursed Coin: one more Greed Monster tonight.
func add_greed(amount: int = 1) -> void:
	greed_spirits += amount
	curse_changed.emit(curse_threat)


## Called when the night starts: the threat has been added to the wave.
func clear_curse_threat() -> void:
	curse_threat = 0
	greed_spirits = 0
	curse_changed.emit(0)


## Every dawn from the castle's curse night on, more cursed symbols appear:
## the castle's Tombstone, or sometimes a Cursed Coin. Returns what was added.
func spread_curse() -> Array[SymbolData]:
	var added: Array[SymbolData] = []
	if night < castle.curse_start_night + stat_int(Stats.CURSE_DELAY) or castle.curses_per_dawn <= 0:
		return added
	var count := castle.curses_per_dawn
	if night >= LATE_CURSE_NIGHT:
		count = maxi(count, LATE_CURSES_PER_DAWN)  # the curse grows late in the run
	for i in count:
		var coin := get_symbol(CURSED_COIN_ID)
		var symbol := coin if coin and randf() < CURSED_COIN_CHANCE else curse_symbol()
		add_symbol(symbol.id)
		added.append(symbol)
	return added


## The cursed symbol this castle's curse spreads.
func curse_symbol() -> SymbolData:
	return castle.curse_symbol if castle.curse_symbol else get_symbol(CURSE_ID)


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

## Castle armor (Time Forge) blocks part of every hit.
func damage_castle(amount: float) -> void:
	amount *= 1.0 - stat(Stats.CASTLE_ARMOR)
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
# --- Thin reels ----------------------------------------------------------------

## Cells on this machine's grid (variable-row machines count their average height).
func reel_slots() -> int:
	var rows := machine_rows
	if machine.variable_rows:
		rows = roundi((machine.min_rows + stat_int(machine.min_rows_stat) + machine.max_rows) * 0.5) \
			if machine.min_rows_stat != &"" else roundi((machine.min_rows + machine.max_rows) * 0.5)
	return machine.reel_count * rows


## Symbols the reels should hold: the machine's cells, but never more than the
## run started with (a fresh run has no Empty Slots).
func slot_target() -> int:
	return mini(reel_slots(), start_symbols) if start_symbols > 0 else reel_slots()


## Empty Slots on the reels: one for every missing symbol below slot_target().
func empty_slots() -> int:
	return maxi(0, slot_target() - pool_total())


## Fewest symbols the Trading Post leaves on the reels.
func min_kept_symbols() -> int:
	return mini(MIN_KEPT_SYMBOLS, reel_slots())


## Spirits every spin adds tonight because the reels are too thin (0 = fine).
func hunger() -> int:
	return maxi(0, mini(HUNGER_BELOW, reel_slots()) - pool_total()) * HUNGER_PER_MISSING


## Copies shown for a symbol, counting the Empty Slots.
func reel_copies(id: StringName) -> int:
	return empty_slots() if id == EMPTY_SLOT_ID else copies_of(id)


## Static-chance symbols (special symbols) take a fixed share of every cell;
## the rest is shared by the others (and the Empty Slots) by their copies.
func chance_of(id: StringName) -> float:
	var symbol := get_symbol(id)
	if symbol == null or reel_copies(id) <= 0:
		return 0.0
	var static_share := _static_share()
	if symbol.static_chance > 0.0:
		return _static_weight(id) * _static_scale(static_share)
	var normal := _normal_copies() + empty_slots()
	return (1.0 - static_share) * reel_copies(id) / maxf(1.0, normal)


## Another machine's special symbol can never be added (see is_other_machine_symbol).
func add_symbol(id: StringName, copies: int = 1) -> void:
	var symbol := get_symbol(id)
	if symbol and is_other_machine_symbol(symbol):
		return
	if symbol and symbol.max_copies > 0:
		copies = mini(copies, symbol.max_copies - copies_of(id))  # e.g. at most 1 Magic Rune a run
		if copies <= 0:
			return
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


## Special symbol of another slot machine (Crown, Jester, Hoard chest, Tome):
## listed in some machine's start or merchant symbols, but not this machine's.
## These only ever appear while playing their own machine. Shared symbols
## (e.g. the Magic Rune, a general Time Forge unlock) are not special.
func is_other_machine_symbol(symbol: SymbolData) -> bool:
	if _machine_uses(machine, symbol):
		return false
	for style: MachineStyle in machines.values():
		if style != machine and _machine_uses(style, symbol):
			return true
	return false


## A slot machine's own special symbol (Crown, Jester, Treasure Chest, Tome):
## part of some machine's starting reels, merchant list or feature. The
## merchant sells a special symbol only while playing its own machine (up to
## max_copies); special symbols can't be upgraded, traded or removed, and they
## land with a fixed chance (SymbolData.static_chance).
func is_special_symbol(symbol: SymbolData) -> bool:
	for style: MachineStyle in machines.values():
		if style.feature_symbol == symbol or _machine_uses(style, symbol):
			return true
	return false


func _machine_uses(style: MachineStyle, symbol: SymbolData) -> bool:
	if symbol in style.merchant_symbols:
		return true
	for entry in style.start_symbols:
		if entry.symbol == symbol:
			return true
	return false


## Can the merchant sell this symbol here? (castle list or Time Forge unlock)
func is_symbol_available(symbol: SymbolData) -> bool:
	if not symbol.in_shop or night < symbol.min_night or is_other_machine_symbol(symbol):
		return false
	if symbol.max_copies > 0 and copies_of(symbol.id) >= symbol.max_copies:
		return false
	if is_special_symbol(symbol):
		return _machine_uses(machine, symbol)  # only this machine's own special symbol
	if symbol in castle.merchant_symbols or symbol in machine.merchant_symbols:
		return true
	return symbol.unlock_stat != &"" and stat(symbol.unlock_stat) >= 1.0


## Picks a random symbol, weighted by the number of copies on the reels.
func roll_symbol() -> SymbolData:
	var static_share := _static_share()
	var roll := randf()
	if roll < static_share:
		# A special symbol, picked by its own fixed chance.
		var scale := _static_scale(static_share)
		for id: StringName in pool:
			var weight := _static_weight(id) * scale
			if weight <= 0.0:
				continue
			roll -= weight
			if roll < 0.0:
				return symbols[id]
	var empty := empty_slots()
	var normal := _normal_copies()
	if normal + empty <= 0:
		return symbols[pool.keys()[0]]
	var pick := randi() % (normal + empty)
	if pick >= normal:
		return symbols[EMPTY_SLOT_ID]  # thin reels spin blanks
	for id: StringName in pool:
		if (symbols[id] as SymbolData).static_chance > 0.0:
			continue
		pick -= pool[id]
		if pick < 0:
			return symbols[id]
	return symbols[pool.keys()[0]]


## Most of a cell's chance the static symbols can take together.
const MAX_STATIC_SHARE := 0.6


func _static_weight(id: StringName) -> float:
	return (symbols[id] as SymbolData).static_chance * copies_of(id)


func _static_share() -> float:
	var total := 0.0
	for id: StringName in pool:
		total += _static_weight(id)
	if _normal_copies() + empty_slots() <= 0:
		return 1.0 if total > 0.0 else 0.0
	return minf(total, MAX_STATIC_SHARE)


## Scales static weights down when they add up to more than MAX_STATIC_SHARE
## (or up to 1 when nothing else is on the reels).
func _static_scale(static_share: float) -> float:
	var total := 0.0
	for id: StringName in pool:
		total += _static_weight(id)
	return static_share / total if total > 0.0 else 0.0


func _normal_copies() -> int:
	var total := 0
	for id: StringName in pool:
		if (symbols[id] as SymbolData).static_chance <= 0.0:
			total += pool[id]
	return total


func _fill_starting_pool() -> void:
	pool.clear()
	var entries: Array[PoolEntry] = castle.starting_pool + machine.start_symbols
	for entry in entries:
		if not is_other_machine_symbol(entry.symbol):
			pool[entry.symbol.id] = copies_of(entry.symbol.id) + entry.copies
	if machine.signature_symbol and machine.signature_stat != &"":
		var extra := stat_int(machine.signature_stat)
		if extra > 0:
			pool[machine.signature_symbol.id] = copies_of(machine.signature_symbol.id) + extra
	var skulls := stat_int(Stats.STARTING_SKULLS)
	if skulls > 0:
		pool[SKULL_ID] = skulls


## Elite Training (Time Forge): troop symbols you start with begin above level 1.
func _level_starting_troops() -> void:
	var bonus := stat_int(Stats.TROOP_START_LEVEL)
	if bonus <= 0:
		return
	for id: StringName in pool:
		var symbol := get_symbol(id)
		if symbol and symbol.effect == SymbolData.Effect.SPAWN_UNIT:
			levels[id] = 1 + bonus


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
