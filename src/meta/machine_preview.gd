class_name MachinePreview
extends Control
## A small, live picture of a slot machine for the Time Forge: its cabinet
## frame and crest (MachineSkin), its reel layout and a few of its symbols.
## The reels give a little spin every few seconds.

const CELL := 12
const PAD := 5
const SPIN_EVERY := 2.6
const SPIN_TIME := 0.5
const SHUFFLE_STEP := 0.06

var _style: MachineStyle
var _symbols: Array[Texture2D] = []
## Per reel: Array[TextureRect] of its cells.
var _reels: Array = []
var _clock := 0.0
var _shuffle := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(88, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_style(style: MachineStyle) -> void:
	if style == _style:
		return
	_style = style
	_clock = SPIN_EVERY - 0.3
	_collect_symbols()
	_build()


func _process(delta: float) -> void:
	if _style == null or not is_visible_in_tree():
		return
	_clock += delta
	if _clock < SPIN_EVERY:
		return
	var spin_age := _clock - SPIN_EVERY
	if spin_age > SPIN_TIME + _reels.size() * 0.08:
		_clock = 0.0
		return
	_shuffle -= delta
	if _shuffle > 0.0:
		return
	_shuffle = SHUFFLE_STEP
	for i in _reels.size():
		if spin_age < SPIN_TIME + i * 0.08:
			for cell: TextureRect in _reels[i]:
				cell.texture = _symbols.pick_random()


func _collect_symbols() -> void:
	_symbols.clear()
	var picks: Array[SymbolData] = []
	for entry: PoolEntry in _style.start_symbols:
		picks.append(entry.symbol)
	for symbol: SymbolData in [_style.signature_symbol, _style.feature_symbol]:
		if symbol:
			picks.append(symbol)
	for id: StringName in [&"coin", &"sword", &"bow", &"coin"]:
		var symbol := GameState.get_symbol(id)
		if symbol:
			picks.append(symbol)
	for symbol in picks:
		if symbol.texture:
			_symbols.append(symbol.texture)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_reels.clear()
	var skin := MachineSkin.for_style(_style)
	var columns := _style.reel_count
	var rows := 3 if not _style.variable_rows else _style.max_rows
	var window := Vector2(columns, rows) * CELL
	var frame_size := window + Vector2.ONE * PAD * 2
	var origin := Vector2(roundf((custom_minimum_size.x - frame_size.x) * 0.5), custom_minimum_size.y - frame_size.y)
	var back := ColorRect.new()
	back.color = skin.bg_color
	back.position = origin + Vector2.ONE * 2
	back.size = frame_size - Vector2.ONE * 4
	add_child(back)
	for reel in columns:
		var height: int = rows if not _style.variable_rows else [2, 4, 3, 4, 2, 3][reel % 6]
		var top := origin + Vector2(PAD + reel * CELL, PAD + (rows - height) * CELL * 0.5)
		var strip := TextureRect.new()
		strip.texture = skin.reel
		strip.stretch_mode = TextureRect.STRETCH_TILE
		strip.position = top
		strip.size = Vector2(CELL, height * CELL)
		strip.modulate = Color.WHITE if reel % 2 == 0 else Color(0.93, 0.93, 0.93)
		add_child(strip)
		var cells: Array[TextureRect] = []
		for row in height:
			var cell := TextureRect.new()
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cell.texture = _symbols.pick_random() if not _symbols.is_empty() else null
			cell.position = top + Vector2(0, row * CELL)
			cell.size = Vector2.ONE * CELL
			add_child(cell)
			cells.append(cell)
		_reels.append(cells)
	var frame := NinePatchRect.new()
	frame.texture = skin.frame
	frame.draw_center = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		frame.set_patch_margin(side, MachineSkin.FRAME_MARGIN)
	frame.position = origin - Vector2.ONE * 3
	frame.size = frame_size + Vector2.ONE * 6
	add_child(frame)
	var crest := TextureRect.new()
	crest.texture = skin.crest
	crest.size = skin.crest.get_size()
	crest.position = Vector2(roundf((custom_minimum_size.x - crest.size.x) * 0.5), frame.position.y - crest.size.y + 6)
	add_child(crest)
	for child in get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
