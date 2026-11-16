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
##   --shots=DIR    save screenshots (needs a window, so no --headless)

const MAIN_SCENE := preload("res://src/main/main.tscn")
const BATTLE_SPEED := 4.0

var _nights := 3
var _shots_dir := ""
var _idle := false
var _shards := 0
var _castle := 1
var _main: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--nights="):
			_nights = int(arg.get_slice("=", 1))
		elif arg == "--idle":
			_idle = true
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
	MetaProgress.conquered.clear()
	for i in _castle - 1:
		MetaProgress.conquered.append(GameState.castles[i].id)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
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
		await _wait(0.3)
		await _shot("00_time_forge")
		print("Forge upgrades: %s (shards left %d)" % [MetaProgress.levels, MetaProgress.shards])
		forge.get_node("%BeginButton").pressed.emit()
		await _wait(0.6)
	menu.get_node("%PreviewButton").pressed.emit()
	await _wait(0.4)
	await _shot("00_preview")
	_main.get_node("UI/Codex").get_node("%BackButton").pressed.emit()
	await _wait(0.4)
	menu.get_node("%PlayButton").pressed.emit()
	await _wait(0.6)
	var map: KingdomMap = _main.get_node("UI/KingdomMap")
	await _shot("00_map")
	map.get_node("%MarchButton").pressed.emit()  # the map preselects the newest open castle
	await _wait(0.6)
	print("Castle: %s" % GameState.castle.display_name)

	var day: DayPhase = _main.get_node("UI/DayPhase")
	var machine: SlotMachine = day.get_node("%SlotMachine")
	var field: Battlefield = _main.get_node("Battlefield")
	for night in range(1, _nights + 1):
		await _wait(0.6)
		var spins := 0 if _idle else GameState.spins_per_day()
		for i in spins:
			day.get_node("%SpinButton").pressed.emit()
			while day.is_busy():
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
			GameState.machine_rows, GameState.paylines.size(), GameState.run_upgrades])
		day.get_node("%StartNightButton").pressed.emit()
		Engine.time_scale = BATTLE_SPEED
		await _wait(3.0)
		await _shot("%02d_night_battle" % night)
		while field.is_night:
			await get_tree().process_frame
		Engine.time_scale = 1.0
		print("  -> after night %d: castle %d, troops left %d, kills %d, upkeep due %d" % [night, GameState.castle_hp, field.get_troops().size(), GameState.kills, field.upkeep_cost()])
		if GameState.castle_hp <= 0:
			print("  castle fell")
			await _wait(0.5)
			await _shot("%02d_game_over" % night)
			return
		await _wait(2.5)
		print("  dawn: gold %d, morale %d%%" % [GameState.gold, roundi(field.morale * 100.0)])


func _buy_forge_upgrades(_forge: TimeForge) -> void:
	var bought := true
	while bought:
		bought = false
		for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
			if MetaProgress.buy(upgrade):
				bought = true
	_forge.open()  # rebuild the tree to show the result


func _buy_everything_affordable(day: DayPhase) -> void:
	var cards: VBoxContainer = day.get_node("%Shop").get_node("%Cards")
	for card: OfferCard in cards.get_children():
		if not card.offer.sold and GameState.gold >= card.offer.cost:
			print("  bought: %s (%d)" % [card.offer.title, card.offer.cost])
			card.get_child(0).get_child(-1).pressed.emit()  # the card's real Buy button


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots_dir, shot_name])
