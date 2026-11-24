class_name MainMenu
extends Control
## Title screen. Emits `chosen` with one of the CHOICE_* ids.
##
## Buttons sit in a column on the left, each with an icon and a colour by
## kind: Play is gold, the Time Forge is cyan (the colour of the Forge screen
## and of Chrono Shards, so it is easy to find), Quit is red, the rest wood.
## The middle shows animated scenes of the game (MenuShowcase).

signal chosen(choice: StringName)

const CHOICE_PLAY := &"play"
const CHOICE_TUTORIAL := &"tutorial"
const CHOICE_UPGRADES := &"upgrades"
const CHOICE_SETTINGS := &"settings"
const CHOICE_PREVIEW := &"preview"
const CHOICE_MERCHANT := &"merchant"
const CHOICE_ABOUT := &"about"
const CHOICE_QUIT := &"quit"

## Button colours by kind: background, accent (left stripe and border), text.
const KINDS := {
	&"play": {"bg": Color("#c8861e"), "accent": Color("#ffe080"), "text": Color("#2a1404")},
	&"forge": {"bg": Color("#0f3646"), "accent": Color("#60d8f8"), "text": Color("#c8f4ff")},
	&"wood": {"bg": Color("#2e1c10"), "accent": Color("#a0702c"), "text": Color(1, 0.93, 0.78)},
	&"quit": {"bg": Color("#2e1210"), "accent": Color("#b04030"), "text": Color(1, 0.85, 0.8)},
}
const BUTTON_KIND := {
	CHOICE_PLAY: &"play",
	CHOICE_UPGRADES: &"forge",
	CHOICE_QUIT: &"quit",
}
const ICONS := {
	CHOICE_PLAY: preload("res://assets/sprites/symbols/sword.png"),
	CHOICE_UPGRADES: preload("res://assets/sprites/ui/shard.png"),
	CHOICE_MERCHANT: preload("res://assets/sprites/ui/cart.png"),
	CHOICE_PREVIEW: preload("res://assets/sprites/symbols/helm.png"),
	CHOICE_SETTINGS: preload("res://assets/sprites/ui/bolts.png"),
	CHOICE_ABOUT: preload("res://assets/sprites/symbols/tome.png"),
	CHOICE_QUIT: preload("res://assets/sprites/symbols/skull.png"),
	CHOICE_TUTORIAL: preload("res://assets/sprites/ui/payline.png"),
}
const SLIDE := 24.0

var _time := 0.0

@onready var _title: Label = %Title
@onready var _shard_label: Label = %ShardLabel
@onready var _crown_label: Label = %CrownLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _showcase: MenuShowcase = %Showcase
@onready var _buttons := {
	CHOICE_PLAY: %PlayButton,
	CHOICE_UPGRADES: %UpgradesButton,
	CHOICE_MERCHANT: %MerchantButton,
	CHOICE_PREVIEW: %PreviewButton,
	CHOICE_SETTINGS: %SettingsButton,
	CHOICE_ABOUT: %AboutButton,
	CHOICE_QUIT: %QuitButton,
	CHOICE_TUTORIAL: %TutorialButton,
}


func _ready() -> void:
	for choice: StringName in _buttons:
		var button: Button = _buttons[choice]
		button.pressed.connect(_on_button_pressed.bind(choice))
		_style_button(button, KINDS[BUTTON_KIND.get(choice, &"wood")], ICONS.get(choice))
	%UpgradesButton.tooltip_text = "Spend Chrono Shards and Crowns on permanent upgrades."
	%QuitButton.visible = OS.get_name() != "Web"
	hide()


func open() -> void:
	_shard_label.text = "%d Chrono Shards" % MetaProgress.shards
	_crown_label.text = "%d Crown%s" % [MetaProgress.crowns(), "" if MetaProgress.crowns() == 1 else "s"]
	_progress_label.text = "Castles conquered: %d / %d   -   Runs: %d" % [
		MetaProgress.conquered.size(), GameState.castles.size(), MetaProgress.runs]
	show()
	_showcase.start()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	# Buttons slide in from the left, one after another.
	var delay := 0.0
	for button: Button in _buttons.values():
		button.modulate.a = 0.0
		var tween := button.create_tween().set_parallel()
		tween.tween_property(button, "modulate:a", 1.0, 0.2).set_delay(delay)
		tween.tween_method(_set_slide.bind(button), -SLIDE, 0.0, 0.25).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.05


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_title.pivot_offset = Vector2(0, _title.size.y * 0.5)
	_title.scale = Vector2.ONE * (1.0 + sin(_time * 2.0) * 0.015)


## Buttons live in a container, so slide them with their content instead of position.
func _set_slide(offset: float, button: Button) -> void:
	button.position.x = offset


func _on_button_pressed(choice: StringName) -> void:
	Audio.play(&"click")
	hide()
	chosen.emit(choice)


## Flat button with an accent stripe on the left and an icon; the label
## slides right a little on hover.
func _style_button(button: Button, kind: Dictionary, icon: Texture2D) -> void:
	var bg: Color = kind["bg"]
	var accent: Color = kind["accent"]
	var normal := _button_box(bg, accent.darkened(0.25), 10)
	var hover := _button_box(bg.lightened(0.18), accent, 14)
	hover.shadow_color = Color(accent, 0.35)
	hover.shadow_size = 3
	var pressed := _button_box(bg.darkened(0.2), accent, 13)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", _button_box(bg.darkened(0.4), accent.darkened(0.6), 10))
	var text: Color = kind["text"]
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text.lightened(0.2))
	button.add_theme_color_override("font_pressed_color", text.darkened(0.1))
	button.add_theme_color_override("font_hover_pressed_color", text)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6) if text.v > 0.5 else Color(1, 1, 1, 0.25))
	button.add_theme_constant_override("outline_size", 3 if text.v > 0.5 else 1)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if icon:
		button.icon = icon
		button.add_theme_constant_override("icon_max_width", 16 if button.custom_minimum_size.y >= 26 else 12)
		button.add_theme_constant_override("h_separation", 6)
	button.mouse_entered.connect(func() -> void: Audio.play(&"click", 1.6, -18.0))


func _button_box(bg: Color, accent: Color, margin_left: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = accent
	box.set_border_width_all(1)
	box.border_width_left = 4
	box.set_corner_radius_all(3)
	box.content_margin_left = margin_left
	box.content_margin_right = 8
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box
