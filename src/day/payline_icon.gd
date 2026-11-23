class_name PaylineIcon
extends Control
## Tiny diagram of one pattern shape on the machine grid. The shape is drawn
## bold at the top and faint at every lower height it also pays at.

const DOT := 5
const PAD := 2

var shapes: Array = []
var shape := 0
var rows := 3
var reels := 5


func setup(p_shapes: Array, p_shape: int, p_rows: int) -> void:
	shapes = p_shapes
	shape = p_shape
	rows = p_rows
	reels = Paylines.shape_offsets(shapes, shape).size()
	custom_minimum_size = Vector2(reels * DOT + PAD * 2, rows * DOT + PAD * 2)
	var lines := Paylines.lines_of(shapes, shape, rows).size()
	tooltip_text = "%s - pays on %d line%s" % [Paylines.shape_name(shapes, shape), lines, "" if lines == 1 else "s"]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color(0, 0, 0, 0.35))
	for reel in reels:
		for row in rows:
			draw_rect(Rect2(_cell(reel, row) - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 1, 0.25))
	var lines := Paylines.lines_of(shapes, shape, rows)
	for i in range(lines.size() - 1, -1, -1):
		var line := lines[i]
		var points := PackedVector2Array()
		for reel in reels:
			points.append(_cell(reel, line.rows[reel]))
		var strength := 1.0 if i == 0 else 0.35
		draw_polyline(points, Color(line.color(), strength), 1.5 if i == 0 else 1.0)


func _cell(reel: int, row: int) -> Vector2:
	return Vector2(PAD, PAD) + (Vector2(reel, row) + Vector2(0.5, 0.5)) * DOT
