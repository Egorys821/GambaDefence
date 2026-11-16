class_name NightPanel
extends Control
## Full-screen overlay during the night battle: title banner, a slim status bar
## and the speed toggle. Leaves the battlefield visible.

@onready var _banner: Label = %Banner
@onready var _subtitle: Label = %Subtitle
@onready var _status_bar: Control = %StatusBar
@onready var _enemies_label: Label = %EnemiesLabel
@onready var _defenders_label: Label = %DefendersLabel
@onready var _speed_button: Button = %SpeedButton


func _ready() -> void:
	_speed_button.pressed.connect(_on_speed_pressed)
	_banner.modulate.a = 0.0
	_subtitle.modulate.a = 0.0


func begin_night(night: int) -> void:
	_update_speed_text()
	show()
	_status_bar.show()
	_speed_button.show()
	var title := "Final Night" if night >= GameState.max_nights() else "Night %d" % night
	show_banner(title, "The spirits rise from their graves...", Color("#a0a8ff"))


func end_night() -> void:
	Engine.time_scale = 1.0
	_status_bar.hide()
	_speed_button.hide()


## Big centred title that fades in and out.
func show_banner(title: String, subtitle: String, color: Color) -> void:
	show()
	_banner.text = title
	_banner.add_theme_color_override("font_color", color)
	_subtitle.text = subtitle
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * 0.6
	var tween := create_tween().set_parallel()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.4)
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_subtitle, "modulate:a", 1.0, 0.6).set_delay(0.2)
	tween.chain().tween_interval(1.4)
	tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.6)


func set_status(enemies_left: int, defenders: int) -> void:
	_enemies_label.text = "Spirits: %d" % enemies_left
	_defenders_label.text = "Defenders: %d" % defenders


func _on_speed_pressed() -> void:
	Engine.time_scale = 2.0 if is_equal_approx(Engine.time_scale, 1.0) else 1.0
	Audio.play(&"click")
	_update_speed_text()


func _update_speed_text() -> void:
	_speed_button.text = "Speed x%d" % roundi(Engine.time_scale)
