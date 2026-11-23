class_name Tutorial
extends Control
## Step-by-step guide over the real game UI. Each step dims the screen except
## one highlighted area and explains it in a small panel.
##
## Steps are dictionaries: {"title": String, "text": String, "rect": Rect2}
## (an empty rect means no highlight). Main builds them from the live UI.

signal finished

const DIM := Color(0, 0, 0, 0.62)
const FRAME := Color("#f8d038")
const PANEL_WIDTH := 230.0
const GAP := 8.0

var _steps: Array[Dictionary] = []
var _index := 0
var _highlight := Rect2()
var _time := 0.0
var _panel: PanelContainer
var _title: Label
var _body: Label
var _counter: Label
var _next_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	hide()


func start(steps: Array[Dictionary]) -> void:
	_steps = steps
	_index = 0
	show()
	_show_step()


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect()
	if _highlight.size == Vector2.ZERO:
		draw_rect(screen, DIM)
		return
	var r := _highlight.grow(3.0)
	# Dim everything around the highlighted area.
	draw_rect(Rect2(0, 0, screen.size.x, r.position.y), DIM)
	draw_rect(Rect2(0, r.end.y, screen.size.x, screen.size.y - r.end.y), DIM)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), DIM)
	draw_rect(Rect2(r.end.x, r.position.y, screen.size.x - r.end.x, r.size.y), DIM)
	var pulse := 0.6 + 0.4 * sin(_time * 5.0)
	draw_rect(r, Color(FRAME, pulse), false, 2.0)


func _show_step() -> void:
	var step := _steps[_index]
	_highlight = step.get("rect", Rect2())
	_title.text = step["title"]
	_body.text = step["text"]
	_counter.text = "%d / %d" % [_index + 1, _steps.size()]
	_next_button.text = "Let's go!" if _index == _steps.size() - 1 else "Next"
	_panel.reset_size()
	_panel.position = _panel_position(_panel.size)
	_panel.modulate.a = 0.0
	_panel.create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)
	queue_redraw()


## Puts the panel beside tall highlights, otherwise above or below them.
func _panel_position(panel_size: Vector2) -> Vector2:
	var screen := get_viewport_rect().size
	if _highlight.size == Vector2.ZERO:
		return (screen - panel_size) * 0.5
	var pos := Vector2.ZERO
	if _highlight.size.y > screen.y * 0.55:
		var right_side := _highlight.get_center().x < screen.x * 0.5
		pos.x = _highlight.end.x + GAP if right_side else _highlight.position.x - panel_size.x - GAP
		pos.y = (screen.y - panel_size.y) * 0.5
	else:
		pos.x = _highlight.get_center().x - panel_size.x * 0.5
		var below := _highlight.get_center().y < screen.y * 0.5
		pos.y = _highlight.end.y + GAP if below else _highlight.position.y - panel_size.y - GAP
	return pos.clamp(Vector2.ONE * GAP, screen - panel_size - Vector2.ONE * GAP)


func _on_next_pressed() -> void:
	Audio.play(&"click")
	_index += 1
	if _index >= _steps.size():
		_finish()
	else:
		_show_step()


func _finish() -> void:
	hide()
	finished.emit()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 11)
	_title.add_theme_color_override("font_color", FRAME)
	box.add_child(_title)
	_body = Label.new()
	_body.custom_minimum_size = Vector2(PANEL_WIDTH - 12.0, 0)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 8)
	box.add_child(_body)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var skip := Button.new()
	skip.text = "Skip tutorial"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 7)
	skip.pressed.connect(_finish)
	buttons.add_child(skip)
	_counter = Label.new()
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.add_theme_font_size_override("font_size", 7)
	buttons.add_child(_counter)
	_next_button = Button.new()
	_next_button.focus_mode = Control.FOCUS_NONE
	_next_button.custom_minimum_size = Vector2(70, 18)
	_next_button.pressed.connect(_on_next_pressed)
	buttons.add_child(_next_button)
