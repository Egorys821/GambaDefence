extends Node
## Screenshots every slot machine with its feature forced on: the idle
## cabinet, a win, and the feature's own presentation (nudge arrows, gamble
## card, hoard round, free spins with an expanding symbol, cascades), plus the
## Time Forge machine preview. Never touches the real save file.
##
## Run from the project root (needs a window, so no --headless):
##   godot --path . res://tools/debug/machine_gallery.tscn -- --shots=C:/tmp/machines
## Flags:
##   --shots=DIR     where to save the screenshots (required)
##   --machine=ID    only this machine (data/machines/, e.g. dragons_hoard)
##   --rows=N        row upgrades for machines that use them (default 3)

const MAIN_SCENE := preload("res://src/main/main.tscn")

var _shots_dir := ""
var _only := &""
var _rows := 3
var _main: Node
var _day: DayPhase
var _machine: SlotMachine


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(_shots_dir)
		elif arg.begins_with("--machine="):
			_only = StringName(arg.get_slice("=", 1))
		elif arg.begins_with("--rows="):
			_rows = int(arg.get_slice("=", 1))
	MetaProgress.persist = false
	MetaProgress.levels.clear()
	MetaProgress.shards = 0
	MetaProgress.runs = 1
	MetaProgress.tutorial_done = true
	MetaProgress.conquered.clear()
	for style: MachineStyle in GameState.machines.values():
		_unlock(style)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _wait(0.5)
	await _forge_previews()
	await _start_run()
	for style in _styles():
		await _show_machine(style)
	get_tree().quit()


func _styles() -> Array[MachineStyle]:
	var result: Array[MachineStyle] = []
	for style: MachineStyle in GameState.machines.values():
		if _only == &"" or style.id == _only:
			result.append(style)
	result.sort_custom(func(a: MachineStyle, b: MachineStyle) -> bool: return a.order < b.order)
	return result


func _unlock(style: MachineStyle) -> void:
	var castle := GameState.machine_castle(style)
	if castle and castle.id not in MetaProgress.conquered:
		MetaProgress.conquered.append(castle.id)
	var unlock := GameState.machine_unlock(style)
	if unlock:
		MetaProgress.levels[unlock.id] = 1


func _forge_previews() -> void:
	var menu: MainMenu = _main.get_node("UI/MainMenu")
	menu.get_node("%UpgradesButton").pressed.emit()
	await _wait(0.5)
	var forge: TimeForge = _main.get_node("UI/TimeForge")
	forge.show_window(0, false)
	for style in _styles():
		var node := GameState.machine_node(style)
		if node == null:
			continue
		forge._select(node)
		await _wait(0.9)
		await _shot("forge_%d_%s" % [style.order, style.id])
	forge.get_node("%BeginButton").pressed.emit()
	await _wait(0.6)


func _start_run() -> void:
	var menu: MainMenu = _main.get_node("UI/MainMenu")
	menu.get_node("%PlayButton").pressed.emit()
	await _wait(0.6)
	var map: KingdomMap = _main.get_node("UI/KingdomMap")
	map._select(GameState.castles[0])
	map.get_node("%MarchButton").pressed.emit()
	await _wait(1.0)
	_day = _main.get_node("UI/DayPhase")
	_machine = _day.get_node("%SlotMachine")


func _show_machine(style: MachineStyle) -> void:
	MetaProgress.selected_machine = style.id
	MetaProgress.levels[&"extra_row"] = maxi(0, _rows - 3)
	GameState.reset()
	await _wait(0.8)
	var tag := "%d_%s" % [style.order, style.id]
	print("Machine: %s (%d reels, %d rows)" % [style.display_name, style.reel_count, _machine.rows])
	await _shot(tag + "_a_idle")
	match style.feature:
		MachineStyle.Feature.NUDGE:
			await _forced_spin(_line_grid(&"coin"), tag + "_b_win")
			_machine.ask("Nudge a reel down one row?", ["Reel 1", "Reel 2", "Reel 3", "Skip"], true)
			await _wait(0.5)
			await _shot(tag + "_c_nudge")
			_machine.decline_choice()
		MachineStyle.Feature.GAMBLE:
			var grid := _line_grid(&"coin")
			grid[1][0] = GameState.get_symbol(&"jester")
			_spin_async(grid)
			await _wait(2.2)
			await _shot(tag + "_b_ways_win")
			await _until_choice()
			await _shot(tag + "_c_gamble")
			_machine._prompt.choose(0)
			await _wait(0.35)
			await _shot(tag + "_d_card")
			await _finish()
		MachineStyle.Feature.HOLD_AND_WIN:
			var grid := _filler_grid()
			var needed := GameState.feature_trigger()
			var cells := GridOps.all_cells(grid)
			cells.shuffle()
			for i in needed:
				grid[cells[i].x][cells[i].y] = style.feature_symbol
			_spin_async(grid)
			await _wait(3.0)
			await _shot(tag + "_b_hoard_start")
			await _wait(2.5)
			await _shot(tag + "_c_hoard_respins")
			await _finish(tag + "_d_hoard_payout")
		MachineStyle.Feature.FREE_SPINS:
			var grid := _filler_grid()
			for reel in [0, 2, 4]:
				grid[reel][1] = style.feature_symbol
			_spin_async(grid)
			await _wait(4.2)
			await _shot(tag + "_b_free_spins")
			await _finish()
			await _expansion_demo(tag)
		MachineStyle.Feature.CASCADE:
			var grid := _machine.roll_grid()
			var coin := GameState.get_symbol(&"coin")
			for reel in grid.size():
				grid[reel][0] = coin
			_spin_async(grid)
			await _wait(2.6)
			await _shot(tag + "_b_win")
			await _wait(0.9)
			await _shot(tag + "_c_cascade")
			await _finish()
		_:
			await _forced_spin(_line_grid(&"coin"), tag + "_b_win")


## Tome: a free spin where the expanding symbol fills four reels.
func _expansion_demo(tag: String) -> void:
	var symbol := GameState.get_symbol(&"coin")
	_machine.is_spinning = true
	_machine.cabinet.set_free_spins(4, 3, symbol)
	_machine.set_status("Free spin 3")
	var grid := _filler_grid(&"sword")
	for reel in [0, 1, 3, 4]:
		grid[reel][reel % _machine.rows] = symbol
	await _machine.spin_to(grid)
	var expansion := BookExpansion.evaluate(_machine.grid, symbol, GameState.active_paylines().size(), 4)
	await _machine.show_grid(BookExpansion.expanded_grid(_machine.grid, symbol))
	_machine.present([expansion])
	await _wait(0.5)
	await _shot(tag + "_c_expansion")
	await _wait(1.0)
	_machine.cabinet.end_free_spins()
	_machine.set_status("")
	_machine.is_spinning = false


func _forced_spin(grid: Array, shot_name: String) -> void:
	_spin_async(grid)
	await _wait(2.9)
	await _shot(shot_name)
	await _finish()


## Plays one spin that lands on `grid`, with the machine's feature after it.
func _spin_async(grid: Array) -> void:
	_machine.is_spinning = true
	_machine.cabinet.on_spin()
	_machine.set_status("")
	await _machine.spin_to(grid)
	if MachineRules.uses_ways(_machine.grid, _machine.style):
		_machine._show_ways()
	var wins := _machine.evaluate(_machine.grid)
	await _machine.present(wins)
	await _machine._feature.after_spin(_machine, wins)
	_machine.is_spinning = false


## Waits for the spin to end, declining questions (shot once if named).
func _finish(shot_name := "") -> void:
	var waited := 0.0
	while _machine.is_spinning and waited < 30.0:
		if _machine.is_awaiting_choice():
			_machine.decline_choice()
		await get_tree().process_frame
		waited += get_process_delta_time()
	if shot_name != "":
		await _shot(shot_name)
	await _wait(0.5)


func _until_choice() -> void:
	var waited := 0.0
	while not _machine.is_awaiting_choice() and waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


## The middle row full of `id`, the rest swords and skulls.
func _line_grid(id: StringName) -> Array:
	var grid := _filler_grid()
	var row := mini(1, _machine.rows - 1)
	for reel in grid.size():
		grid[reel][row] = GameState.get_symbol(id)
	return grid


## A losing-looking grid of the machine's shape.
func _filler_grid(first := &"sword") -> Array:
	var ids := [first, &"bow", &"skull", &"coin"]
	var grid := []
	for reel in _machine.style.reel_count:
		var column := []
		for row in _machine.rows:
			var symbol := GameState.get_symbol(ids[(reel + row * 2) % ids.size()])
			column.append(symbol if symbol else GameState.roll_symbol())
		grid.append(column)
	return grid


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots_dir, shot_name])
	print("  shot ", shot_name)
