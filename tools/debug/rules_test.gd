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


func test_rune_helps_curses_other_wilds_dont() -> void:
	var grid := _grid(["tombstone rune tombstone coin bow", "coin bow coin bow coin", "bow coin bow coin bow"])
	var wins := LineEvaluator.evaluate(grid, _lines(), GameState.machine)
	_check(wins.size() == 1 and wins[0].symbol.id == &"tombstone" and wins[0].count == 3, "the rune completes a tombstone line")
	var purple := LineEvaluator.evaluate(_grid(["purple_tombstone purple_tombstone rune coin bow", "coin bow coin bow coin", "bow coin bow coin bow"]), _lines(), GameState.machine)
	_check(purple.size() == 1 and purple[0].symbol.id == &"purple_tombstone", "the rune completes a purple tombstone line")
	var banner := LineEvaluator.evaluate(_grid(["tombstone banner tombstone coin bow", "coin bow coin bow coin", "bow coin bow coin bow"]), _lines(), GameState.machine)
	_check(banner.is_empty(), "other wilds never complete a curse")


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
	_check(gold >= HoardPrize.JACKPOTS[HoardPrize.Kind.GRAND][0] * HoardRound.PAYOUT_SCALE, "grand gold paid (at half pay)")


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
		_check(unlock == GameState.machine_unlock(style) and unlock.is_crown_node(), "%s is bought with crowns" % style.id)
		# Its branch is a chain below the unlock node, in the same column.
		var branch := 0
		for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
			var parent := upgrade.requires
			while parent and parent != unlock:
				parent = parent.requires
			if parent == unlock:
				branch += 1
				_check(_is_declared_stat(upgrade.stat), "%s: %s uses a stat declared in Stats" % [style.id, upgrade.id])
				_check(upgrade.tree_position.x == unlock.tree_position.x, "%s sits under its machine" % upgrade.id)
		_check(branch == 3, "%s has 3 upgrades" % style.id)


func test_locked_machine_falls_back_to_standard() -> void:
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	MetaProgress.selected_machine = &"shifting_halls"
	GameState.start_run(GameState.castles[0])
	_check(GameState.machine.id == MachineStyle.STANDARD_ID, "locked machine is not used")


func test_each_castle_unlocks_the_next_machine() -> void:
	# Castle number (1 = first) -> machine it opens for crowns; the others open none.
	var rewards := {1: &"old_cellar", 3: &"jester_81", 5: &"dragons_hoard", 7: &"tome_of_ages", 9: &"shifting_halls"}
	_check(GameState.castles.size() == 10, "10 castles on the map")
	for i in GameState.castles.size():
		var expected: MachineStyle = GameState.machines[rewards[i + 1]] if rewards.has(i + 1) else null
		_check(GameState.machine_reward(GameState.castles[i]) == expected,
			"castle %d unlocks %s" % [i + 1, rewards.get(i + 1, "nothing")])


func test_castles_ramp_up() -> void:
	var ids := {}
	for i in GameState.castles.size():
		var castle := GameState.castles[i]
		_check(not ids.has(castle.id), "castle id %s is unique" % castle.id)
		ids[castle.id] = true
		_check(castle.order == i, "%s has order %d" % [castle.id, i])
		_check(castle.boss != null and castle.boss.is_boss, "%s has a boss" % castle.id)
		_check(not castle.enemies.is_empty(), "%s has spirits" % castle.id)
		if i > 0:
			var before := GameState.castles[i - 1]
			_check(castle.power_for(10) > before.power_for(10), "%s is harder than %s on night 10" % [castle.id, before.id])
			_check(castle.shard_multiplier > before.shard_multiplier, "%s pays more shards than %s" % [castle.id, before.id])
			_check(castle.payline_tier >= before.payline_tier, "%s sells at least the shapes of %s" % [castle.id, before.id])


func test_conquered_castle_stays_open() -> void:
	MetaProgress.conquered.clear()
	# E.g. won in an older version, before castles were added in front of it.
	MetaProgress.conquered.append(GameState.castles[2].id)
	_check(MetaProgress.is_castle_unlocked(GameState.castles[2]), "a conquered castle stays open")
	_check(not MetaProgress.is_castle_unlocked(GameState.castles[1]), "castle 2 still needs castle 1")
	_check(MetaProgress.is_castle_unlocked(GameState.castles[3]), "the castle after a conquered one opens")
	MetaProgress.conquered.clear()


func test_every_castle_has_its_own_layout() -> void:
	var layout_ids := {}
	var gate := Battlefield.GATE_POSITION + Vector2(0, 6)
	for i in GameState.castles.size():
		var castle := GameState.castles[i]
		var layout := castle.layout
		_check(layout != null, "%s has a layout" % castle.id)
		if layout == null:
			continue
		_check(not layout_ids.has(layout.id), "%s's layout %s is not shared" % [castle.id, layout.id])
		layout_ids[layout.id] = true
		var nav := BattleNav.new(layout)
		_check(nav.has_obstacles == (i > 0), "%s: only the first castle is an open field" % castle.id)
		# The courtyard and the watchtower slots must be open ground.
		var clear := BattleLayout.KEEP_CLEAR
		for y in range(int(clear.position.y), int(clear.end.y), 8):
			for x in range(int(clear.position.x), int(clear.end.x), 8):
				if nav.is_blocked(Vector2(x, y)):
					_check(false, "%s: courtyard blocked at (%d, %d)" % [layout.id, x, y])
		for slot in layout.get_tower_slots():
			_check(not nav.is_blocked(slot), "%s: tower slot %s is open" % [layout.id, slot])
		# Spirits can walk from anywhere in every graveyard to the gate.
		for zone in layout.get_spawn_zones():
			for corner in [zone.position, zone.end, zone.get_center(), Vector2(zone.position.x, zone.end.y), Vector2(zone.end.x, zone.position.y)]:
				_check(nav.can_reach(corner, gate), "%s: path from graveyard %s to the gate" % [layout.id, corner])
		# Rally points: unique ids, open ground, reachable from the gate.
		var rally_ids := {}
		for point in layout.rally_points:
			_check(not rally_ids.has(point.id), "%s: rally point %s is unique" % [layout.id, point.id])
			rally_ids[point.id] = true
			_check(not nav.is_blocked(point.position), "%s: rally point %s is on open ground" % [layout.id, point.id])
			_check(nav.can_reach(gate, point.position), "%s: rally point %s is reachable" % [layout.id, point.id])
		_check(layout.rally_point(&"gate") != null, "%s has a gate rally point" % layout.id)
		_check(layout.rally_points.size() >= 4, "%s has at least 4 rally points" % layout.id)


func test_terrain_lengthens_the_march() -> void:
	# On every layout with terrain, some graveyard's walk to the gate is longer than a straight line.
	for castle in GameState.castles.slice(1):
		var nav := BattleNav.new(castle.layout)
		var longest := 0.0
		for zone in castle.layout.get_spawn_zones():
			for x in [zone.position.x + 4, zone.get_center().x, zone.end.x - 4]:
				var from := Vector2(x, zone.position.y)
				var detour := nav.path_length(from, Battlefield.GATE_POSITION + Vector2(0, 6)) / from.distance_to(Battlefield.GATE_POSITION)
				longest = maxf(longest, detour)
		_check(longest > 1.05, "%s's terrain bends the route (x%.2f)" % [castle.id, longest])


func test_paths_never_cross_terrain() -> void:
	for castle in GameState.castles:
		var nav := BattleNav.new(castle.layout)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 20:
			var from := nav.nearest_free(Vector2(rng.randf_range(10, 630), rng.randf_range(120, 350)))
			var to := nav.nearest_free(Vector2(rng.randf_range(10, 630), rng.randf_range(120, 350)))
			var path := nav.find_path(from, to)
			var at := from
			for point in path:
				if not nav.is_clear_line(at, point, 0.0):
					_check(false, "%s: path step %s -> %s cuts through terrain" % [castle.id, at, point])
				at = point


func test_machine_unlock_costs_crowns() -> void:
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	MetaProgress.shards = 9999
	var style: MachineStyle = GameState.machines[&"jester_81"]
	var unlock := GameState.machine_unlock(style)
	_check(unlock.is_crown_node() and unlock.crown_cost == 2, "Jester's 81 costs 2 crowns")
	_check(not MetaProgress.can_buy(unlock), "shards alone can't buy a machine")
	MetaProgress.conquered.append(GameState.castles[0].id)
	MetaProgress.conquered.append(GameState.castles[1].id)
	_check(MetaProgress.crowns() == 2, "two castles won = 2 crowns")
	_check(not MetaProgress.can_buy(unlock), "its castle (Frostpeak) must be conquered first")
	MetaProgress.conquered.append(GameState.machine_castle(style).id)
	_check(MetaProgress.crowns() == 3, "Frostpeak adds its crown")
	_check(not GameState.is_machine_unlocked(style), "conquest alone doesn't unlock it")
	_check(MetaProgress.buy(unlock), "bought with crowns")
	_check(MetaProgress.crowns() == 1 and MetaProgress.shards == 9999, "paid 2 crowns, no shards")
	_check(GameState.is_machine_unlocked(style), "unlocked after buying")
	_check(GameState.prerequisites_met(GameState.upgrades[&"jester_troupe"]), "its upgrades open up")
	MetaProgress.refund_upgrades()
	_check(MetaProgress.crowns() == 3 and not GameState.is_machine_unlocked(style), "refund gives the crowns back")
	MetaProgress.shards = 0


func test_crowns_come_from_first_conquests() -> void:
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	var total := 0
	var last := 0
	for castle in GameState.castles:
		_check(castle.crown_reward >= last, "%s gives at least as many crowns as the castle before" % castle.display_name)
		last = castle.crown_reward
		total += castle.crown_reward
	_check(total == 20, "20 crowns in the whole kingdom")
	var crown_price := 0
	for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
		if upgrade.is_crown_node():
			crown_price += upgrade.crown_cost * upgrade.max_level
			_check(upgrade.base_cost == 0, "%s costs only crowns" % upgrade.id)
	_check(crown_price > total, "crown nodes cost more than the kingdom gives: the player must choose")
	var shards_before := MetaProgress.shards
	MetaProgress.record_run(10, 40, true, GameState.castles[3])
	_check(MetaProgress.last_crowns == 2 and MetaProgress.crowns() == 2, "first conquest of Thornwood: 2 crowns")
	MetaProgress.record_run(10, 40, true, GameState.castles[3])
	_check(MetaProgress.last_crowns == 0 and MetaProgress.crowns() == 2, "winning it again gives no more crowns")
	MetaProgress.record_run(3, 5, false, GameState.castles[4])
	_check(MetaProgress.last_crowns == 0, "a lost run gives no crowns")
	MetaProgress.shards = shards_before
	MetaProgress.runs = 0
	MetaProgress.conquered.clear()


func test_time_forge_windows() -> void:
	var windows := {
		UpgradeData.Category.MACHINE: 0, UpgradeData.Category.MACHINES: 0,
		UpgradeData.Category.CASTLE: 1, UpgradeData.Category.ARMY: 2, UpgradeData.Category.MERCHANT: 3,
	}
	var cells := {}
	var per_window := [0, 0, 0, 0]
	for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
		var window: int = windows[upgrade.category]
		per_window[window] += 1
		var key := "%d:%s" % [window, upgrade.tree_position]
		_check(not cells.has(key), "%s has its own spot (shared with %s)" % [upgrade.id, cells.get(key)])
		cells[key] = upgrade.id
		if upgrade.requires:
			_check(windows[upgrade.requires.category] == window, "%s's parent is in the same window" % upgrade.id)
		else:
			_check(upgrade.tree_position.y == 0, "%s is a root on the top row" % upgrade.id)
	for i in 4:
		_check(per_window[i] >= 10, "window %d has at least 10 skills" % i)
	_check(GameState.get_upgrades(UpgradeData.Scope.META).size() >= 60, "60+ skills in the Time Forge")


func test_new_forge_skills() -> void:
	GameState.start_run(GameState.castles[0])
	GameState.damage_castle(20)
	_check(GameState.castle_hp == GameState.castle_max_hp - 20, "no armor: full damage")
	_check(not GameState.trade_unlocked, "Trading Post closed without the charter")
	_check(GameState.level_of(&"sword") == 1, "swords start at level 1")
	_check(TradeRules.cost(TradeRules.Mode.SWAP_SAME) == 30, "trade price")
	MetaProgress.levels[&"bastion"] = 1
	MetaProgress.levels[&"reinforced_gates"] = 3
	MetaProgress.levels[&"trade_charter"] = 1
	MetaProgress.levels[&"fair_trades"] = 2
	MetaProgress.levels[&"elite_training"] = 1
	MetaProgress.levels[&"merchant_favor"] = 2
	MetaProgress.levels[&"legendary_favor"] = 1
	MetaProgress.levels[&"stonemasons"] = 2
	GameState.start_run(GameState.castles[0])
	GameState.damage_castle(20)
	_check(GameState.castle_hp == GameState.castle_max_hp - 14, "30% armor: 20 damage -> 14")
	_check(GameState.trade_unlocked, "the charter opens the Trading Post on day 1")
	_check(TradeRules.cost(TradeRules.Mode.SWAP_SAME) == 10, "Fair Trades: 30 - 2x10 = 10 gold")
	_check(GameState.level_of(&"sword") == 2 and GameState.level_of(&"coin") == 1, "Elite Training levels troop symbols only")
	_check(ShopCatalog.repair_amount() == ShopCatalog.REPAIR_AMOUNT + 10, "Stonemasons: +10 repair")
	GameState.merchant_bag.clear()
	var drawn := GameState.draw_merchant_rarity()
	var bag := GameState.merchant_bag
	_check(bag.size() + 1 == 34 + 4 + 2 + 1, "bag has the extra tokens")
	var legendaries := bag.count(MerchantRarity.Tier.LEGENDARY) + (1 if drawn == MerchantRarity.Tier.LEGENDARY else 0)
	_check(legendaries == 2, "2 legendaries in the bag")


func test_crown_nodes_gate_subtrees() -> void:
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	MetaProgress.shards = 9999
	for id: StringName in [&"walls", &"engineers", &"watchtowers"]:
		MetaProgress.buy(GameState.upgrades[id])
	var arcane: UpgradeData = GameState.upgrades[&"arcane_towers"]
	_check(not MetaProgress.can_buy(arcane), "Arcane Towers need the Fortified Towers crown node")
	_check(not MetaProgress.buy(GameState.upgrades[&"fortified_towers"]), "no crowns, no Fortified Towers")
	MetaProgress.conquered.append(GameState.castles[0].id)
	_check(MetaProgress.buy(GameState.upgrades[&"fortified_towers"]), "1 crown buys Fortified Towers")
	_check(MetaProgress.can_buy(arcane), "Arcane Towers open with shards")
	MetaProgress.shards = 0
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()


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
	_check(GameState.copies_of(&"chest") >= 2, "hoard starts with chests")
	_check(GameState.is_symbol_available(_sym("chest")), "Dragon's Hoard sells its chests (below the cap)")


func test_merchant_sells_only_this_machines_special_symbol() -> void:
	_use_machine(&"jester_81")
	var jester := _sym("jester")
	_check(GameState.is_symbol_available(jester), "Jester's 81 sells Jesters below the cap")
	_check(not GameState.is_symbol_available(_sym("chest")), "Jester's 81 never sells chests")
	_check(not GameState.is_symbol_available(_sym("crown")), "Jester's 81 never sells crowns")
	GameState.add_symbol(jester.id, 5)
	_check(GameState.copies_of(&"jester") == jester.max_copies, "jesters stop at their cap")
	_check(not GameState.is_symbol_available(jester), "no more jesters at the cap")
	_use_machine(MachineStyle.STANDARD_ID)
	for id in ["jester", "chest", "crown", "tome"]:
		_check(not GameState.is_symbol_available(_sym(id)), "the Gamba Machine sells no %s" % id)


func test_special_symbols_are_never_upgraded_traded_or_removed() -> void:
	var specials: Array[SymbolData] = [_sym("crown"), _sym("jester"), _sym("chest"), _sym("tome")]
	for symbol in GameState.symbols.values():
		if GameState.is_special_symbol(symbol):
			_check(symbol in specials, "%s is a machine's special symbol" % symbol.id)
	_check(not GameState.is_special_symbol(_sym("rune")), "the Magic Rune is not a machine's special symbol")
	for style: MachineStyle in GameState.machines.values():
		_use_machine(style.id)
		GameState.trade_unlocked = true
		GameState.night = 20
		for symbol in specials:
			GameState.add_symbol(symbol.id, 2)
		var titles: Array[String] = []
		for offer in ShopCatalog.candidate_offers():
			titles.append(offer.title)
		for symbol in specials:
			if not GameState._machine_uses(style, symbol):
				_check(not GameState.is_symbol_available(symbol), "%s: %s (another machine's) is never sold" % [style.id, symbol.id])
			_check(not TradeRules.is_tradeable(symbol), "%s: %s can't be traded" % [style.id, symbol.id])
			for mode in [TradeRules.Mode.SWAP_UP, TradeRules.Mode.SWAP_SAME]:
				_check(symbol not in TradeRules.give_options(mode), "%s: %s is never given in a trade" % [style.id, symbol.id])
				for give in TradeRules.give_options(mode):
					_check(symbol not in TradeRules.get_options(mode, give), "%s: %s is never received in a trade" % [style.id, symbol.id])
			_check(symbol not in TradeRules.give_options(TradeRules.Mode.REMOVE), "%s: %s can't be removed" % [style.id, symbol.id])
			for title in titles:
				_check(not (symbol.display_name in title and "Upgrade" in title), "%s: no '%s' offer for %s" % [style.id, title, symbol.id])


func test_gamba_upgrades_only_work_on_the_gamba_machine() -> void:
	var row: UpgradeData = GameState.upgrades[&"extra_row"]
	var blueprints: UpgradeData = GameState.upgrades[&"blueprints"]
	var levels := {row.id: 1, blueprints.id: 1}
	_use_machine(&"jester_81", levels)
	_check(GameState.machine_rows == 3, "jester keeps 3 rows")
	_check(is_equal_approx(GameState.match_multiplier(3), 0.6), "no reward bonus from the Gamba row upgrade")
	_use_machine(&"dragons_hoard", levels)
	_check(GameState.machine_rows == 3, "hoard ignores the Gamba row upgrade")
	_check(GameState.shapes.size() == 1, "hoard ignores the Gamba blueprints")
	_use_machine(MachineStyle.STANDARD_ID, levels)
	_check(GameState.machine_rows == 4 and is_equal_approx(GameState.match_multiplier(3), 1.0), "the Gamba Machine gets the row")
	_check(GameState.shapes.size() == 2, "the Gamba Machine gets the blueprint shape")
	var node := GameState.machine_node(GameState.machines[MachineStyle.STANDARD_ID])
	_check(node != null and node.is_machine_node() and GameState.machine_unlocked_by(node).id == MachineStyle.STANDARD_ID, "the Gamba Machine has its own Forge node")
	_check(GameState.prerequisites_met(blueprints) and not MetaProgress.can_buy(node), "its node is owned, its upgrades are open")


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


# --- Merchant -----------------------------------------------------------------

func test_merchant_bag_holds_exact_rarities() -> void:
	var full := 0
	for tier: int in MerchantRarity.BAG_CONTENTS:
		full += MerchantRarity.BAG_CONTENTS[tier]
	var counts := {}
	for i in full * 2:  # two full bags
		var tier := GameState.draw_merchant_rarity()
		counts[tier] = counts.get(tier, 0) + 1
	for tier: int in MerchantRarity.BAG_CONTENTS:
		_check(counts.get(tier, 0) == MerchantRarity.BAG_CONTENTS[tier] * 2, "%s drawn exactly per bag" % MerchantRarity.tier_name(tier))
	GameState.reset()
	_check(GameState.merchant_bag.is_empty(), "new run starts with a fresh bag")


func test_merchant_offers_fall_back_to_lower_rarity() -> void:
	GameState.night = 10
	# A bag of only Legendary tokens: every slot asks for Legendary.
	GameState.merchant_bag.assign([3, 3, 3, 3, 3, 3])
	var offers := ShopCatalog.roll_offers()
	_check(offers.size() == GameState.stat_int(Stats.SHOP_SLOTS), "every slot filled")
	_check(offers.all(func(o: ShopOffer) -> bool: return o.rarity >= MerchantRarity.Tier.MYTHIC), "rare tokens stay high when stock allows")
	var titles := offers.map(func(o: ShopOffer) -> String: return o.title)
	for title in titles:
		_check(titles.count(title) == 1, "no duplicate offer: %s" % title)


func test_every_merchant_upgrade_is_valid() -> void:
	for upgrade in GameState.get_upgrades(UpgradeData.Scope.RUN):
		_check(_is_declared_stat(upgrade.stat), "%s uses a declared stat" % upgrade.id)
		_check(upgrade.icon != null, "%s has an icon" % upgrade.id)
	var tiers := {}
	for upgrade in GameState.get_upgrades(UpgradeData.Scope.RUN):
		tiers[upgrade.rarity] = true
	_check(tiers.size() == MerchantRarity.Tier.size(), "every rarity has merchant upgrades")


func test_trading_post_must_be_bought() -> void:
	GameState.gold = 100
	var bow := _sym("bow")
	GameState.add_symbol(bow.id, 2)
	_check(not TradeRules.can_trade(TradeRules.Mode.REMOVE, bow, null), "no trades before the Trading Post is open")
	_check(TradeRules.unlock() and GameState.gold == 100 - TradeRules.unlock_cost(), "opening it costs gold once")
	_check(not TradeRules.unlock(), "can't buy it twice")
	GameState.reset()
	_check(not GameState.trade_unlocked, "closed again in a new run")


func test_swap_up_gives_two_for_one_rarer() -> void:
	_use_machine(MachineStyle.STANDARD_ID, {&"recruit_crossbows": 1})
	GameState.trade_unlocked = true
	GameState.gold = 200
	var bow := _sym("bow")
	var crossbow := _sym("crossbow")
	GameState.add_symbol(bow.id, 2)
	GameState.add_symbol(crossbow.id)  # you can only pick symbols you already own
	var bows := GameState.copies_of(bow.id)
	var crossbows := GameState.copies_of(crossbow.id)
	_check(crossbow in TradeRules.get_options(TradeRules.Mode.SWAP_UP, bow), "bow can become a crossbow")
	_check(TradeRules.get_options(TradeRules.Mode.SWAP_UP, bow).all(
		func(s: SymbolData) -> bool: return s.rarity == bow.rarity + 1), "swap up only offers the next rarity")
	_check(TradeRules.trade(TradeRules.Mode.SWAP_UP, bow, crossbow), "trade works")
	_check(GameState.copies_of(bow.id) == bows - 2 and GameState.copies_of(crossbow.id) == crossbows + 1, "2 bows -> 1 crossbow")
	_check(GameState.gold == 200 - TradeRules.cost(TradeRules.Mode.SWAP_UP), "fixed price paid")
	_check(TradeRules.trade(TradeRules.Mode.SWAP_UP, bow, crossbow) or GameState.copies_of(bow.id) < 2, "usable again, same price")


func test_random_trade_picks_are_valid() -> void:
	GameState.trade_unlocked = true
	for i in 20:
		for mode: TradeRules.Mode in TradeRules.Mode.values():
			var give := TradeRules.pick_give(mode)
			_check(give == null or give in TradeRules.give_options(mode), "picked give is allowed")
			_check(give == null or mode == TradeRules.Mode.REMOVE or not TradeRules.get_options(mode, give).is_empty(),
				"a picked give always has something to choose")


func test_special_symbols_stay_on_their_machine() -> void:
	var specials := {}  # symbol id -> machine id that owns it
	for style: MachineStyle in GameState.machines.values():
		for symbol in style.merchant_symbols:
			specials[symbol.id] = style.id
		for entry in style.start_symbols:
			specials[entry.symbol.id] = style.id
	_check(specials.size() >= 4, "crown, jester, chest and tome are machine symbols")
	_check(not specials.has(&"rune"), "the Magic Rune is shared")
	for style: MachineStyle in GameState.machines.values():
		# Every Time Forge upgrade owned, every castle open: the worst case for leaks.
		var all_levels := {}
		for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
			all_levels[upgrade.id] = upgrade.max_level
		_use_machine(style.id, all_levels)
		for castle in GameState.castles:
			GameState.start_run(castle)
			GameState.night = 20
			for id: StringName in specials:
				if specials[id] == style.id:
					continue
				var name := "%s on %s / %s" % [id, style.id, castle.id]
				_check(GameState.copies_of(id) == 0, "no %s at run start" % name)
				_check(not GameState.is_symbol_available(GameState.get_symbol(id)), "merchant never sells %s" % name)
				GameState.add_symbol(id)
				_check(GameState.copies_of(id) == 0, "can't add %s" % name)
			for offer in ShopCatalog.candidate_offers():
				for id: StringName in specials:
					if specials[id] != style.id:
						_check(not offer.title.contains(GameState.get_symbol(id).display_name), "offer '%s' on %s" % [offer.title, style.id])
	_use_machine(MachineStyle.STANDARD_ID)


func test_trade_pool_is_only_owned_symbols() -> void:
	GameState.trade_unlocked = true
	var coin := _sym("coin")
	for mode: TradeRules.Mode in [TradeRules.Mode.SWAP_UP, TradeRules.Mode.SWAP_SAME]:
		for symbol in TradeRules.get_options(mode, coin):
			_check(GameState.copies_of(symbol.id) > 0, "%s is already on the reels" % symbol.id)
	_check(_sym("jester") not in TradeRules.get_options(TradeRules.Mode.SWAP_UP, coin), "no jester unless owned")
	GameState.add_symbol(&"jester")
	_check(_sym("jester") not in TradeRules.get_options(TradeRules.Mode.SWAP_UP, coin), "never another machine's jester")
	_use_machine(&"jester_81")
	GameState.trade_unlocked = true
	_check(not GameState.is_other_machine_symbol(_sym("jester")), "jester is fine on Jester's 81")


func test_swap_same_and_remove_rules() -> void:
	GameState.trade_unlocked = true
	GameState.gold = 100
	var coin := _sym("coin")
	var skull := _sym("skull")
	_check(TradeRules.get_options(TradeRules.Mode.SWAP_SAME, coin).all(
		func(s: SymbolData) -> bool: return s.rarity == coin.rarity and s.id != coin.id), "same tier swap stays in tier")
	_check(skull not in TradeRules.give_options(TradeRules.Mode.SWAP_UP), "skulls can't be swapped up")
	if GameState.copies_of(skull.id) > 0:
		var before := GameState.copies_of(skull.id)
		_check(TradeRules.trade(TradeRules.Mode.REMOVE, skull), "remove a skull")
		_check(GameState.copies_of(skull.id) == before - 1, "one skull fewer")
	while TradeRules.trade(TradeRules.Mode.REMOVE, TradeRules.give_options(TradeRules.Mode.REMOVE)[0] 			if not TradeRules.give_options(TradeRules.Mode.REMOVE).is_empty() else null):
		GameState.gold = 100
	_check(GameState.pool_total() == GameState.min_kept_symbols(), "removing good symbols stops at the floor")


func test_gold_multiplier_boosts_gold_lines() -> void:
	var coin := _sym("coin")
	var before := coin.reward_amount(3, 1)
	GameState.run_upgrades[&"midas_touch"] = 1
	_check(coin.reward_amount(3, 1) == roundi(before * 2.0), "Midas Touch doubles a coin line")
	GameState.run_upgrades.clear()


# --- Helpers ------------------------------------------------------------------

## Unlocks and starts a run on a machine, with optional extra upgrade levels.
func _use_machine(id: StringName, extra_levels: Dictionary = {}) -> void:
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	var style: MachineStyle = GameState.machines[id]
	var castle := GameState.machine_castle(style)
	if castle:
		MetaProgress.conquered.append(castle.id)
	var unlock := GameState.machine_unlock(style)
	if unlock:
		MetaProgress.levels[unlock.id] = 1
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


func test_old_save_is_refunded() -> void:
	MetaProgress.levels.clear()
	MetaProgress.levels[&"walls"] = 2       # 8 + 16
	MetaProgress.levels[&"extra_row"] = 1   # was 40 shards, now a crown node
	MetaProgress.levels[&"unknown_node"] = 3
	var shards_before := MetaProgress.shards
	MetaProgress.persist = false
	MetaProgress._migrate_to_crowns()
	_check(MetaProgress.migrated_shards == 64 and MetaProgress.shards == shards_before + 64, "old upgrades refunded in shards")
	_check(MetaProgress.levels.is_empty(), "the new tree starts empty")
	MetaProgress.shards = shards_before
	MetaProgress.migrated_shards = 0


func test_refund_subtree() -> void:
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()
	MetaProgress.conquered.append(GameState.castles[0].id)
	MetaProgress.shards = 1000
	for id: StringName in [&"walls", &"engineers", &"engineers", &"watchtowers", &"fortified_towers", &"arcane_towers", &"healer"]:
		MetaProgress.buy(GameState.upgrades[id])
	var spent := 1000 - MetaProgress.shards
	var refund := MetaProgress.refund_subtree(GameState.upgrades[&"engineers"])
	_check(refund["crowns"] == 1, "the Fortified Towers crown comes back")
	_check(MetaProgress.level_of(&"engineers") == 0 and MetaProgress.level_of(&"arcane_towers") == 0
		and MetaProgress.level_of(&"fortified_towers") == 0, "engineers and everything below it are gone")
	_check(MetaProgress.level_of(&"walls") == 1 and MetaProgress.level_of(&"healer") == 1, "the rest of the tree stays")
	_check(MetaProgress.shards == 1000 - spent + refund["shards"] and refund["shards"] > 0, "shards given back")
	_check(MetaProgress.crowns() == 1, "crown free to spend again")
	var nothing := MetaProgress.refund_subtree(GameState.upgrades[&"engineers"])
	_check(nothing["shards"] == 0 and nothing["crowns"] == 0, "refunding an empty branch does nothing")
	MetaProgress.shards = 0
	MetaProgress.levels.clear()
	MetaProgress.conquered.clear()


func test_curse_adds_exactly_one_ghost_per_point() -> void:
	GameState.start_run(GameState.castles[0])
	var ghost: UnitData = WaveGenerator.CURSE_SPIRIT
	GameState.curse_threat = 0
	var plain := WaveGenerator.build(1)
	GameState.curse_threat = 30
	var cursed := WaveGenerator.build(1)
	_check(cursed.count(ghost) >= 30, "Curse +30 brings at least 30 ghosts")
	# Willowdale night 1 only sends ghosts, so the wave is exactly 30 bigger.
	_check(cursed.size() == plain.size() + 30, "Curse +30 = 30 more spirits (%d vs %d)" % [cursed.size(), plain.size()])
	GameState.curse_threat = 0


func test_purple_tombstone_from_castle_six() -> void:
	var tomb := _sym("tombstone")
	var purple := _sym("purple_tombstone")
	_check(purple.effect == SymbolData.Effect.CURSE and not purple.in_shop, "purple tombstone is a curse, never sold")
	_check(purple.passive_threat == tomb.passive_threat * 2 and purple.power == tomb.power * 2, "purple tombstone doubles the curse")
	for i in GameState.castles.size():
		GameState.start_run(GameState.castles[i])
		var expected := purple if i >= 5 else tomb
		_check(GameState.curse_symbol() == expected, "castle %d spreads %s" % [i + 1, expected.display_name])
	GameState.start_run(GameState.castles[5])
	GameState.night = 10
	for i in 20:
		GameState.spread_curse()
	_check(GameState.copies_of(&"purple_tombstone") >= 1, "the curse adds purple tombstones at castle 6")
	_check(not TradeRules.is_tradeable(purple), "purple tombstones can't be traded up")


func test_cursed_coin_and_greed_monster() -> void:
	var coin := _sym("coin")
	var cursed := _sym("cursed_coin")
	_check(cursed.is_cursed() and not cursed.in_shop, "cursed coin is cursed and never sold")
	_check(cursed.is_wild_for(coin) and not cursed.is_wild_for(_sym("sword")), "cursed coin is wild for coins only")
	_check(not TradeRules.is_tradeable(cursed), "cursed coins can't be traded")
	_check(cursed.win_spirit == WaveGenerator.GREED_SPIRIT, "a winning line through it brings the Greed Monster")
	# Stronger than a ghost, weaker than two ghouls ("zombies").
	var greed: UnitData = WaveGenerator.GREED_SPIRIT
	var ghost: UnitData = load("res://data/units/ghost.tres")
	var ghoul: UnitData = load("res://data/units/ghoul.tres")
	_check(greed.max_hp > ghost.max_hp and greed.max_hp < ghoul.max_hp * 2, "Greed Monster HP between a ghost and 2 ghouls")
	_check(greed.damage > ghost.damage and greed.damage < ghoul.damage * 2, "Greed Monster damage between a ghost and 2 ghouls")
	# A coin line through a cursed coin wins as coins and includes its cell.
	var grid := _grid(["coin cursed_coin coin bow sword", "bow sword bow sword bow", "sword bow sword bow sword"])
	var wins := LineEvaluator.evaluate(grid, _lines(), GameState.machine)
	_check(wins.size() == 1 and wins[0].symbol.id == &"coin" and wins[0].count == 3, "coin + cursed coin + coin pays as 3 coins")
	_check(Vector2i(1, 0) in wins[0].cells, "the cursed coin is part of the winning line")
	# Greed joins tonight's wave, then clears at nightfall.
	GameState.start_run(GameState.castles[0])
	GameState.add_greed(2)
	var wave := WaveGenerator.build(1)
	_check(wave.count(greed) == 2, "2 winning lines = 2 Greed Monsters tonight")
	GameState.clear_curse_threat()
	_check(GameState.greed_spirits == 0, "greed clears when the night starts")
	# The merchant offers to banish it.
	GameState.add_symbol(&"cursed_coin")
	var banish := false
	for offer in ShopCatalog.candidate_offers():
		if offer.title == "Banish Cursed Coin":
			banish = true
	_check(banish, "the merchant offers to banish cursed coins")


func test_curse_sometimes_spreads_cursed_coins() -> void:
	GameState.start_run(GameState.castles[0])
	GameState.night = 10
	var seen := {}
	for i in 60:
		for symbol in GameState.spread_curse():
			seen[symbol.id] = true
	_check(seen.has(&"tombstone") and seen.has(&"cursed_coin"), "the curse spreads tombstones and sometimes cursed coins")
	_check(not seen.has(&"purple_tombstone"), "no purple tombstones before castle 6")


func test_zombie_miner_burrows() -> void:
	var miner: UnitData = load("res://data/units/zombie_miner.tres")
	_check(miner.burrower and not miner.flying and not miner.assassin, "the Zombie Miner digs (and only digs)")
	var ghost: UnitData = load("res://data/units/ghost.tres")
	_check(miner.max_hp > ghost.max_hp, "a miner is tougher than a ghost")
	for i in GameState.castles.size():
		var has_miner := false
		for entry in GameState.castles[i].enemies:
			if entry.unit == miner:
				has_miner = true
		_check(has_miner == ((i + 1) in [4, 6, 7, 8, 9, 10]), "castle %d %s Zombie Miners" % [i + 1, "has" if has_miner else "has no"])


func test_magic_rune_limit_two_per_run() -> void:
	MetaProgress.levels[&"rune_mastery"] = 1
	GameState.start_run(GameState.castles[0])
	GameState.night = 10
	var rune := _sym("rune")
	_check(rune.max_copies == 1, "Magic Rune: at most 1 a run")
	_check(GameState.is_symbol_available(rune), "the merchant sells runes below the limit")
	GameState.add_symbol(&"rune", 5)
	_check(GameState.copies_of(&"rune") == 1, "adding 5 runes stops at 1")
	_check(not GameState.is_symbol_available(rune), "no more runes from the merchant at the limit")
	GameState.trade_unlocked = true
	for mode in [TradeRules.Mode.SWAP_UP, TradeRules.Mode.SWAP_SAME]:
		for give in TradeRules.give_options(mode):
			_check(rune not in TradeRules.get_options(mode, give), "no runes from trades at the limit")
	MetaProgress.levels.erase(&"rune_mastery")


func test_one_hoard_in_three_hides_the_dragons_treasure() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var units := [_sym("sword")]
	var big := 0
	var rounds := 3000
	for i in rounds:
		var hoard := HoardRound.new(5, 3, 3)
		for x in 6:
			hoard.lock(Vector2i(x % 5, x / 5), HoardPrize.roll(rng, 10, units))
		var cell := hoard.roll_big_prize(rng, units)
		if cell != Vector2i(-1, -1):
			big += 1
			var prize: HoardPrize = hoard.prizes[cell]
			_check(prize.kind == HoardPrize.Kind.MAJOR and prize.troops >= 10 and prize.gold >= 80, "the Treasure is a big army and lots of gold")
	var share := float(big) / rounds
	_check(share > 0.30 and share < 0.36, "about 1 round in 3 has the Treasure (%.2f)" % share)
	_check(HoardPrize.WEIGHTS[HoardPrize.Kind.MAJOR] == 0.0, "MAJOR only comes from the Treasure roll")
	_use_machine(&"dragons_hoard")
	_check(GameState.copies_of(&"chest") == 2, "Dragon's Hoard starts with 2 chests")


func test_upgrades_need_the_symbol_or_living_troops() -> void:
	GameState.start_run(GameState.castles[0])
	var bow := _sym("bow")
	var coin := _sym("coin")
	var pike := _sym("pike")
	_check(ShopCatalog.can_upgrade(bow) and ShopCatalog.can_upgrade(coin), "symbols on the reels can be upgraded")
	_check(GameState.copies_of(&"pike") == 0 and not ShopCatalog.can_upgrade(pike), "no pikes, no pikemen: no Upgrade Pike")
	while GameState.copies_of(&"bow") > 0:
		GameState.remove_symbol(&"bow")
	_check(not ShopCatalog.can_upgrade(bow), "bows gone and no archers: no Upgrade Bow")
	# A living archer brings the offer back, and upgrading makes it stronger.
	var archer: Unit = preload("res://src/battle/unit.tscn").instantiate()
	archer.setup(bow.unit, Unit.Team.PLAYER, GameState.power_for(&"bow"), null)
	archer.process_mode = Node.PROCESS_MODE_DISABLED  # no battlefield here: just counts as alive
	add_child(archer)
	_check(ShopCatalog.can_upgrade(bow), "a living archer allows Upgrade Bow")
	var hp_before := archer.max_hp
	ShopCatalog.upgrade_symbol_offer(bow).apply.call()
	_check(archer.max_hp > hp_before * 1.3, "upgrading Bow makes the archer on the field stronger")
	archer.remove_from_group(Unit.GROUP_TROOPS)
	archer.queue_free()
	_check(not ShopCatalog.can_upgrade(_sym("skull")), "junk is never upgraded")


func test_hoard_has_two_respins() -> void:
	_use_machine(&"dragons_hoard")
	_check(GameState.feature_length() == 2, "the Hoard gives 2 respins")
	_use_machine(&"dragons_hoard", {&"hoard_respins": 1})
	_check(GameState.feature_length() == 3, "Greedy Dragon adds a third")


func test_special_symbols_have_static_chances() -> void:
	_use_machine(&"dragons_hoard")
	var chest := _sym("chest")
	_check(chest.static_chance > 0.0, "chests have a static chance")
	var expected := chest.static_chance * GameState.copies_of(&"chest")
	_check(is_equal_approx(GameState.chance_of(&"chest"), expected), "chest chance = static chance x copies")
	GameState.add_symbol(&"coin", 20)
	GameState.add_symbol(&"sword", 20)
	_check(is_equal_approx(GameState.chance_of(&"chest"), expected), "more symbols on the reels don't dilute chests")
	var hits := 0
	var rolls := 20000
	for i in rolls:
		if GameState.roll_symbol() == chest:
			hits += 1
	_check(absf(float(hits) / rolls - expected) < 0.015, "rolls land chests at the static chance (%.3f vs %.3f)" % [float(hits) / rolls, expected])
	var total := 0.0
	for id: StringName in GameState.pool:
		total += GameState.chance_of(id)
	_check(absf(total - 1.0) < 0.001, "all chances add up to 100%")
	for id in ["crown", "jester", "tome"]:
		_check(_sym(id).static_chance > 0.0, "%s has a static chance" % id)
	_check(_sym("coin").static_chance == 0.0 and _sym("rune").static_chance == 0.0, "normal symbols keep pool chances")


func test_thin_reels_fill_with_empty_slots() -> void:
	var cells := {&"standard": 15, &"old_cellar": 9, &"dragons_hoard": 15}
	for id: StringName in cells:
		_use_machine(id)
		_check(GameState.reel_slots() == cells[id], "%s has %d cells" % [id, cells[id]])
	_use_machine(MachineStyle.STANDARD_ID)
	_check(GameState.empty_slots() == 0, "a fresh run has no Empty Slots")
	_check(GameState.slot_target() == mini(15, GameState.start_symbols), "the reels keep the run's starting size (up to the cells)")
	GameState.start_symbols = 15
	GameState.pool.clear()
	GameState.pool[&"coin"] = 4
	GameState.pool[&"sword"] = 3
	_check(GameState.empty_slots() == 8, "7 symbols on 15 cells = 8 Empty Slots")
	_check(is_equal_approx(GameState.chance_of(GameState.EMPTY_SLOT_ID), 8.0 / 15.0), "Empty Slots land 8 times in 15")
	var total := GameState.chance_of(GameState.EMPTY_SLOT_ID)
	for id: StringName in GameState.pool:
		total += GameState.chance_of(id)
	_check(absf(total - 1.0) < 0.001, "chances with Empty Slots add up to 100%")
	var empties := 0
	for i in 15000:
		if GameState.roll_symbol().id == GameState.EMPTY_SLOT_ID:
			empties += 1
	_check(absf(empties / 15000.0 - 8.0 / 15.0) < 0.02, "rolls land Empty Slots at their chance")
	var grid := _grid(["empty_slot empty_slot empty_slot empty_slot empty_slot", "coin sword coin sword coin", "sword coin sword coin sword"])
	_check(LineEvaluator.evaluate(grid, _lines(), GameState.machine).is_empty(), "a line of Empty Slots never wins")
	GameState.pool[&"coin"] = 20
	_check(GameState.empty_slots() == 0 and GameState.chance_of(GameState.EMPTY_SLOT_ID) == 0.0, "full reels have no Empty Slots")
	_check(not ShopCatalog.can_upgrade(_sym("empty_slot")) and not _sym("empty_slot").in_shop, "Empty Slots are never sold or upgraded")


func test_hungry_machine_and_floor() -> void:
	_use_machine(MachineStyle.STANDARD_ID)
	GameState.pool.clear()
	GameState.pool[&"coin"] = 6
	GameState.pool[&"sword"] = 4
	_check(GameState.hunger() == 0, "10 symbols: the machine is fed")
	GameState.pool[&"sword"] = 1
	_check(GameState.hunger() == 3 * GameState.HUNGER_PER_MISSING, "7 symbols: +2 spirits per missing symbol each spin")
	GameState.pool[&"sword"] = 4
	GameState.pool[&"skull"] = 2
	GameState.trade_unlocked = true
	GameState.gold = 999
	var removable := TradeRules.give_options(TradeRules.Mode.REMOVE)
	_check(_sym("skull") in removable, "skulls can always be removed")
	GameState.pool.erase(&"skull")
	_check(TradeRules.give_options(TradeRules.Mode.REMOVE).is_empty(), "good symbols stop at 10")
	_check(Battlefield.GHOST_SPAWN_FACTOR < 1.0, "ghosts spawn faster than other spirits")


func test_curse_spreads_two_from_night_five() -> void:
	GameState.start_run(GameState.castles[0])
	GameState.night = 4
	_check(GameState.spread_curse().size() == GameState.castle.curses_per_dawn, "before night 5: the castle's usual curse")
	GameState.night = 5
	var added := GameState.spread_curse()
	_check(added.size() == 2, "from night 5: 2 cursed symbols every dawn")
	for symbol in added:
		_check(symbol.id in [&"tombstone", &"cursed_coin"], "each is a Tombstone or a Cursed Coin")


func test_orc_catapult_and_exploding_miners() -> void:
	var catapult: UnitData = load("res://data/units/orc_catapult.tres")
	_check(catapult.siege and catapult.is_ranged() and catapult.splash_radius > 0.0, "the catapult lobs splash shots")
	_check(catapult.attack_range >= 100.0, "the catapult shoots from far away")
	var miner: UnitData = load("res://data/units/zombie_miner.tres")
	_check(miner.death_damage > 0.0 and miner.death_radius > 0.0, "Zombie Miners explode on death")
	for i in GameState.castles.size():
		var has := false
		for entry in GameState.castles[i].enemies:
			if entry.unit == catapult:
				has = true
		_check(has == (i >= 7), "castle %d %s Orc Catapults" % [i + 1, "has" if has else "has no"])


func test_horde_grows_exponentially_and_with_the_army() -> void:
	var first := GameState.castles[0]
	var last := GameState.castles[9]
	_check(first.wave_growth == 1.0 and first.army_threat == 0.0, "Willowdale stays as it was")
	for i in range(1, GameState.castles.size()):
		var castle := GameState.castles[i]
		var before := GameState.castles[i - 1]
		_check(castle.wave_growth >= before.wave_growth and castle.army_threat >= before.army_threat,
			"%s grows at least as fast as %s" % [castle.id, before.id])
	GameState.start_run(last)
	var night5 := WaveGenerator.threat_for(5)
	var night10 := WaveGenerator.threat_for(10)
	_check(night10 > night5 * 2, "the Ashen Throne horde more than doubles from night 5 to 10 (%d -> %d)" % [night5, night10])
	_check(night10 <= roundi(last.budget_for(10) * WaveGenerator.THREAT_MULTIPLIER * WaveGenerator.MAX_GROWTH) + 1, "growth is capped")
	_check(WaveGenerator.threat_for(5, 100) == night5 + WaveGenerator.army_extra(100), "a 100-troop army adds its threat")
	_check(WaveGenerator.army_extra(100) == roundi(80 * last.army_threat), "80 troops over the line x army threat")
	_check(WaveGenerator.army_extra(15) == 0, "small armies add nothing")
	var wave := WaveGenerator.build(10, 100)
	_check(wave.size() < 200, "huge budgets buy heavier spirits, not endless swarms (%d spirits)" % wave.size())
