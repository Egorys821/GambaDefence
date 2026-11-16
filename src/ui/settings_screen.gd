class_name SettingsScreen
extends Control
## Volume sliders (master / music / effects), quit to menu during a run, and
## a full progress reset. Pauses the game while open.

signal closed
## The player chose to abandon the current run.
signal quit_run_requested

## Set by Main: true while a run is being played.
var in_run := false
var _quit_armed := false

var _delete_armed := false

@onready var _sliders := {
	Audio.MASTER_BUS: %MasterSlider,
	Audio.MUSIC_BUS: %MusicSlider,
	Audio.SFX_BUS: %SfxSlider,
}
@onready var _close_button: Button = %CloseButton
@onready var _delete_button: Button = %DeleteButton
@onready var _quit_run_button: Button = %QuitRunButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: StringName in _sliders:
		var slider: HSlider = _sliders[bus]
		slider.value_changed.connect(_on_slider_changed.bind(bus))
	_close_button.pressed.connect(close)
	_delete_button.pressed.connect(_on_delete_pressed)
	_quit_run_button.pressed.connect(_on_quit_run_pressed)
	hide()


func open() -> void:
	for bus: StringName in _sliders:
		(_sliders[bus] as HSlider).set_value_no_signal(Audio.get_volume(bus) * 100.0)
	_delete_armed = false
	_delete_button.text = "Delete all progress"
	_delete_button.visible = not in_run  # don't wipe the save mid-run
	_quit_armed = false
	_quit_run_button.text = "Quit to main menu"
	_quit_run_button.visible = in_run
	get_tree().paused = true
	show()


func close() -> void:
	Audio.play(&"click")
	get_tree().paused = false
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_slider_changed(value: float, bus: StringName) -> void:
	Audio.set_volume(bus, value / 100.0)
	if bus != Audio.MUSIC_BUS:
		Audio.play(&"coin", 1.0, 0.0)


func _on_quit_run_pressed() -> void:
	if not _quit_armed:
		_quit_armed = true
		_quit_run_button.text = "Give up this run? Click again"
		return
	Audio.play(&"click")
	get_tree().paused = false
	hide()
	quit_run_requested.emit()


func _on_delete_pressed() -> void:
	if not _delete_armed:
		_delete_armed = true
		_delete_button.text = "Click again to delete everything!"
		return
	MetaProgress.reset_progress()
	_delete_armed = false
	_delete_button.text = "Progress deleted"
	Audio.play(&"denied")
