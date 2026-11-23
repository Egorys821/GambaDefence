class_name LineOverlay
extends Control
## Draws over the reels: winning paylines (traced from left to right), boxes
## around the cells of other wins (ways, expansions, prizes), and labels on
## locked cells (Dragon's Hoard chests). Everything shown gently pulses.

const TRACE_TIME := 0.25
const LOCK_COLOR := Color("#f8d038")

## Rect2 of a cell in this control's space: func(reel: int, row: int) -> Rect2.
var cell_rect: Callable
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
		draw_polyline(traced, Color(color, 0.3 * pulse), 6.0)
		draw_polyline(traced, Color(color, pulse), 2.0)
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


func _draw_lock(cell: Vector2i, text: String, pulse: float) -> void:
	var rect := _rect(cell)
	draw_rect(rect.grow(-1), Color(LOCK_COLOR, pulse), false, 2.0)
	var font := get_theme_default_font()
	var font_size := 7
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(rect.get_center().x - width * 0.5, rect.end.y - 3)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _frame(cell: Vector2i, color: Color) -> void:
	draw_rect(_rect(cell).grow(-1), color, false, 2.0)


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
