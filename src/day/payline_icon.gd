class_name PaylineIcon
extends Control
## Tiny diagram of one payline: a grid of dots with the line drawn through it.

const DOT := 5
const PAD := 2

var line := 0
var rows := 3


func setup(p_line: int, p_rows: int) -> void:
	line = p_line
	rows = p_rows
	custom_minimum_size = Vector2(5 * DOT + PAD * 2, rows * DOT + PAD * 2)
	tooltip_text = Paylines.name_of(line)
	queue_redraw()


func _draw() -> void:
	var color := Paylines.color_of(line)
	draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color(0, 0, 0, 0.35))
	for reel in 5:
		for row in rows:
			draw_rect(Rect2(_cell(reel, row) - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 1, 0.25))
	var points := PackedVector2Array()
	var line_rows := Paylines.rows_of(line)
	for reel in 5:
		points.append(_cell(reel, line_rows[reel]))
	draw_polyline(points, color, 1.5)


func _cell(reel: int, row: int) -> Vector2:
	return Vector2(PAD, PAD) + (Vector2(reel, row) + Vector2(0.5, 0.5)) * DOT
