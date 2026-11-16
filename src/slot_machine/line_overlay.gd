class_name LineOverlay
extends Control
## Draws winning paylines over the reels. Each new line is traced from left to
## right, then all shown lines gently pulse.

const TRACE_TIME := 0.25

var cell_size := 32
## Each entry: {"win": LineWin, "progress": float 0..1}
var _entries: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	_time += delta
	queue_redraw()


func add_win(win: LineWin) -> void:
	var entry := {"win": win, "progress": 0.0}
	_entries.append(entry)
	create_tween().tween_method(func(p: float) -> void: entry["progress"] = p, 0.0, 1.0, TRACE_TIME)


func clear() -> void:
	_entries.clear()
	queue_redraw()


func _draw() -> void:
	var pulse := 0.75 + 0.25 * sin(_time * 8.0)
	for entry in _entries:
		var win: LineWin = entry["win"]
		var progress: float = entry["progress"]
		var rows := Paylines.rows_of(win.payline)
		var color := Paylines.color_of(win.payline)
		var points := PackedVector2Array()
		for reel in rows.size():
			points.append((Vector2(reel, rows[reel]) + Vector2(0.5, 0.5)) * cell_size)
		var traced := _partial_line(points, progress)
		if traced.size() >= 2:
			draw_polyline(traced, Color(color, 0.3 * pulse), 6.0)
			draw_polyline(traced, Color(color, pulse), 2.0)
		for reel in win.count:
			if progress * (rows.size() - 1) + 0.01 < reel:
				continue
			var top_left := Vector2(reel, rows[reel]) * cell_size + Vector2.ONE
			draw_rect(Rect2(top_left, Vector2.ONE * (cell_size - 2)), Color(color, pulse), false, 2.0)


## The first `progress` (0..1) of a polyline, measured by segments.
func _partial_line(points: PackedVector2Array, progress: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var segments := points.size() - 1
	var travelled := progress * segments
	for i in points.size():
		if i <= travelled:
			result.append(points[i])
		else:
			result.append(points[i - 1].lerp(points[i], travelled - (i - 1)))
			break
	return result
