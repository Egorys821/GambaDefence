class_name SlotMachine
extends Panel
## The magic slot machine: 5 reels, 3 to 5 rows (GameState.machine_rows).
## Rolls symbols from GameState.pool, scrolls the reels, then presents each
## winning payline one after another. Rewards are applied by DayPhase.

## All reels stopped; nothing has been evaluated yet.
signal symbols_landed(grid: Array)
## Fired once per winning line, in presentation order (smallest win first).
signal line_won(win: LineWin, index: int)
## Every line has been presented.
signal spin_finished(wins: Array[LineWin], grid: Array)

enum ReelState { IDLE, SPINNING, STOPPING, LANDING }

const REELS := 5
const PADDING := 6
## Cell size per row count. Multiples of 8 keep the 16px pixel art crisp.
const CELL_SIZE_BY_ROWS := {3: 40, 4: 40, 5: 32}
const SPIN_SPEED := 720.0  # pixels per second
const SPIN_TIME := 0.45  # before the first reel stops
const REEL_STAGGER := 0.16
## Extra suspense before a reel that could extend a win to 4 or 5 of a kind.
const TEASE_TIME := 0.75
const LINE_SHOW_TIME := 0.45
const REEL_COLOR := Color("#e8d8b0")
const REEL_COLOR_ALT := Color("#dccaa0")
const TEASE_COLOR := Color("#f8d038")

var is_spinning := false
var rows := 0
var cell_size := 40
## grid[reel][row] -> SymbolData currently shown.
var _grid: Array = []
## Per reel: rows + 1 symbols, index 0 is hidden just above the window.
var _strips: Array = []
## Per reel: TextureRects matching _strips.
var _cells: Array = []
var _offsets: Array[float] = []
var _states: Array[int] = []  # ReelState per reel
## Per reel: final symbols still to scroll in while stopping.
var _queues: Array = []
var _tease_glows: Array[ColorRect] = []

@onready var _reels: Control = %Reels
@onready var _overlay: LineOverlay = %LineOverlay


func _ready() -> void:
	add_theme_stylebox_override("panel", _make_frame_style())
	configure(GameState.machine_rows)


## (Re)builds the reels for a row count. Safe to call between spins.
func configure(row_count: int) -> void:
	if row_count == rows or is_spinning:
		return
	rows = row_count
	cell_size = CELL_SIZE_BY_ROWS.get(rows, 24)
	var reels_size := Vector2(REELS, rows) * cell_size
	custom_minimum_size = reels_size + Vector2.ONE * PADDING * 2
	size = custom_minimum_size
	for control: Control in [_reels, _overlay]:
		control.position = Vector2.ONE * PADDING
		control.size = reels_size
	_overlay.cell_size = cell_size
	_overlay.clear()
	_build_reels()
	_grid = _roll_grid()
	for reel in REELS:
		_strips[reel] = [GameState.roll_symbol()] + _grid[reel]
		_apply_textures(reel)
		_layout_reel(reel)


func _process(delta: float) -> void:
	for reel in REELS:
		if _states[reel] != ReelState.SPINNING and _states[reel] != ReelState.STOPPING:
			continue
		_offsets[reel] += SPIN_SPEED * delta * cell_size / 32.0
		while _offsets[reel] >= cell_size and _states[reel] != ReelState.LANDING:
			_offsets[reel] -= cell_size
			_advance_reel(reel)
		_layout_reel(reel)


func spin() -> void:
	if is_spinning:
		return
	is_spinning = true
	_overlay.clear()
	_reset_cell_effects()
	var result := _roll_grid()
	Audio.play(&"spin")
	for reel in REELS:
		_states[reel] = ReelState.SPINNING
		_set_blur(reel, true)
	await _wait(SPIN_TIME)
	for reel in REELS:
		if reel > 0:
			if _should_tease(result, reel):
				_set_tease(reel, true)
				Audio.play(&"tease")
				await _wait(TEASE_TIME)
			else:
				await _wait(REEL_STAGGER)
		# Symbols scroll in at the top, so feed the final column bottom-first,
		# then one filler that ends up hidden above the window.
		var queue: Array = result[reel].duplicate()
		queue.reverse()
		queue.append(GameState.roll_symbol())
		_queues[reel] = queue
		_states[reel] = ReelState.STOPPING
	while not _all_reels_idle():
		await get_tree().process_frame

	_grid = result
	symbols_landed.emit(result)
	var wins := evaluate(result, GameState.paylines)
	wins.sort_custom(func(a: LineWin, b: LineWin) -> bool: return a.count < b.count)
	await _wait(0.15)
	for i in wins.size():
		_present_win(wins[i], i)
		line_won.emit(wins[i], i)
		await _wait(LINE_SHOW_TIME)
	is_spinning = false
	spin_finished.emit(wins, result)


## Global position of the centre of a cell, used for reward effects.
func cell_center(reel: int, row: int) -> Vector2:
	return _reels.global_position + Vector2(reel + 0.5, row + 0.5) * cell_size


## Finds every paying line. Symbols match from the leftmost reel; wilds match
## anything they are wild for (see SymbolData.wild_for).
static func evaluate(grid: Array, payline_ids: Array[int]) -> Array[LineWin]:
	var wins: Array[LineWin] = []
	for line in payline_ids:
		var result := best_match(grid, Paylines.rows_of(line), grid.size())
		var count: int = result[0]
		var base: SymbolData = result[1]
		if count < Paylines.MIN_MATCH or base == null or base.effect == SymbolData.Effect.NONE:
			continue
		wins.append(LineWin.new(line, base, count))
	return wins


## Longest match from the left along `rows` within the first `reels` reels.
## Returns [count, symbol the line pays as]. Every non-wild symbol on the line
## is tried as the paying symbol, so group wilds pick the one they help most.
static func best_match(grid: Array, rows: Array, reels: int) -> Array:
	var candidates: Array[SymbolData] = []
	for reel in reels:
		var symbol: SymbolData = grid[reel][rows[reel]]
		if not symbol.is_wild():
			if symbol not in candidates:
				candidates.append(symbol)
		else:
			for target in symbol.wild_for:
				if target not in candidates:
					candidates.append(target)
	if candidates.is_empty():
		# Only wilds: a line of universal wilds pays as the wild itself,
		# a line of group wilds pays as the first symbol of their group.
		var first: SymbolData = grid[0][rows[0]]
		candidates.append(first if first.wild_for.is_empty() else first.wild_for[0])
	var best_count := 0
	var best_symbol: SymbolData = null
	for candidate in candidates:
		var count := 0
		for reel in reels:
			var symbol: SymbolData = grid[reel][rows[reel]]
			if symbol.id == candidate.id or symbol.is_wild_for(candidate):
				count += 1
			else:
				break
		if count > best_count:
			best_count = count
			best_symbol = candidate
	return [best_count, best_symbol]


# --- Reel mechanics -----------------------------------------------------------

func _advance_reel(reel: int) -> void:
	var strip: Array = _strips[reel]
	strip.pop_back()
	if _states[reel] == ReelState.STOPPING:
		strip.push_front(_queues[reel].pop_front())
		if _queues[reel].is_empty():
			_land_reel(reel)
	else:
		strip.push_front(GameState.roll_symbol())
	_apply_textures(reel)


## The last symbol scrolled in: settle back with a little bounce.
func _land_reel(reel: int) -> void:
	_states[reel] = ReelState.LANDING
	_set_blur(reel, false)
	var tween := create_tween()
	tween.tween_method(_set_offset.bind(reel), _offsets[reel] + 4.0, 0.0, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_reel_landed.bind(reel))


func _on_reel_landed(reel: int) -> void:
	_states[reel] = ReelState.IDLE
	_set_tease(reel, false)
	Audio.play(&"reel_stop", 1.0 + reel * 0.05)


func _set_offset(value: float, reel: int) -> void:
	_offsets[reel] = value
	_layout_reel(reel)


func _layout_reel(reel: int) -> void:
	for i in rows + 1:
		var cell: TextureRect = _cells[reel][i]
		cell.position = Vector2(reel * cell_size, (i - 1) * cell_size + _offsets[reel])


func _apply_textures(reel: int) -> void:
	for i in rows + 1:
		var symbol: SymbolData = _strips[reel][i]
		var cell: TextureRect = _cells[reel][i]
		cell.texture = symbol.texture
		cell.tooltip_text = "%s\n%s" % [symbol.display_name, symbol.description]


func _all_reels_idle() -> bool:
	for state in _states:
		if state != ReelState.IDLE:
			return false
	return true


## Tease when every reel so far matches on some payline and a win is already
## guaranteed, so the next reel decides between a normal and a big win.
func _should_tease(result: Array, reel: int) -> bool:
	if reel < Paylines.MIN_MATCH:
		return false
	for line in GameState.paylines:
		if best_match(result, Paylines.rows_of(line), reel)[0] >= reel:
			return true
	return false


# --- Presentation ---------------------------------------------------------------

func _present_win(win: LineWin, index: int) -> void:
	var line_rows := Paylines.rows_of(win.payline)
	var color := Paylines.color_of(win.payline)
	_overlay.add_win(win)
	if win.symbol.effect == SymbolData.Effect.CURSE:
		Audio.play(&"castle_hit", 0.8)
		color = Color("#ff3040")
	else:
		Audio.play(&"win", 1.0 + index * 0.12)
	for reel in win.count:
		var cell: TextureRect = _cells[reel][line_rows[reel] + 1]
		var tween := cell.create_tween()
		tween.tween_interval(reel * 0.05)
		tween.tween_callback(_pop_cell.bind(cell, color))


func _pop_cell(cell: TextureRect, color: Color) -> void:
	cell.pivot_offset = cell.size * 0.5
	cell.z_index = 1
	cell.modulate = Color(1.8, 1.8, 1.8)
	Fx.pop(cell, 1.45, 0.3)
	cell.create_tween().tween_property(cell, "modulate", Color.WHITE, 0.3)
	Fx.burst(self, cell.position + _reels.position + cell.size * 0.5, color, 10, 70.0)


func _reset_cell_effects() -> void:
	for column: Array in _cells:
		for cell: TextureRect in column:
			cell.scale = Vector2.ONE
			cell.z_index = 0
			cell.modulate = Color.WHITE


func _set_blur(reel: int, spinning: bool) -> void:
	for cell: TextureRect in _cells[reel]:
		cell.self_modulate = Color(0.85, 0.85, 0.9, 0.85) if spinning else Color.WHITE


func _set_tease(reel: int, on: bool) -> void:
	var glow := _tease_glows[reel]
	var tween := glow.create_tween()
	tween.tween_property(glow, "color:a", 0.55 if on else 0.0, 0.15)


# --- Setup ------------------------------------------------------------------------

func _roll_grid() -> Array:
	var grid := []
	for reel in REELS:
		var column := []
		for row in rows:
			column.append(GameState.roll_symbol())
		grid.append(column)
	return grid


func _build_reels() -> void:
	for child in _reels.get_children():
		child.queue_free()
	_cells.clear()
	_strips.clear()
	_offsets.clear()
	_states.clear()
	_queues.clear()
	_tease_glows.clear()
	for reel in REELS:
		var strip := ColorRect.new()
		strip.color = REEL_COLOR if reel % 2 == 0 else REEL_COLOR_ALT
		strip.position = Vector2(reel * cell_size, 0)
		strip.size = Vector2(cell_size, rows * cell_size)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reels.add_child(strip)
		var glow := ColorRect.new()
		glow.color = Color(TEASE_COLOR, 0.0)
		glow.position = strip.position
		glow.size = strip.size
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reels.add_child(glow)
		_tease_glows.append(glow)
		var column := []
		for i in rows + 1:
			var cell := TextureRect.new()
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cell.size = Vector2.ONE * cell_size
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
			_reels.add_child(cell)
			column.append(cell)
		_cells.append(column)
		_strips.append([])
		_offsets.append(0.0)
		_states.append(ReelState.IDLE)
		_queues.append([])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _make_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3a2414")
	style.border_color = Color("#c08820")
	style.set_border_width_all(3)
	return style
