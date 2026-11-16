class_name Fx
extends RefCounted
## Small reusable "juice" effects: particle bursts, flying icons and shakes.
## Works with both world nodes (Node2D) and UI nodes (Control) as parents.


## One-shot particle burst. Pass a texture for coins etc, or none for pixel sparks.
static func burst(parent: Node, at: Vector2, color: Color, amount: int = 12, speed: float = 60.0,
		texture: Texture2D = null, lifetime: float = 0.5, gravity: float = 120.0) -> void:
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0, gravity)
	particles.color = color
	particles.z_index = 30
	if texture:
		particles.texture = texture
		particles.scale_amount_min = 0.5
		particles.scale_amount_max = 0.8
		particles.angular_velocity_min = -360.0
		particles.angular_velocity_max = 360.0
	else:
		particles.scale_amount_min = 1.0
		particles.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## Flies an icon along an arc between two global positions (UI space).
## Returns the tween so the caller can react when it lands.
static func fly_icon(parent: Control, texture: Texture2D, from_global: Vector2, to_global: Vector2,
		duration: float = 0.5, icon_size: float = 14.0, delay: float = 0.0) -> Tween:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2.ONE * icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 40
	icon.visible = delay <= 0.0
	parent.add_child(icon)
	var half := icon.size * 0.5
	var start := from_global - parent.global_position - half
	var end := to_global - parent.global_position - half
	var control_point := (start + end) * 0.5 + Vector2(randf_range(-40, 40), -60)
	icon.position = start
	var tween := icon.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_callback(icon.show)
	var move_along_arc := func(t: float) -> void:
		icon.position = start.lerp(control_point, t).lerp(control_point.lerp(end, t), t)
		icon.scale = Vector2.ONE * (1.0 + sin(t * PI) * 0.4)
	tween.tween_method(move_along_arc, 0.0, 1.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(icon.queue_free)
	return tween


## Quick jitter of a Control around its current position.
static func shake_control(control: Control, strength: float = 4.0, duration: float = 0.3) -> void:
	var base := control.position
	var tween := control.create_tween()
	var steps := 8
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff
		tween.tween_property(control, "position", base + offset, duration / steps)
	tween.tween_property(control, "position", base, 0.03)


## Scale "pop" for a Control or Node2D (uses its pivot / origin).
static func pop(node: CanvasItem, amount: float = 1.3, duration: float = 0.25) -> void:
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * amount, duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
