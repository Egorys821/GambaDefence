extends Node
## Unit tests for the slot machine rules and the machine styles: evaluators,
## grid helpers, feature rules, rewards and run setup. Pure logic only, no UI.
## Exits with code 1 if any check fails. Never touches the real save file.
##
## Run from the project root:
##   godot --headless --path . res://tools/debug/rules_test.tscn

var _passed := 0
var _failed: Array[String] = []
var _test := ""


func _ready() -> void:
	MetaProgress.persist = false
	MetaProgress.levels.clear()
	for method in get_method_list():
		var test_name: String = method["name"]
		if test_name.begins_with("test_"):
			_test = test_name
			_use_machine(MachineStyle.STANDARD_ID)
			call(test_name)
	print("\nRules tests: %d passed, %d failed" % [_passed, _failed.size()])
	for failure in _failed:
		print("  FAIL " + failure)
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	get_tree().quit(1 if not _failed.is_empty() else 0)


# --- Line machines ----------------------------------------------------------

func test_line_win_from_left() -> void:
	var grid := _grid(["sword sword sword coin bow", "coin bow coin bow coin", "bow coin bow coin bow"])
	var wins := LineEvaluator.evaluate(grid, _lines(), GameState.machine)
	_check(wins.size() == 1, "one winning line")
	_check(wins[0].symbol.id == &"sword" and wins[0].count == 3, "3 swords on row 1")
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_check(wins[0].cells == expected, "win cells")


func test_wild_never_helps_curse() -> void:
	var grid := _grid(["tombstone rune tombstone coin bow", "coin bow coin bow coin", "bow coin bow coin bow"])
	var wins := LineEvaluator.evaluate(grid, _lines(), GameState.machine)
	_check(wins.is_empty(), "rune does not complete a tombstone line")


func test_group_pays_mixed_weapons() -> void:
	_use_machine(&"old_cellar")
	var grid := _grid(["sword pike helm", "coin bow staff", "bow staff coin"])
	var wins := LineEvaluator.evaluate(grid, _lines(), GameState.machine)
	_check(wins.size() == 1, "mixed melee line wins")
	_check(wins[0].symbol.id == &"helm", "pays as the weakest symbol (helm)")
	var repeat := LineEvaluator.evaluate(_grid(["sword sword pike", "bow coin staff", "bow staff coin"]), _lines(), GameState.machine)
	_check(repeat.is_empty(), "mixed wins need 3 different symbols")
	var wild := LineEvaluator.evaluate(_grid(["sword banner pike", "bow coin staff", "bow staff coin"]), _lines(), GameState.machine)
	_check(wild.is_empty() or wild[0].symbol.id != &"pike" or wild[0].reward_scale == 1.0, "no wilds in mixed wins")


func test_crown_multiplies_line() -> void:
	_use_machine(&"old_cellar")
	var one := LineEvaluator.evaluate(_grid(["sword crown sword", "coin bow staff", "bow staff coin"]), _lines(), GameState.machine)
	_check(one.size() == 1 and one[0].extra_mult == 2, "one crown doubles")
	var two := LineEvaluator.evaluate(_grid(["crown sword crown", "coin bow staff", "bow staff coin"]), _lines(), GameState.machine)
	_check(two.size() == 1 and two[0].extra_mult == 4, "two crowns x4")


func test_consolation_coin_only_on_losing_spin() -> void:
	_use_machine(&"old_cellar")
	var lucky := LineEvaluator.evaluate(_grid(["bow staff holy", "coin bow staff", "staff holy bow"]), _lines(), GameState.machine)
	_check(lucky.size() == 1 and lucky[0].fixed and lucky[0].amount() == GameState.stat_int(Stats.CONSOLATION_GOLD), "lucky coin pays")
	var won := LineEvaluator.evaluate(_grid(["sword sword sword", "coin bow staff", "staff holy bow"]), _lines(), GameState.machine)
	_check(won.size() == 1 and not won[0].fixed, "no lucky coin when the spin already won")


# --- Ways machines ----------------------------------------------------------

func test_ways_counts_combinations() -> void:
	var grid := _columns([["sword", "sword", "coin"], ["sword", "sword", "bow"], ["sword", "sword", "coin"], ["bow", "coin", "coin"]])
	var wins := WaysEvaluator.evaluate(grid, 3)
	var sword := _find(wins, &"sword")
	_check(sword != null and sword.count == 3 and sword.ways == 8, "2 x 2 x 2 = 8 sword ways")
	_check(sword.cells.size() == 6, "every sword cell is part of the win")


func test_ways_with_variable_heights() -> void:
	var grid := _columns([["coin"], ["coin", "bow", "coin"], ["bow", "coin"]])
	var coin := _find(WaysEvaluator.evaluate(grid, 3), &"coin")
	_check(coin != null and coin.ways == 2, "1 x 2 x 1 = 2 ways on uneven reels")


func test_ways_wild_not_for_curse() -> void:
	var grid := _columns([["tombstone"], ["jester"], ["tombstone"]])
	_check(_find(WaysEvaluator.evaluate(grid, 3), &"tombstone") == null, "jester never completes a curse")


func test_jester_turns_on_ways() -> void:
	_use_machine(&"jester_81")
	var plain := _grid(["coin bow sword coin", "bow sword coin bow", "sword coin bow sword"])
	_check(not MachineRules.uses_ways(plain, GameState.machine), "lines without a jester")
	var jester := _grid(["coin bow sword coin", "bow jester coin bow", "sword coin bow sword"])
	_check(MachineRules.uses_ways(jester, GameState.machine), "ways with a jester")
	var wins := MachineRules.evaluate(jester, GameState.machine, GameState.active_paylines())
	var coin := _find(wins, &"coin")
	_check(coin != null and coin.count == 4, "coin pays across 4 reels on any rows")
	_check(_find(wins, &"bow") == null or _find(wins, &"bow").count >= 4, "ways spins pay 4 of a kind only")


# --- Grid helpers -----------------------------------------------------------

func test_collapse_refills_from_top() -> void:
	var grid := _columns([["coin", "sword", "bow"], ["bow", "bow", "bow"]])
	var removed: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 2)]
	var result := GridOps.collapse(grid, removed, _roller(["rune", "rune", "rune"]))
	var new_grid: Array = result["grid"]
	_check(_ids(new_grid[0]) == ["rune", "coin", "bow"], "reel 0: coin falls one row")
	_check(_ids(new_grid[1]) == ["rune", "rune", "bow"], "reel 1: middle bow falls one row")
	_check(result["falls"][0] == [1, 1, 0], "reel 0 falls")
	_check((result["new_cells"] as Array).size() == 3, "three new symbols")


func test_nudge_shifts_one_row() -> void:
	var grid := _columns([["coin", "sword", "bow"], ["bow", "bow", "bow"]])
	var nudged := GridOps.nudge(grid, 0, _sym("rune"))
	_check(_ids(nudged[0]) == ["rune", "coin", "sword"], "reel moved down one row")
	_check(_ids(grid[0]) == ["coin", "sword", "bow"], "original grid untouched")


# --- Features -----------------------------------------------------------------

func test_book_expansion_pays_non_adjacent() -> void:
	var grid := _grid(["coin bow coin bow coin", "bow sword bow sword bow", "sword bow sword bow sword"])
	var win := BookExpansion.evaluate(grid, _sym("coin"), 3, 3)
	_check(win != null and win.count == 3, "coin on reels 1, 3, 5 expands")
	_check(win.cells.size() == 9, "fills 3 whole reels")
	_check(BookExpansion.evaluate(grid, _sym("coin"), 3, 4) == null, "needs 4 reels when min is 4")
	var expanded := BookExpansion.expanded_grid(grid, _sym("coin"))
	_check(_ids(expanded[2]) == ["coin", "coin", "coin"], "expanded reel shows the symbol")


func test_book_expansion_never_picks_specials() -> void:
	for id in ["tome", "tombstone", "skull", "rune", "chest", "jester"]:
		_check(not BookExpansion.is_eligible(_sym(id)), "%s can't expand" % id)
	_check(BookExpansion.is_eligible(_sym("sword")), "sword can expand")


func test_one_scatter_per_reel() -> void:
	_use_machine(&"tome_of_ages")
	var grid := _grid(["tome coin tome coin bow", "tome bow coin bow coin", "bow coin bow coin bow"])
	_check(GameState.machine.feature_symbols_on(grid) == 2, "two tomes on one reel count once")


func test_hoard_respins_reset_and_end() -> void:
	var hoard := HoardRound.new(5, 3, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var prize := func() -> HoardPrize: return HoardPrize.roll(rng, 5, [_sym("sword")])
	hoard.lock(Vector2i(0, 0), prize.call())
	hoard.respin(0.0, rng, prize)
	_check(hoard.respins_left == 2, "a miss uses a respin")
	var landed := hoard.respin(1.0, rng, prize)
	_check(landed.size() == 14 and hoard.is_full() and hoard.is_over(), "chance 1 fills the grid")
	_check(hoard.respins_left == 3, "a new chest resets the respins")
	var wins := hoard.payout(_sym("chest"), 100, HoardPrize.grand([_sym("sword")], rng))
	var gold := 0
	for win in wins:
		gold += win.gold()
		if win.effect() == SymbolData.Effect.SPAWN_UNIT:
			_check(win.amount() <= HoardRound.MAX_TROOPS, "hoard troops capped")
	_check(gold >= HoardPrize.JACKPOTS[HoardPrize.Kind.GRAND][0], "grand gold paid")


func test_free_spin_retriggers_are_capped() -> void:
	_use_machine(&"tome_of_ages")
	var cap := FreeSpinsFeature.MAX_FREE_SPINS
	_check(FreeSpinsFeature.retrigger(2, 1) == 2 + GameState.feature_length(), "retrigger adds spins")
	_check(FreeSpinsFeature.retrigger(5, cap - 3) == 3, "never past the cap")


func test_cascade_chain_multiplier() -> void:
	_check(CascadeFeature.chain_multiplier(1) == 1, "first cascade x1")
	_check(CascadeFeature.chain_multiplier(3) == 1 + 2 * GameState.stat_int(Stats.CASCADE_STEP), "chain grows by the step")


func test_gamble_card_matches_outcome() -> void:
	_check(GambleFeature.card_is_red(0, true) and not GambleFeature.card_is_red(0, false), "red guess")
	_check(not GambleFeature.card_is_red(1, true) and GambleFeature.card_is_red(1, false), "black guess")
	_check(is_equal_approx(GambleFeature.win_chance(), 0.5), "fair gamble without upgrades")


# --- Rewards ------------------------------------------------------------------

func test_reward_caps() -> void:
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var troops := SlotWin.combo(_sym("sword"), 3, 100, cells)
	troops.extra_mult = 10
	_check(troops.amount() == _sym("sword").reward_amount(3, 1) * SlotWin.TROOP_SCALE_CAP, "troops capped")
	var gold := SlotWin.combo(_sym("coin"), 3, 100, cells)
	gold.extra_mult = 100
	_check(gold.amount() == _sym("coin").reward_amount(3, 1) * SlotWin.VALUE_SCALE_CAP, "gold capped")


func test_fractional_multiplier_rounds() -> void:
	_use_machine(&"tome_of_ages")
	_check(_sym("coin").reward_amount(3, 1) == roundi(5 * 0.4), "coin x0.4 rounds")
	_check(_sym("helm").reward_amount(3, 1) >= 1, "troops never round to zero")


# --- Machine setup ------------------------------------------------------------

func test_every_machine_is_consistent() -> void:
	_check(GameState.machines.size() == 6, "six machines")
	for style: MachineStyle in GameState.machines.values():
		for shape: Dictionary in Paylines.table(style.line_table):
			_check(shape["offsets"].size() == style.reel_count, "%s shapes fit its reels" % style.id)
		for count in style.match_counts():
			_check(style.match_multiplier.has(count), "%s pays %d in a row" % [style.id, count])
		if style.unlock_stat != &"":
			var unlock := _upgrade_for(style.unlock_stat)
			_check(unlock != null and unlock.category == UpgradeData.Category.MACHINES, "%s has a Time Forge unlock" % style.id)
			_check(GameState.machine_unlocked_by(unlock) == style, "%s unlock maps back" % style.id)
		if style.feature in [MachineStyle.Feature.FREE_SPINS, MachineStyle.Feature.HOLD_AND_WIN]:
			_check(style.feature_symbol != null, "%s has a feature symbol" % style.id)


func test_every_machine_has_own_upgrades() -> void:
	for style: MachineStyle in GameState.machines.values():
		if style.unlock_stat == &"":
			continue
		var unlock := _upgrade_for(style.unlock_stat)
		var children := 0
		for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
			if upgrade.requires == unlock:
				children += 1
				_check(_is_declared_stat(upgrade.stat), "%s: %s uses a stat declared in Stats" % [style.id, upgrade.id])
		_check(children == 3, "%s has 3 upgrades" % style.id)


func test_locked_machine_falls_back_to_standard() -> void:
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	MetaProgress.selected_machine = &"shifting_halls"
	GameState.start_run(GameState.castles[0])
	_check(GameState.machine.id == MachineStyle.STANDARD_ID, "locked machine is not used")


func test_each_castle_unlocks_the_next_machine() -> void:
	var order: Array[StringName] = [&"old_cellar", &"jester_81", &"dragons_hoard", &"tome_of_ages", &"shifting_halls"]
	for i in order.size():
		_check(GameState.machine_reward(GameState.castles[i]) == GameState.machines[order[i]],
			"castle %d unlocks %s" % [i + 1, order[i]])


func test_machine_unlock_comes_from_conquest_not_shards() -> void:
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	MetaProgress.shards = 9999
	var style: MachineStyle = GameState.machines[&"jester_81"]
	var unlock := _upgrade_for(style.unlock_stat)
	_check(not MetaProgress.can_buy(unlock), "machine unlock can't be bought")
	_check(not GameState.is_machine_unlocked(style), "locked before the conquest")
	MetaProgress.conquered.append(GameState.machine_castle(style).id)
	_check(GameState.is_machine_unlocked(style), "unlocked after conquering its castle")
	_check(MetaProgress.level_of(unlock.id) == 1, "unlock node counts as owned")
	_check(GameState.prerequisites_met(GameState.upgrades[&"jester_troupe"]), "its upgrades open up")
	_check(MetaProgress.refund_upgrades() == 0, "nothing to refund for a castle reward")
	_check(GameState.is_machine_unlocked(style), "refunds keep conquest unlocks")
	MetaProgress.shards = 0


func test_run_setup_per_machine() -> void:
	_use_machine(&"jester_81")
	_check(GameState.machine_rows == 3, "jester has fixed 3 rows")
	_check(GameState.copies_of(&"jester") == 1, "starts with a jester")
	_check(GameState.active_paylines().size() == 3, "starts with the 3 straight rows")
	_check(GameState.next_locked_shape() > 0, "merchant sells jester patterns")
	_use_machine(&"shifting_halls")
	_check(GameState.active_paylines().is_empty(), "ways machine has no lines")
	_check(GameState.next_locked_shape() < 0, "no patterns for sale")
	_use_machine(&"dragons_hoard")
	_check(GameState.copies_of(&"chest") == 2, "hoard starts with chests")
	_check(GameState.is_symbol_available(_sym("chest")), "merchant sells chests here")


func test_merchant_stops_at_max_copies() -> void:
	_use_machine(&"jester_81")
	var jester := _sym("jester")
	_check(GameState.is_symbol_available(jester), "jester sold below the cap")
	GameState.add_symbol(jester.id, jester.max_copies - GameState.copies_of(jester.id))
	_check(not GameState.is_symbol_available(jester), "no more jesters at the cap")


func test_fixed_rows_turn_row_upgrades_into_rewards() -> void:
	var row: UpgradeData = GameState.upgrades[&"extra_row"]
	_use_machine(&"jester_81", {row.id: 1})
	_check(GameState.machine_rows == 3, "jester keeps 3 rows")
	_check(is_equal_approx(GameState.match_multiplier(3), 0.6 * (1.0 + GameState.ROW_REWARD_BONUS)), "row upgrade boosts rewards")
	_use_machine(MachineStyle.STANDARD_ID, {row.id: 1})
	_check(GameState.machine_rows == 4 and is_equal_approx(GameState.match_multiplier(3), 1.0), "standard gets the row instead")


func test_hoard_needs_more_chests_on_taller_reels() -> void:
	_use_machine(&"dragons_hoard")
	_check(GameState.feature_trigger() == 6, "6 chests on 3 rows")
	GameState.machine_rows = 5
	_check(GameState.feature_trigger() == roundi(6 * (1.0 + 2 * GameState.TRIGGER_PER_ROW)), "more chests on 5 rows")


func test_signature_upgrade_adds_copies() -> void:
	var troupe: UpgradeData = GameState.upgrades[&"jester_troupe"]
	_use_machine(&"jester_81", {troupe.id: 1})
	_check(GameState.copies_of(&"jester") == 2, "troupe adds a jester")
	_use_machine(&"tome_of_ages", {&"tome_chapter": 1})
	_check(GameState.feature_length() == 4, "long chapter adds a free spin")


# --- Helpers ------------------------------------------------------------------

## Unlocks and starts a run on a machine, with optional extra upgrade levels.
func _use_machine(id: StringName, extra_levels: Dictionary = {}) -> void:
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	var style: MachineStyle = GameState.machines[id]
	var castle := GameState.machine_castle(style)
	if castle:
		MetaProgress.conquered.append(castle.id)
	for upgrade_id: StringName in extra_levels:
		MetaProgress.levels[upgrade_id] = extra_levels[upgrade_id]
	MetaProgress.selected_machine = id
	GameState.start_run(GameState.castles[0])


func _upgrade_for(stat: StringName) -> UpgradeData:
	for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
		if upgrade.stat == stat:
			return upgrade
	return null


func _is_declared_stat(stat: StringName) -> bool:
	return stat in (load("res://src/data/stats.gd") as Script).get_script_constant_map().values()


func _lines() -> Array[Payline]:
	return GameState.active_paylines()


func _sym(id: String) -> SymbolData:
	var symbol := GameState.get_symbol(StringName(id))
	assert(symbol != null, "unknown symbol " + id)
	return symbol


## Grid from rows of space-separated ids (top row first).
func _grid(rows: Array) -> Array:
	var columns := []
	for row: String in rows:
		var ids := row.split(" ")
		for reel in ids.size():
			if columns.size() <= reel:
				columns.append([])
			columns[reel].append(ids[reel])
	return _columns(columns)


## Grid from reels of ids (top first).
func _columns(reels: Array) -> Array:
	var grid := []
	for reel: Array in reels:
		grid.append(reel.map(func(id: String) -> SymbolData: return _sym(id)))
	return grid


func _ids(column: Array) -> Array:
	return column.map(func(symbol: SymbolData) -> String: return String(symbol.id))


func _roller(ids: Array) -> Callable:
	var queue := ids.duplicate()
	return func() -> SymbolData: return _sym(queue.pop_front())


func _find(wins: Array[SlotWin], id: StringName) -> SlotWin:
	for win in wins:
		if win.symbol.id == id:
			return win
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed.append("%s: %s" % [_test, label])
