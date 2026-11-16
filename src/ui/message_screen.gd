class_name MessageScreen
extends Control
## Modal message used for the intro, game over and victory screens.

signal confirmed

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _button: Button = %ConfirmButton


func _ready() -> void:
	_button.pressed.connect(_on_confirm_pressed)
	hide()


func show_message(title: String, body: String, button_text: String) -> void:
	_title.text = title
	_body.text = body
	_button.text = button_text
	show()


func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit()
