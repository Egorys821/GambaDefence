class_name ChoicePrompt
extends PanelContainer
## A small question shown over the reels mid-spin (gamble, nudge). The last
## option is always the safe one: Space or `decline()` picks it.

signal chosen(index: int)

var _label: Label
var _buttons: HBoxContainer
var _option_count := 0


func _ready() -> void:
	hide()
	z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 3)
	box.add_child(_buttons)


## Shows the question and waits for an answer. Returns the option's index.
## `low` puts it at the bottom of the machine (the reels stay visible).
func ask(question: String, options: Array[String], low := false) -> int:
	_label.text = question
	for child in _buttons.get_children():
		_buttons.remove_child(child)  # now, so the old buttons don't widen the panel
		child.queue_free()
	_option_count = options.size()
	for i in options.size():
		var button := Button.new()
		button.text = options[i]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 8)
		button.pressed.connect(choose.bind(i))
		_buttons.add_child(button)
	show()
	reset_size()
	var parent := get_parent() as Control
	position = (parent.size - size) * 0.5
	if low:
		position.y = parent.size.y - size.y - 2
	Fx.pop(self, 1.1, 0.2)
	var index: int = await chosen
	hide()
	return index


func is_open() -> bool:
	return visible


## Picks the safe (last) option.
func decline() -> void:
	if visible:
		choose(_option_count - 1)


## Answers the open question with option `index`.
func choose(index: int) -> void:
	if not visible or index < 0 or index >= _option_count:
		return
	Audio.play(&"click")
	chosen.emit(index)
