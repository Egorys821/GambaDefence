class_name LineOverlay
extends Control
## Draws over the reels: winning paylines (traced from left to right), boxes
## around the cells of other wins (ways, expansions, prizes), and labels on
## locked cells (Dragon's Hoard chests). Everything shown gently pulses.
## While wins are shown, the cells that didn't win are dimmed.

const TRACE_TIME := 0.25
const LOCK_COLOR := Color("#f8d038")
const DIM_COLOR := Color(0.05, 0.03, 0.08, 0.4)
const JACKPOT_COLORS := {
	"GRAND": Color("#ff6050"), "MAJOR": Color("#d080ff"), "MINOR": Color("#60b8ff"), "MINI": Color("#80f060"),
}

## Rect2 of a cell in this control's space: func(reel: int, row: int) -> Rect2.
var cell_rect: Callable
## Every cell on the reels: func() -> Array[Vector2i]. Used to dim losers.
var all_cells: Callable
## The machine skin's accent (corner sparks on winning cells).
var accent := Color.WHITE
## Each entry: {"win": SlotWin, "progress": float 0..1}
var _entries: Array[Dictionary] = []
## Locked cell (Vector2i) -> short label.
var _locks: Dictionary = {}
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _entries.is_empty() and _locks.is_empty():
		return
	_time += delta
	queue_redraw()


func add_win(win: SlotWin) -> void:
	var entry := {"win": win, "progress": 0.0}
	_entries.append(entry)
	create_tween().tween_method(func(p: float) -> void: entry["progress"] = p, 0.0, 1.0, TRACE_TIME)


func set_lock(cell: Vector2i, text: String) -> void:
	_locks[cell] = text
	queue_redraw()


func clear() -> void:
	_entries.clear()
	_locks.clear()
	queue_redraw()


func _draw() -> void:
	var pulse := 0.75 + 0.25 * sin(_time * 8.0)
	_dim_losers()
	for cell: Vector2i in _locks:
		_draw_lock(cell, _locks[cell], pulse)
	for entry in _entries:
		var win: SlotWin = entry["win"]
		if win.payline:
			_draw_line_win(win, entry["progress"], pulse)
		else:
			_draw_cells(win.cells, win.color, entry["progress"], pulse)


func _draw_line_win(win: SlotWin, progress: float, pulse: float) -> void:
	var rows := win.payline.rows
	var color := win.color
	var points := PackedVector2Array()
	for reel in rows.size():
		points.append(_rect(Vector2i(reel, rows[reel])).get_center())
	var traced := _partial_line(points, progress)
	if traced.size() >= 2:
		draw_polyline(traced, Color(0, 0, 0, 0.45), 5.0)
		draw_polyline(traced, Color(color, 0.3 * pulse), 8.0)
		draw_polyline(traced, Color(color, pulse), 3.0)
		draw_polyline(traced, Color(1, 1, 1, 0.6 * pulse), 1.0)
		for point in traced:
			draw_circle(point, 2.5, Color(color.lightened(0.4), pulse))
	# Frame each matched cell once the trace has reached it.
	for cell in win.cells:
		if progress * (rows.size() - 1) + 0.01 >= cell.x:
			_frame(cell, Color(color, pulse))


func _draw_cells(cells: Array[Vector2i], color: Color, progress: float, pulse: float) -> void:
	var reels := 1
	for cell in cells:
		reels = maxi(reels, cell.x + 1)
	for cell in cells:
		if progress * reels + 0.01 >= cell.x:
			_frame(cell, Color(color, pulse))


## A locked hoard chest: glowing gold frame and a prize ribbon (jackpots in
## their own colour).
func _draw_lock(cell: Vector2i, text: String, pulse: float) -> void:
	var rect := _rect(cell)
	var color: Color = JACKPOT_COLORS.get(text, LOCK_COLOR)
	draw_rect(rect.grow(-2), Color(color, 0.15 * pulse))
	draw_rect(rect.grow(-1), Color(color, pulse), false, 2.0)
	var font := get_theme_default_font()
	var font_size := 8
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ribbon := Rect2(rect.position.x + 2, rect.end.y - 11, rect.size.x - 4, 9)
	draw_rect(ribbon, Color(0.08, 0.05, 0.02, 0.85))
	draw_rect(ribbon, Color(color, 0.9), false, 1.0)
	var at := Vector2(rect.get_center().x - width * 0.5, ribbon.end.y - 2)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color.lightened(0.5))


## A winning cell: a coloured frame with bright corner brackets.
func _frame(cell: Vector2i, color: Color) -> void:
	var rect := _rect(cell).grow(-1)
	draw_rect(rect, color, false, 2.0)
	var corner := 5.0
	var bright := Color(accent.lerp(Color.WHITE, 0.5), color.a)
	for x_side in [0, 1]:
		for y_side in [0, 1]:
			var p := rect.position + rect.size * Vector2(x_side, y_side)
			var dx := corner if x_side == 0 else -corner
			var dy := corner if y_side == 0 else -corner
			draw_line(p, p + Vector2(dx, 0), bright, 2.0)
			draw_line(p, p + Vector2(0, dy), bright, 2.0)


## Darkens the cells that are not part of any win shown right now.
func _dim_losers() -> void:
	if _entries.is_empty() or not all_cells.is_valid():
		return
	var winners := {}
	var fade := 0.0
	for entry in _entries:
		fade = maxf(fade, entry["progress"])
		for cell: Vector2i in (entry["win"] as SlotWin).cells:
			winners[cell] = true
	for cell: Vector2i in _locks:
		winners[cell] = true
	if winners.is_empty():
		return
	for cell: Vector2i in all_cells.call():
		if not winners.has(cell):
			draw_rect(_rect(cell), Color(DIM_COLOR, DIM_COLOR.a * fade))


func _rect(cell: Vector2i) -> Rect2:
	return cell_rect.call(cell.x, cell.y)


## The first `progress` (0..1) of a polyline, measured by segments.
func _partial_line(points: PackedVector2Array, progress: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var travelled := progress * (points.size() - 1)
	for i in points.size():
		if i <= travelled:
			result.append(points[i])
		else:
			result.append(points[i - 1].lerp(points[i], travelled - (i - 1)))
			break
	return result
