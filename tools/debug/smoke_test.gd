extends Node
## Autoplay smoke test: plays a run by itself (spins, buys, fights) and prints
## what happens. Never touches the real save file. Optional screenshots.
##
## Run from the project root:
##   godot --path . res://tools/debug/smoke_test.tscn -- --nights=3 --shots=C:/tmp/shots
## Flags:
##   --nights=N     nights to play (default 3)
##   --idle         no spins, no shopping: tests the castle alone
##   --shards=N     start with N Chrono Shards and buy Time Forge upgrades first
##   --castle=N     castle to play (1 = first); earlier castles count as conquered
##   --machine=ID   slot machine style to play (data/machines/, e.g. jester_81);
##                  conquers the castle that unlocks it first. Gamble and nudge
##                  questions are declined.
##   --shots=DIR    save screenshots (needs a window, so no --headless)
##   --layouts      only screenshot every castle's battlefield (plain and with
##                  the pathing grid and rally points), then quit. Needs --shots.

const MAIN_SCENE := preload("res://src/main/main.tscn")
const BATTLE_SPEED := 4.0

var _nights := 3
var _shots_dir := ""
var _idle := false
var _shards := 0
var _tutorial := false
var _castle := 1
var _machine := MachineStyle.STANDARD_ID
var _layouts := false
var _main: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--nights="):
			_nights = int(arg.get_slice("=", 1))
		elif arg == "--tutorial":
			_tutorial = true  # step through the tutorial and screenshot each step
		elif arg == "--idle":
			_idle = true
		elif arg == "--layouts":
			_layouts = true
		elif arg.begins_with("--machine="):
			_machine = StringName(arg.get_slice("=", 1))
		elif arg.begins_with("--castle="):
			_castle = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shards="):
			_shards = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shots="):
			_shots_dir = arg.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(_shots_dir)
	# Fresh, in-memory progress (runs = 1 skips the intro).
	MetaProgress.persist = false
	MetaProgress.levels.clear()
	MetaProgress.shards = _shards
	MetaProgress.runs = 1
	MetaProgress.tutorial_done = not _tutorial
	MetaProgress.conquered.clear()
	for i in _castle - 1:
		MetaProgress.conquered.append(GameState.castles[i].id)
	_unlock_machine(_machine)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	if _layouts:
		await _shoot_layouts()
	else:
		await _run()
	get_tree().quit()


func _run() -> void:
	await _wait(0.5)
	await _shot("00_main_menu")
	var menu: MainMenu = _main.get_node("UI/MainMenu")
	if _shards > 0:
		menu.get_node("%UpgradesButton").pressed.emit()
		await _wait(0.4)
		var forge: TimeForge = _main.get_node("UI/TimeForge")
		_buy_forge_upgrades(forge)
		for window in TimeForge.WINDOWS.size():
			forge.show_window(window)
			await _wait(0.3)
			await _shot("00_time_forge_%d" % window)
		print("Forge upgrades: %s (shards left %d, crowns left %d)" % [MetaProgress.levels, MetaProgress.shards, MetaProgress.crowns()])
		forge.get_node("%BeginButton").pressed.emit()
		await _wait(0.6)
	menu.get_node("%PreviewButton").pressed.emit()
	await _wait(0.4)
	await _shot("00_preview")
	_main.get_node("UI/Codex").get_node("%BackButton").pressed.emit()
	await _wait(0.4)
	menu.get_node("%MerchantButton").pressed.emit()
	await _wait(0.4)
	var wares: MerchantWares = _main.get_node("UI/MerchantWares")
	for tier: int in MerchantRarity.Tier.values():
		wares._show_tier(tier)
		await _shot("00_wares_%s" % MerchantRarity.tier_name(tier).to_lower())
	wares.get_node("%BackButton").pressed.emit()
	await _wait(0.4)
	menu.get_node("%PlayButton").pressed.emit()
	await _wait(0.6)
	var map: KingdomMap = _main.get_node("UI/KingdomMap")
	await _shot("00_map")
	map._select(GameState.castles[_castle - 1])  # machine unlocks may have opened later castles
	map.get_node("%MarchButton").pressed.emit()
	await _wait(0.6)
	print("Castle: %s | Machine: %s" % [GameState.castle.display_name, GameState.machine.display_name])
	if _tutorial:
		await _step_through_tutorial()

	var day: DayPhase = _main.get_node("UI/DayPhase")
	var machine: SlotMachine = day.get_node("%SlotMachine")
	var field: Battlefield = _main.get_node("Battlefield")
	for night in range(1, _nights + 1):
		await _wait(0.6)
		var spins := 0 if _idle else GameState.spins_per_day()
		for i in spins:
			day.get_node("%SpinButton").pressed.emit()
			while day.is_busy():
				if machine.is_awaiting_choice():
					machine.decline_choice()
				await get_tree().process_frame
			if i == 0:
				await _wait(0.1)
				await _shot("%02d_day_first_spin" % night)
				if night == 1:
					var settings: SettingsScreen = _main.get_node("Overlay/SettingsScreen")
					settings.open()
					await _wait(0.3)
					await _shot("01_settings")
					settings.close()
			await _wait(0.15)
		await _wait(0.4)
		if not _idle:
			_buy_everything_affordable(day)
		await _wait(0.3)
		await _shot("%02d_day_after_shopping" % night)
		print("Night %d | gold %d | castle %d/%d | troops %d | rows %d | lines %d | run upgrades %s" % [
			night, GameState.gold, GameState.castle_hp, GameState.castle_max_hp, field.get_troops().size(),
			GameState.machine_rows, GameState.active_paylines().size(), GameState.run_upgrades])
		day.get_node("%StartNightButton").pressed.emit()
		await _wait(1.0)  # the night panel applies the saved speed; override it after
		Engine.time_scale = BATTLE_SPEED
		await _wait(3.0)
		await _shot("%02d_night_battle" % night)
		while field.is_night:
			await get_tree().process_frame
		Engine.time_scale = 1.0
		print("  -> after night %d: castle %d, troops left %d, kills %d, upkeep due %d" % [night, GameState.castle_hp, field.get_troops().size(), GameState.kills, field.upkeep_cost()])
		if GameState.castle_hp <= 0:
			print("  castle fell")
			print("RESULT castle=%d fell night=%d kills=%d" % [_castle, night, GameState.kills])
			await _wait(0.5)
			await _shot("%02d_game_over" % night)
			return
		await _wait(2.5)
		print("  dawn: gold %d, morale %d%%" % [GameState.gold, roundi(field.morale * 100.0)])
	print("RESULT castle=%d survived nights=%d hp=%d/%d kills=%d" % [
		_castle, _nights, GameState.castle_hp, GameState.castle_max_hp, GameState.kills])


## Unlocks (conquers its castle and buys its crown node) and picks a machine
## (in-memory progress only).
func _unlock_machine(id: StringName) -> void:
	var style: MachineStyle = GameState.machines.get(id)
	assert(style != null, "Unknown machine: %s" % id)
	var castle := GameState.machine_castle(style)
	if castle and castle.id not in MetaProgress.conquered:
		MetaProgress.conquered.append(castle.id)
	var unlock := GameState.machine_unlock(style)
	if unlock:
		MetaProgress.levels[unlock.id] = 1
	MetaProgress.selected_machine = id


func _step_through_tutorial() -> void:
	await _wait(1.0)
	var tutorial: Tutorial = _main.get("_tutorial")
	var step := 1
	while tutorial.visible:
		await _shot("tut_%02d" % step)
		tutorial._next_button.pressed.emit()
		step += 1
		await _wait(0.4)
	print("Tutorial steps: %d" % (step - 1))


func _buy_forge_upgrades(_forge: TimeForge) -> void:
	var bought := true
	while bought:
		bought = false
		for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
			if MetaProgress.buy(upgrade):
				bought = true
	_forge.open()  # rebuild the tree to show the result


func _buy_everything_affordable(day: DayPhase) -> void:
	var shop: Shop = day.get_node("%Shop")
	var cards: GridContainer = shop.get_node("%Cards")
	for card: OfferCard in cards.get_children():
		if not card.offer.sold and GameState.gold >= card.offer.cost:
			print("  bought: %s (%d)" % [card.offer.title, card.offer.cost])
			card.get_child(0).get_child(-1).pressed.emit()  # the card's real Buy button
	# Trading Post: open it when affordable, then remove Skulls and swap up spare symbols.
	var unlock: Button = shop.get_node("%UnlockTradeButton")
	if unlock.visible and not unlock.disabled:
		unlock.pressed.emit()
		print("  opened the Trading Post")
	if not GameState.trade_unlocked:
		return
	var skull := GameState.get_symbol(GameState.SKULL_ID)
	while TradeRules.trade(TradeRules.Mode.REMOVE, skull):
		print("  trade: removed a Skull")
	for give in TradeRules.give_options(TradeRules.Mode.SWAP_UP):
		if GameState.copies_of(give.id) >= 3:
			var receive: SymbolData = TradeRules.get_options(TradeRules.Mode.SWAP_UP, give)[0]
			if TradeRules.trade(TradeRules.Mode.SWAP_UP, give, receive):
				print("  trade: 2x %s -> %s" % [give.display_name, receive.display_name])


## Every castle's battlefield from the night camera, without the UI.
func _shoot_layouts() -> void:
	await _wait(0.5)
	_main.get_node("UI").hide()
	var field: Battlefield = _main.get_node("Battlefield")
	var terrain: LayoutView = field.get_node("Terrain")
	for i in GameState.castles.size():
		var castle := GameState.castles[i]
		field.apply_castle(castle)
		await _wait(0.8)
		field.show_overview()
		terrain.show_debug = false
		terrain.queue_redraw()
		await _wait(0.1)
		await _shot("layout_%02d_%s" % [i + 1, castle.id])
		terrain.show_debug = true
		terrain.queue_redraw()
		await _wait(0.1)
		await _shot("layout_%02d_%s_debug" % [i + 1, castle.id])
		print("Layout %d: %s (%s), %d rally points" % [i + 1, castle.layout.display_name, castle.id, castle.layout.rally_points.size()])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots_dir, shot_name])
