class_name MainMenu
extends Control
## Title screen. Emits `chosen` with one of the CHOICE_* ids.

signal chosen(choice: StringName)

const CHOICE_PLAY := &"play"
const CHOICE_TUTORIAL := &"tutorial"
const CHOICE_UPGRADES := &"upgrades"
const CHOICE_SETTINGS := &"settings"
const CHOICE_PREVIEW := &"preview"
const CHOICE_MERCHANT := &"merchant"
const CHOICE_ABOUT := &"about"
const CHOICE_QUIT := &"quit"
const COIN_TEXTURE := preload("res://assets/sprites/symbols/coin.png")

var _time := 0.0

@onready var _title: Label = %Title
@onready var _shard_label: Label = %ShardLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _buttons := {
	CHOICE_PLAY: %PlayButton,
	CHOICE_TUTORIAL: %TutorialButton,
	CHOICE_UPGRADES: %UpgradesButton,
	CHOICE_SETTINGS: %SettingsButton,
	CHOICE_PREVIEW: %PreviewButton,
	CHOICE_MERCHANT: %MerchantButton,
	CHOICE_ABOUT: %AboutButton,
	CHOICE_QUIT: %QuitButton,
}


func _ready() -> void:
	for choice: StringName in _buttons:
		(_buttons[choice] as Button).pressed.connect(_on_button_pressed.bind(choice))
	%QuitButton.visible = OS.get_name() != "Web"
	hide()


func open() -> void:
	_shard_label.text = "%d Chrono Shards" % MetaProgress.shards
	_progress_label.text = "Castles conquered: %d / %d   -   Runs: %d" % [
		MetaProgress.conquered.size(), GameState.castles.size(), MetaProgress.runs]
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	var delay := 0.0
	for button: Button in _buttons.values():
		button.modulate.a = 0.0
		var tween := button.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(button, "modulate:a", 1.0, 0.2)
		delay += 0.06


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = sin(_time * 1.3) * 0.02
	_title.scale = Vector2.ONE * (1.0 + sin(_time * 2.0) * 0.02)
	if randf() < delta * 0.8:
		Fx.burst(self, Vector2(randf_range(40, 600), randf_range(60, 120)), Color.WHITE, 6, 90.0, COIN_TEXTURE, 1.2, 220.0)


func _on_button_pressed(choice: StringName) -> void:
	Audio.play(&"click")
	hide()
	chosen.emit(choice)
