class_name MessageScreen
extends Control
## Modal message used for the intro, game over and victory screens.
## An optional second button (e.g. "Upgrade Tree" after a run): check
## `chose_alt` after `confirmed`.

signal confirmed

## The second button was pressed (reset by every show_message).
var chose_alt := false

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _button: Button = %ConfirmButton
@onready var _alt_button: Button = %AltButton


func _ready() -> void:
	_button.pressed.connect(_on_confirm_pressed.bind(false))
	_alt_button.pressed.connect(_on_confirm_pressed.bind(true))
	hide()


func show_message(title: String, body: String, button_text: String, alt_text := "") -> void:
	_title.text = title
	_body.text = body
	_button.text = button_text
	_alt_button.text = alt_text
	_alt_button.visible = alt_text != ""
	chose_alt = false
	show()


func _on_confirm_pressed(alt: bool) -> void:
	chose_alt = alt
	hide()
	confirmed.emit()
