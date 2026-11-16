class_name BurstEffect
extends Node2D
## Expanding ring shown when a splash attack lands.

const DURATION := 0.3

var radius := 16.0
var color := Color.WHITE
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := _t / DURATION
	draw_arc(Vector2.ZERO, radius * progress, 0.0, TAU, 20, Color(color, 1.0 - progress), 2.0)
