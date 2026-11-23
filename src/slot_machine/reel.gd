class_name Reel
extends Control
## One column of the slot machine. Scrolls random symbols while spinning,
## then scrolls in its final symbols and lands with a small bounce. Can also
## be nudged one row, reshaped (variable-height machines) and refilled by a
## cascade. The machine places it; the reel only lays out its own cells.
##
## The strip holds rows + 1 symbols: index 0 sits hidden just above the window,
## indices 1..rows are the visible rows.

signal landed(reel: Reel)

enum State { IDLE, SPINNING, STOPPING, LANDING }

## Scroll speed in pixels per second for 32px cells (scaled to the cell size).
const SPIN_SPEED := 720.0
const LAND_TIME := 0.22
const LAND_OVERSHOOT := 4.0
const DROP_TIME := 0.22
const TEASE_COLOR := Color("#f8d038")
const BLUR_TINT := Color(0.85, 0.85, 0.9, 0.85)

var index := 0
var rows := 0
var cell_size := 40
var state := State.IDLE

var _strip: Array[SymbolData] = []
var _cells: Array[TextureRect] = []
var _queue: Array[SymbolData] = []
var _offset := 0.0
var _color := Color.WHITE
var _glow: ColorRect


## Builds the reel showing `symbols` (one per row, top first).
func setup(p_index: int, p_cell_size: int, symbols: Array, color: Color) -> void:
	index = p_index
	_color = color
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build(symbols.size(), p_cell_size)
	_strip.assign([GameState.roll_symbol()] + symbols)
	_refresh_textures()


func _process(delta: float) -> void:
	if state != State.SPINNING and state != State.STOPPING:
		return
	_offset += SPIN_SPEED * delta * cell_size / 32.0
	while _offset >= cell_size and state != State.LANDING:
		_offset -= cell_size
		_advance()
	_layout()


func start_spin() -> void:
	reset_effects()
	state = State.SPINNING
	_set_blur(true)


## Changes the height while spinning (hidden by the motion blur).
func reshape(p_rows: int, p_cell_size: int) -> void:
	if p_rows == rows and p_cell_size == cell_size:
		return
	_build(p_rows, p_cell_size)
	_strip.clear()
	for i in rows + 1:
		_strip.append(GameState.roll_symbol())
	_refresh_textures()
	_set_blur(state == State.SPINNING)


## Stops on `symbols` (one per row, top first).
func stop_on(symbols: Array) -> void:
	# New symbols enter at the top, so feed the column bottom-first, then one
	# filler that ends up hidden above the window.
	_queue.assign(symbols.duplicate())
	_queue.reverse()
	_queue.append(GameState.roll_symbol())
	state = State.STOPPING


## Moves the reel one row down; `new_top` scrolls in at the top.
func nudge(new_top: SymbolData) -> void:
	reset_effects()
	_strip[0] = new_top
	_refresh_textures()
	_queue.assign([GameState.roll_symbol()])
	state = State.STOPPING


## Shows `symbols` at once (e.g. an expanding symbol filling the reel).
func show_symbols(symbols: Array) -> void:
	for row in rows:
		_strip[row + 1] = symbols[row]
	_refresh_textures()


## Cascade: shows `symbols` and drops each cell from `falls[row]` rows above.
func drop_in(symbols: Array, falls: Array) -> void:
	reset_effects()
	show_symbols(symbols)
	var tween := create_tween().set_parallel()
	var moving := false
	for row in rows:
		var fall: int = falls[row]
		var cell := _cells[row + 1]
		var target := cell.position.y
		if fall > 0:
			moving = true
			cell.position.y = target - fall * cell_size
			tween.tween_property(cell, "position:y", target, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not moving:
		tween.kill()
		return
	await tween.finished
	Audio.play(&"reel_stop", 1.1 + index * 0.05, -4.0)


func is_idle() -> bool:
	return state == State.IDLE


func set_tease(on: bool) -> void:
	_glow.create_tween().tween_property(_glow, "color:a", 0.55 if on else 0.0, 0.15)


## The cell showing `row` (0 = top) once the reel has landed.
func cell_at(row: int) -> TextureRect:
	return _cells[row + 1]


func reset_effects() -> void:
	for cell in _cells:
		cell.scale = Vector2.ONE
		cell.z_index = 0
		cell.modulate = Color.WHITE
	_layout()


# --- Internals ----------------------------------------------------------------

func _build(p_rows: int, p_cell_size: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_cells.clear()
	rows = p_rows
	cell_size = p_cell_size
	size = Vector2(cell_size, rows * cell_size)
	_add_rect(_color)
	_glow = _add_rect(Color(TEASE_COLOR, 0.0))
	for i in rows + 1:
		var cell := TextureRect.new()
		cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.size = Vector2.ONE * cell_size
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(cell)
		_cells.append(cell)
	_layout()


func _advance() -> void:
	_strip.pop_back()
	if state == State.STOPPING:
		_strip.push_front(_queue.pop_front())
		if _queue.is_empty():
			_land()
	else:
		_strip.push_front(GameState.roll_symbol())
	_refresh_textures()


## Settles back from the overshoot with a little bounce.
func _land() -> void:
	state = State.LANDING
	_set_blur(false)
	var tween := create_tween()
	tween.tween_method(_set_offset, _offset + LAND_OVERSHOOT, 0.0, LAND_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_landed)


func _on_landed() -> void:
	state = State.IDLE
	set_tease(false)
	Audio.play(&"reel_stop", 1.0 + index * 0.05)
	landed.emit(self)


func _set_offset(value: float) -> void:
	_offset = value
	_layout()


func _layout() -> void:
	for i in _cells.size():
		_cells[i].position = Vector2(0, (i - 1) * cell_size + _offset)


func _refresh_textures() -> void:
	for i in _cells.size():
		var symbol := _strip[i]
		_cells[i].texture = symbol.texture
		_cells[i].tooltip_text = "%s\n%s" % [symbol.display_name, symbol.description] if symbol.texture else ""


func _set_blur(on: bool) -> void:
	for cell in _cells:
		cell.self_modulate = BLUR_TINT if on else Color.WHITE


func _add_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect
