class_name Payline
extends RefCounted
## One concrete winning line: a pattern shape (see Paylines) placed `shift`
## rows down from the top of the machine.

var shape: int
var shift: int
var shape_name: String
## Row on each reel, top = 0.
var rows: Array[int] = []


func _init(shapes: Array, p_shape: int, p_shift: int) -> void:
	shape = p_shape
	shift = p_shift
	shape_name = Paylines.shape_name(shapes, shape)
	for offset: int in Paylines.shape_offsets(shapes, shape):
		rows.append(offset + shift)


func display_name() -> String:
	if shape == Paylines.STRAIGHT:
		return "Row %d" % (shift + 1)
	return shape_name if shift == 0 else "%s (%d down)" % [shape_name, shift]


func color() -> Color:
	return Paylines.shape_color(shape).lightened(0.12 * shift)
