class_name SlotMachine
extends Panel
## The magic slot machine. Its layout and rules come from the run's
## MachineStyle (GameState.machine): 3 to 6 reels, fixed or variable heights,
## lines or ways, and one bonus feature (see MachineFeature).
##
## Runs a spin from start to finish: rolls the result, spins and stops the
## Reels (with suspense when a big win is building), evaluates with
## MachineRules, presents each win, then lets the feature continue the spin
## (free spins, respins, cascades, a gamble...). Rewards are applied by
## DayPhase through the signals below.

## Reels stopped. `cells` are the cells that just landed (passive effects).
signal symbols_landed(grid: Array, cells: Array[Vector2i])
## Fired once per win, in presentation order.
signal won(win: SlotWin, index: int)
## A big moment worth a banner ("FREE SPINS!", "81 WAYS!").
signal announced(text: String, color: Color)
## The spin and its feature are over.
signal spin_finished(wins: Array[SlotWin])

const PADDING := 6
## Cell size per row count. Multiples of 8 keep the 16px pixel art crisp.
const CELL_SIZE_BY_ROWS := {3: 40, 4: 40, 5: 32}
## Machines with few reels get bigger cells.
const SMALL_MACHINE_CELL := 48
## Variable-height machines: every reel fits this box, cells shrink to fit.
const VARIABLE_REEL_WIDTH := 40
const VARIABLE_HEIGHT := 160
const SPIN_TIME := 0.45  # before the first reel stops
const REEL_STAGGER := 0.16
## Extra suspense before a reel that could make the win bigger.
const TEASE_TIME := 0.75
const LINE_SHOW_TIME := 0.45
const CURSE_COLOR := Color("#ff3040")

var is_spinning := false
var style: MachineStyle
var rows := 0
var cell_size := 40
## grid[reel][row] -> SymbolData currently shown.
var grid: Array = []
var _reels: Array[Reel] = []
## While a hold-and-win round runs, every cell is its own one-row reel.
var _cell_reels: Dictionary = {}
var _feature: MachineFeature
var _spin_wins: Array[SlotWin] = []

@onready var _reel_area: Control = %Reels
@onready var _overlay: LineOverlay = %LineOverlay
var _prompt: ChoicePrompt
var _status: Label


func _ready() -> void:
	_overlay.cell_rect = _cell_rect
	_prompt = ChoicePrompt.new()
	add_child(_prompt)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 8)
	_status.add_theme_color_override("font_color", Color("#f8d038"))
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 4)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)
	configure()


## (Re)builds the machine for GameState's style and rows. Safe between spins.
func configure() -> void:
	if is_spinning or (style == GameState.machine and rows == GameState.machine_rows):
		return
	style = GameState.machine
	rows = GameState.machine_rows
	_feature = MachineFeature.create(style)
	add_theme_stylebox_override("panel", _make_frame_style())
	if style.variable_rows:
		cell_size = VARIABLE_REEL_WIDTH
	elif style.reel_count <= 4:
		cell_size = SMALL_MACHINE_CELL
	else:
		cell_size = CELL_SIZE_BY_ROWS.get(rows, 32)
	var area := _area_size()
	custom_minimum_size = area + Vector2.ONE * PADDING * 2
	size = custom_minimum_size
	for control: Control in [_reel_area, _overlay]:
		control.position = Vector2.ONE * PADDING
		control.size = area
	_status.position = Vector2(0, -13)
	_status.size = Vector2(size.x, 12)
	_overlay.clear()
	set_status("")
	grid = roll_grid()
	_build_reels()


func spin() -> void:
	if is_spinning:
		return
	is_spinning = true
	_spin_wins.clear()
	_overlay.clear()
	Audio.play(&"spin")
	await spin_to(roll_grid())
	if MachineRules.uses_ways(grid, style):
		_show_ways()
	await wait(0.15)
	var wins := evaluate(grid)
	await present(wins)
	await _feature.after_spin(self, wins)
	is_spinning = false
	spin_finished.emit(_spin_wins)


# --- API for features -----------------------------------------------------------

## A fresh random result for this machine.
func roll_grid() -> Array:
	var bonus := GameState.stat_int(style.min_rows_stat) if style.min_rows_stat != &"" else 0
	return GridOps.roll(MachineRules.roll_heights(style, rows, bonus), GameState.roll_symbol)


func evaluate(p_grid: Array) -> Array[SlotWin]:
	return MachineRules.evaluate(p_grid, style, GameState.active_paylines())


## Spins every reel and stops them left to right on `result`.
func spin_to(result: Array) -> void:
	_overlay.clear()
	for reel in _reels:
		reel.start_spin()
	if style.variable_rows:
		for reel in _reels:
			reel.reshape(result[reel.index].size(), _variable_cell(result[reel.index].size()))
		_place_reels(result)
	await wait(SPIN_TIME)
	for reel in _reels:
		if reel.index > 0:
			if _should_tease(result, reel.index):
				reel.set_tease(true)
				Audio.play(&"tease")
				await wait(TEASE_TIME)
			else:
				await wait(REEL_STAGGER)
		reel.stop_on(result[reel.index])
	await _until_idle(_reels)
	grid = result
	symbols_landed.emit(grid, GridOps.all_cells(grid))


## Shows each win in turn and fires `won` for its reward.
func present(wins: Array[SlotWin]) -> void:
	for win in wins:
		var index := _spin_wins.size()
		_spin_wins.append(win)
		_present_win(win, index)
		won.emit(win, index)
		await wait(LINE_SHOW_TIME)


## Asks the player a question over the reels; returns the option index.
func ask(question: String, options: Array[String]) -> int:
	return await _prompt.ask(question, options)


func is_awaiting_choice() -> bool:
	return _prompt.is_open()


## Picks the safe answer of the open question (Collect, Skip).
func decline_choice() -> void:
	_prompt.decline()


func announce(text: String, color: Color = Color("#f8d038")) -> void:
	announced.emit(text, color)


## Small text above the reels ("Free spin 2/10", "Respins: 3").
func set_status(text: String) -> void:
	_status.text = text


## Moves one reel down a row; `new_top` scrolls in.
func nudge_reel(reel_index: int, new_top: SymbolData) -> void:
	_overlay.clear()
	var reel := _reels[reel_index]
	reel.nudge(new_top)
	await _until_idle([reel])
	grid = GridOps.nudge(grid, reel_index, new_top)
	var landed: Array[Vector2i] = [Vector2i(reel_index, 0)]
	symbols_landed.emit(grid, landed)


## Shows `p_grid` at once without spinning (an expanding symbol filling reels).
func show_grid(p_grid: Array) -> void:
	for reel in _reels:
		if p_grid[reel.index] != grid[reel.index]:
			reel.show_symbols(p_grid[reel.index])
			reel.set_tease(true)
			Fx.burst(self, reel.position + _reel_area.position + reel.size * 0.5, Color("#f8d038"), 14, 60.0)
	Audio.play(&"big_win", 1.3, -6.0)
	await wait(0.4)
	for reel in _reels:
		reel.set_tease(false)


## Cascade, part 1: the winning cells burst and vanish.
func explode(cells: Array[Vector2i]) -> void:
	_overlay.clear()
	for cell in cells:
		var node := _cell_node(cell)
		Fx.burst(self, _cell_rect(cell.x, cell.y).get_center() + _reel_area.position, Color.WHITE, 6, 50.0)
		node.create_tween().tween_property(node, "modulate:a", 0.0, 0.15)
	Audio.play(&"coin", 0.7, -4.0)
	await wait(0.2)


## Cascade, part 2: the rest falls down and new symbols drop in.
## `result` comes from GridOps.collapse.
func cascade_to(result: Dictionary) -> void:
	var new_grid: Array = result["grid"]
	for reel in _reels:
		reel.drop_in(new_grid[reel.index], result["falls"][reel.index])
	await wait(Reel.DROP_TIME + 0.05)
	grid = new_grid
	symbols_landed.emit(grid, result["new_cells"])


## Hold and win: every cell becomes its own reel. Cells not showing `keep`
## turn into `empty`.
func enter_cell_mode(keep: SymbolData, empty: SymbolData) -> void:
	for reel_index in grid.size():
		for row in grid[reel_index].size():
			if (grid[reel_index][row] as SymbolData).id != keep.id:
				grid[reel_index][row] = empty
	_build_cell_reels()
	await wait(0.3)


## Spins only the given cells and stops each on its symbol (cell -> SymbolData).
func spin_cells(targets: Dictionary) -> void:
	var spinning: Array[Reel] = []
	for cell: Vector2i in targets:
		var reel: Reel = _cell_reels[cell]
		reel.start_spin()
		spinning.append(reel)
	await wait(SPIN_TIME)
	for cell: Vector2i in targets:
		_cell_reels[cell].stop_on([targets[cell]])
		grid[cell.x][cell.y] = targets[cell]
		await wait(0.05)
	await _until_idle(spinning)


func lock_cell(cell: Vector2i, text: String) -> void:
	_overlay.set_lock(cell, text)
	var node := _cell_node(cell)
	node.pivot_offset = node.size * 0.5
	Fx.pop(node, 1.3, 0.25)


func exit_cell_mode() -> void:
	_overlay.clear()
	_build_reels()


## Global position of the centre of a cell, used for reward effects.
func cell_center(reel: int, row: int) -> Vector2:
	return _reel_area.global_position + _cell_rect(reel, row).get_center()


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --- Presentation -----------------------------------------------------------------

func _should_tease(result: Array, reels: int) -> bool:
	return MachineRules.is_building_big_win(result, style, GameState.active_paylines(), reels) \
		or _feature.wants_tease(result, reels)


func _show_ways() -> void:
	var ways := 1
	for column: Array in grid:
		ways *= column.size()
	set_status("%d WAYS" % ways)
	if style.eval_mode == MachineStyle.Eval.LINES_OR_WAYS:
		announce("%d WAYS!" % ways, Color("#d090ff"))
		Audio.play(&"tease")


func _present_win(win: SlotWin, index: int) -> void:
	_overlay.add_win(win)
	var color := win.color
	if win.effect() == SymbolData.Effect.CURSE:
		Audio.play(&"castle_hit", 0.8)
		color = CURSE_COLOR
	else:
		Audio.play(&"win", 1.0 + index * 0.12)
	for cell in win.cells:
		var node := _cell_node(cell)
		if node == null:
			continue
		var tween := node.create_tween()
		tween.tween_interval(cell.x * 0.05)
		tween.tween_callback(_pop_cell.bind(node, color))


func _pop_cell(cell: TextureRect, color: Color) -> void:
	cell.pivot_offset = cell.size * 0.5
	cell.z_index = 1
	cell.modulate = Color(1.8, 1.8, 1.8)
	Fx.pop(cell, 1.45, 0.3)
	cell.create_tween().tween_property(cell, "modulate", Color.WHITE, 0.3)
	var local := cell.get_global_rect().get_center() - global_position
	Fx.burst(self, local, color, 10, 70.0)


func _until_idle(reels: Array[Reel]) -> void:
	while not reels.all(func(reel: Reel) -> bool: return reel.is_idle()):
		await get_tree().process_frame


# --- Layout -----------------------------------------------------------------------

func _area_size() -> Vector2:
	if style.variable_rows:
		return Vector2(style.reel_count * VARIABLE_REEL_WIDTH, VARIABLE_HEIGHT)
	return Vector2(style.reel_count, rows) * cell_size


func _variable_cell(height: int) -> int:
	return clampi(floori(VARIABLE_HEIGHT / float(height) / 8.0) * 8, 16, VARIABLE_REEL_WIDTH)


## A cell's rectangle inside the reel area.
func _cell_rect(reel: int, row: int) -> Rect2:
	if not style.variable_rows:
		return Rect2(Vector2(reel, row) * cell_size, Vector2.ONE * cell_size)
	var height: int = grid[reel].size()
	var cell := _variable_cell(height)
	var top_left := Vector2(
		reel * VARIABLE_REEL_WIDTH + (VARIABLE_REEL_WIDTH - cell) * 0.5,
		(VARIABLE_HEIGHT - height * cell) * 0.5 + row * cell)
	return Rect2(top_left, Vector2.ONE * cell)


func _cell_node(cell: Vector2i) -> TextureRect:
	if not _cell_reels.is_empty():
		return (_cell_reels[cell] as Reel).cell_at(0)
	if cell.x >= _reels.size() or cell.y >= _reels[cell.x].rows:
		return null
	return _reels[cell.x].cell_at(cell.y)


func _reel_color(index: int) -> Color:
	return style.reel_colors[index % style.reel_colors.size()]


func _clear_reels() -> void:
	for child in _reel_area.get_children():
		child.queue_free()
	_reels.clear()
	_cell_reels.clear()


func _build_reels() -> void:
	_clear_reels()
	for i in style.reel_count:
		var reel := Reel.new()
		_reel_area.add_child(reel)
		var column: Array = grid[i]
		reel.setup(i, _variable_cell(column.size()) if style.variable_rows else cell_size, column, _reel_color(i))
		_reels.append(reel)
	_place_reels(grid)


func _place_reels(p_grid: Array) -> void:
	var saved := grid
	grid = p_grid  # _cell_rect reads the heights
	for reel in _reels:
		reel.position = _cell_rect(reel.index, 0).position
	grid = saved


func _build_cell_reels() -> void:
	_clear_reels()
	for reel_index in grid.size():
		for row in grid[reel_index].size():
			var reel := Reel.new()
			_reel_area.add_child(reel)
			reel.setup(reel_index, cell_size, [grid[reel_index][row]], _reel_color(reel_index + row))
			reel.position = _cell_rect(reel_index, row).position
			_cell_reels[Vector2i(reel_index, row)] = reel


func _make_frame_style() -> StyleBoxFlat:
	var frame := StyleBoxFlat.new()
	frame.bg_color = style.bg_color
	frame.border_color = style.frame_color
	frame.set_border_width_all(3)
	return frame
