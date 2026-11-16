class_name FloatingText
extends Label
## Short-lived text that drifts up and fades out ("+5 gold", "+2 Archers").

const RISE := 16.0
const DURATION := 1.0


static func spawn(parent: Node, message: String, at: Vector2, color: Color = Color.WHITE, font_size: int = 8) -> void:
	var label := FloatingText.new()
	label.text = message
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	label.reset_size()
	label.position = at - label.size * 0.5
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - RISE, DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DURATION).set_delay(DURATION * 0.4)
	tween.chain().tween_callback(label.queue_free)
