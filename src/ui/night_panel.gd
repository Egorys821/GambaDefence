class_name NightPanel
extends Control
## Full-screen overlay during the night battle: title banner, a slim status bar
## and the speed toggle. Leaves the battlefield visible.
##
## The chosen speed (x1 / x2 / x3) is remembered for every night and saved to
## user://settings.cfg.

const SPEEDS: Array[float] = [1.0, 2.0, 3.0]
const SETTINGS_PATH := "user://settings.cfg"

var _speed := 1.0

@onready var _banner: Label = %Banner
@onready var _subtitle: Label = %Subtitle
@onready var _status_bar: Control = %StatusBar
@onready var _enemies_label: Label = %EnemiesLabel
@onready var _defenders_label: Label = %DefendersLabel
@onready var _speed_button: Button = %SpeedButton


func _ready() -> void:
	_speed_button.pressed.connect(_on_speed_pressed)
	_speed = _load_speed()
	_banner.modulate.a = 0.0
	_subtitle.modulate.a = 0.0


func begin_night(night: int) -> void:
	Engine.time_scale = _speed
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
	var next := (SPEEDS.find(_speed) + 1) % SPEEDS.size()
	_speed = SPEEDS[next]
	Engine.time_scale = _speed
	_save_speed()
	Audio.play(&"click")
	_update_speed_text()


func _update_speed_text() -> void:
	_speed_button.text = "Speed x%d" % roundi(_speed)


func _load_speed() -> float:
	var file := ConfigFile.new()
	file.load(SETTINGS_PATH)
	var saved: float = file.get_value("game", "night_speed", 1.0)
	return saved if saved in SPEEDS else 1.0


func _save_speed() -> void:
	var file := ConfigFile.new()
	file.load(SETTINGS_PATH)  # keep the audio settings in the same file
	file.set_value("game", "night_speed", _speed)
	file.save(SETTINGS_PATH)
