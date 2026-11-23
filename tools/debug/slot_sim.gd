extends Node
## Balance simulator: spins every machine style many times with the pure rules
## (MachineRules, GridOps, BookExpansion, HoardRound...) and prints the
## average value per daily spin. Use it to keep machines within ~15% of the
## standard machine (see docs/SLOT_MACHINE_STYLES.md, "Balancing tool").
##
## Run from the project root:
##   godot --headless --path . res://tools/debug/slot_sim.tscn -- --spins=20000
## Flags:
##   --spins=N      spins per machine (default 20000)
##   --machine=ID   only this machine
##   --castle=N     starting reels of this castle (default 1), or "all"
##   --night=N      grow the reels as a run would by night N: the merchant adds
##                  2 symbols a day, the curse spreads, 1 junk symbol is banished
##   --upgrades     max out the Time Forge slot upgrades: the shared ones and
##                  each machine's own branch
##   --upgrades=shared / --upgrades=branch
##                  only the shared reel upgrades / only the machine's branch
##   --without=a,b  leave these upgrade ids at level 0 (with --upgrades)
## Never touches the real save file.

## How much one troop / one HP is worth in gold, for the value column.
## Curse threat is shown on its own: it grows with the cells on the reels.
const TROOP_VALUE := 3.0
const REPAIR_VALUE := 0.3
## Reels are regrown (a new random run) every this many spins.
const SPINS_PER_RUN := 100
const BUYS_PER_DAY := 2

var _spins := 20000
var _only := &""
var _castles: Array[int] = [1]
var _night := 1
var _upgrades := false
var _shared := true
var _branch := true
var _without: PackedStringArray = []
var _standard_value := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spins="):
			_spins = int(arg.get_slice("=", 1))
		elif arg.begins_with("--machine="):
			_only = StringName(arg.get_slice("=", 1))
		elif arg == "--upgrades":
			_upgrades = true
		elif arg.begins_with("--upgrades="):
			_upgrades = true
			_shared = arg.get_slice("=", 1) == "shared"
			_branch = arg.get_slice("=", 1) == "branch"
		elif arg.begins_with("--without="):
			_without = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--night="):
			_night = int(arg.get_slice("=", 1))
		elif arg == "--castle=all":
			_castles.assign(range(1, GameState.castles.size() + 1))
		elif arg.begins_with("--castle="):
			_castles.assign([int(arg.get_slice("=", 1))])
	MetaProgress.persist = false
	for castle in _castles:
		print("
%s, night %d%s" % [GameState.castles[castle - 1].display_name, _night, ", upgrades maxed" if _upgrades else ""])
		print("%-16s %7s %6s %7s %7s %7s %7s %6s %7s %7s %7s" % [
			"machine", "value", "vs std", "gold", "troops", "repair", "threat", "hit%", "feat%", "p99", "max"])
		for style in _sorted_machines():
			if _only == &"" or style.id == _only or style.id == MachineStyle.STANDARD_ID:
				_report(style, _simulate(style, castle))
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	get_tree().quit()


func _sorted_machines() -> Array[MachineStyle]:
	var styles: Array[MachineStyle] = []
	styles.assign(GameState.machines.values())
	styles.sort_custom(func(a: MachineStyle, b: MachineStyle) -> bool: return a.order < b.order)
	return styles


func _simulate(style: MachineStyle, castle: int) -> Dictionary:
	_setup_progress(style)
	var totals := {"gold": 0.0, "troops": 0.0, "repair": 0.0, "threat": 0.0, "hits": 0, "features": 0, "spins_per_day": 0.0}
	var values: Array[float] = []
	for i in _spins:
		if i % SPINS_PER_RUN == 0:
			GameState.start_run(GameState.castles[castle - 1])
			_grow_pool(_night)
		var spin := _spin_once()
		for key in ["gold", "troops", "repair", "threat"]:
			totals[key] += spin[key]
		totals["hits"] += 1 if spin["hit"] else 0
		totals["features"] += 1 if spin["feature"] else 0
		values.append(_value(spin))
	totals["spins_per_day"] = GameState.spins_per_day()
	values.sort()
	totals["p99"] = values[int(values.size() * 0.99)]
	totals["max"] = values[-1]
	return totals


## Unlocks and picks the machine; with --upgrades also maxes slot upgrades.
func _setup_progress(style: MachineStyle) -> void:
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	var castle := GameState.machine_castle(style)
	if castle:
		MetaProgress.conquered.append(castle.id)
	var unlock := GameState.machine_unlock(style)
	if unlock:
		MetaProgress.levels[unlock.id] = 1
	if _upgrades:
		for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
			if String(upgrade.id) in _without:
				continue
			var shared := _shared and upgrade.category == UpgradeData.Category.MACHINE
			var root := GameState.machine_node(style)  # the Gamba Machine has a node but no unlock
			if shared or (_branch and root != null and _in_branch(upgrade, root)):
				MetaProgress.levels[upgrade.id] = upgrade.max_level
	MetaProgress.selected_machine = style.id


## The upgrade sits below `root` in the tree (a machine's own branch).
func _in_branch(upgrade: UpgradeData, root: UpgradeData) -> bool:
	var parent := upgrade.requires
	while parent:
		if parent == root:
			return true
		parent = parent.requires
	return false


## Plays the merchant and the curse up to `night`: 2 random symbols bought a
## day, the curse spreads at dawn, 1 junk or cursed symbol banished a day.
func _grow_pool(night: int) -> void:
	for day in range(1, night):
		GameState.night = day
		var offers := GameState.symbols.values().filter(func(symbol: SymbolData) -> bool:
			return GameState.is_symbol_available(symbol))
		for i in BUYS_PER_DAY:
			if not offers.is_empty():
				GameState.add_symbol((offers.pick_random() as SymbolData).id)
		_banish_one()
		GameState.night = day + 1
		GameState.spread_curse()
	GameState.night = night


func _banish_one() -> void:
	for id in [GameState.CURSE_ID, GameState.SKULL_ID]:
		if GameState.copies_of(id) > 0:
			GameState.remove_symbol(id)
			return


## One daily spin including its feature. Returns gold, troops, repair, threat.
func _spin_once() -> Dictionary:
	var style := GameState.machine
	var result := {"gold": 0.0, "troops": 0.0, "repair": 0.0, "threat": 0.0, "hit": false, "feature": false}
	var grid := _roll()
	_add_passives(result, grid, GridOps.all_cells(grid))
	var wins := _evaluate(grid)
	_add_wins(result, wins)
	result["hit"] = not wins.is_empty()
	match style.feature:
		MachineStyle.Feature.NUDGE:
			if wins.is_empty() and randf() < GameState.stat(Stats.NUDGE_CHANCE):
				_add_wins(result, _best_nudge(grid))
		MachineStyle.Feature.FREE_SPINS:
			result["feature"] = _free_spins(result, grid)
		MachineStyle.Feature.HOLD_AND_WIN:
			result["feature"] = _hoard(result, grid)
		MachineStyle.Feature.CASCADE:
			result["feature"] = _cascade(result, grid, wins)
	return result


func _roll() -> Array:
	var style := GameState.machine
	var bonus := GameState.stat_int(style.min_rows_stat) if style.min_rows_stat != &"" else 0
	return GridOps.roll(MachineRules.roll_heights(style, GameState.machine_rows, bonus), GameState.roll_symbol)


func _evaluate(grid: Array) -> Array[SlotWin]:
	return MachineRules.evaluate(grid, GameState.machine, GameState.active_paylines())


func _best_nudge(grid: Array) -> Array[SlotWin]:
	var top := GameState.roll_symbol()
	var best: Array[SlotWin] = []
	var best_value := 0.0
	for reel in grid.size():
		var wins := _evaluate(GridOps.nudge(grid, reel, top))
		var probe := {"gold": 0.0, "troops": 0.0, "repair": 0.0, "threat": 0.0}
		_add_wins(probe, wins)
		if _value(probe) > best_value:
			best_value = _value(probe)
			best = wins
	return best


func _free_spins(result: Dictionary, grid: Array) -> bool:
	var scatter := GameState.machine.feature_symbol
	var trigger := GameState.feature_trigger()
	var count := GameState.machine.feature_symbols_on(grid)
	if count < trigger:
		return false
	result["gold"] += FreeSpinsFeature.scatter_gold(scatter, count)
	var pool := []
	for id: StringName in GameState.pool:
		pool.append(GameState.get_symbol(id))
	var symbol := BookExpansion.pick_symbol(pool)
	var min_reels := BookExpansion.MIN_REELS - GameState.stat_int(Stats.EXPAND_EASE)
	var spins_left := GameState.feature_length()
	var played := 0
	while spins_left > 0:
		spins_left -= 1
		played += 1
		var free_grid := _roll()
		_add_passives(result, free_grid, GridOps.all_cells(free_grid))
		_add_wins(result, _evaluate(free_grid))
		if symbol:
			var expansion := BookExpansion.evaluate(free_grid, symbol, GameState.active_paylines().size(), min_reels)
			if expansion:
				_add_wins(result, [expansion])
		var scatters := GameState.machine.feature_symbols_on(free_grid)
		if scatters >= trigger:
			result["gold"] += FreeSpinsFeature.scatter_gold(scatter, scatters)
			spins_left = FreeSpinsFeature.retrigger(spins_left, played)
	return true


func _hoard(result: Dictionary, grid: Array) -> bool:
	var chest := GameState.machine.feature_symbol
	var start := GridOps.cells_of(grid, chest)
	if start.size() < GameState.feature_trigger():
		return false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var units := HoardFeature._unit_symbols()
	var coin_power := HoardFeature._coin_power()
	var roll_prize := func() -> HoardPrize: return HoardPrize.roll(rng, coin_power, units)
	var hoard := HoardRound.new(grid.size(), GameState.machine_rows, GameState.feature_length())
	for cell in start:
		hoard.lock(cell, roll_prize.call())
	while not hoard.is_over():
		hoard.respin(hoard.chest_chance(), rng, roll_prize)
	var grand := HoardPrize.grand(units, rng) if hoard.is_full() else null
	_add_wins(result, hoard.payout(chest, GameState.castle_max_hp, grand, GameState.stat(Stats.HOARD_GOLD_BONUS)))
	return true


func _cascade(result: Dictionary, grid: Array, wins: Array[SlotWin]) -> bool:
	var current := wins
	var chain := 0
	while not current.is_empty() and chain < CascadeFeature.MAX_CASCADES:
		chain += 1
		var collapsed := GridOps.collapse(grid, CascadeFeature.winning_cells(current), GameState.roll_symbol)
		grid = collapsed["grid"]
		_add_passives(result, grid, collapsed["new_cells"])
		current = _evaluate(grid)
		for win in current:
			win.extra_mult *= CascadeFeature.chain_multiplier(chain)
		_add_wins(result, current)
	return chain >= 2


func _add_wins(result: Dictionary, wins: Array) -> void:
	for win: SlotWin in wins:
		match win.effect():
			SymbolData.Effect.GOLD, SymbolData.Effect.WILD:
				result["gold"] += win.amount()
			SymbolData.Effect.SPAWN_UNIT:
				result["troops"] += win.amount()
			SymbolData.Effect.REPAIR:
				result["repair"] += win.amount()
			SymbolData.Effect.CURSE:
				result["threat"] += win.amount()


func _add_passives(result: Dictionary, grid: Array, cells: Array[Vector2i]) -> void:
	for cell in cells:
		var symbol: SymbolData = grid[cell.x][cell.y]
		result["gold"] += symbol.passive_gold
		result["threat"] += symbol.passive_threat


func _value(spin: Dictionary) -> float:
	return spin["gold"] + spin["troops"] * TROOP_VALUE + spin["repair"] * REPAIR_VALUE


func _report(style: MachineStyle, totals: Dictionary) -> void:
	var n := float(_spins)
	# Value per spin, scaled so machines with extra daily spins compare fairly.
	var day_value: float = (totals["gold"] + totals["troops"] * TROOP_VALUE + totals["repair"] * REPAIR_VALUE) 		/ n * totals["spins_per_day"] / float(Stats.BASE[Stats.SPINS_PER_DAY])
	if style.id == MachineStyle.STANDARD_ID:
		_standard_value = day_value
	var ratio := day_value / _standard_value if _standard_value > 0.0 else 1.0
	print("%-16s %7.2f %5d%% %7.2f %7.2f %7.2f %7.2f %6.1f %7.2f %7.1f %7.1f" % [
		style.id, day_value, roundi(ratio * 100.0), totals["gold"] / n, totals["troops"] / n, totals["repair"] / n,
		totals["threat"] / n, 100.0 * totals["hits"] / n, 100.0 * totals["features"] / n, totals["p99"], totals["max"]])
