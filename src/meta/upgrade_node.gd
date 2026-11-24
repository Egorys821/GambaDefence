class_name UpgradeNode
extends Button
## One upgrade in the Time Forge tree: an icon with its level underneath.
## States: locked (parent not owned), available, maxed; plus selected.
## Crown nodes (paid with Crowns) get a gold double frame and a little crown.
## Click / right-click: select. Double-click: forge it. Double right-click:
## refund it and everything below it.

const NODE_SIZE := Vector2(36, 36)
const LOCKED_COLOR := Color(0.25, 0.22, 0.25)
const GOLD := Color("#f8d038")
const IN_USE := Color("#60f080")
const CROWN_GOLD := Color("#ffc830")

## Double left click on the node.
signal forge_requested
## Double right click on the node.
signal refund_requested
## Single right click (selects, like a left click).
signal right_clicked

var upgrade: UpgradeData
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var _icon: TextureRect
var _level: Label
var _pulse := 0.0


func _init(p_upgrade: UpgradeData) -> void:
	upgrade = p_upgrade
	custom_minimum_size = NODE_SIZE
	size = NODE_SIZE
	focus_mode = Control.FOCUS_NONE
	tooltip_text = upgrade.display_name
	_icon = TextureRect.new()
	_icon.texture = upgrade.icon
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(4, 4)
	_icon.size = NODE_SIZE - Vector2(8, 8)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_level = Label.new()
	_level.add_theme_font_size_override("font_size", 7)
	_level.add_theme_color_override("font_outline_color", Color.BLACK)
	_level.add_theme_constant_override("outline_size", 3)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.position = Vector2(-10, NODE_SIZE.y - 2)
	_level.size = Vector2(NODE_SIZE.x + 20, 10)
	_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level)
	refresh()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT and click.double_click:
		forge_requested.emit()
		accept_event()
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		if click.double_click:
			refund_requested.emit()
		else:
			right_clicked.emit()
		accept_event()


func _process(delta: float) -> void:
	# Affordable nodes gently glow to show where to go next.
	if MetaProgress.can_buy(upgrade):
		_pulse += delta
		self_modulate = Color.WHITE.lerp(Color(1.4, 1.3, 0.8), 0.5 + 0.5 * sin(_pulse * 4.0))
	else:
		self_modulate = Color.WHITE


func is_open() -> bool:
	return GameState.prerequisites_met(upgrade) or MetaProgress.level_of(upgrade.id) > 0


func refresh() -> void:
	var level := MetaProgress.level_of(upgrade.id)
	if not is_open():
		_icon.modulate = LOCKED_COLOR
		_level.text = ""
	else:
		_icon.modulate = Color.WHITE
		_level.text = "starter" if upgrade.max_level == 0 else "%d/%d" % [level, upgrade.max_level]
		_level.add_theme_color_override("font_color", GOLD if upgrade.is_maxed(level) else Color.WHITE)
	queue_redraw()


func _draw() -> void:
	var level := MetaProgress.level_of(upgrade.id)
	var border := Color(0.45, 0.32, 0.18)
	if upgrade.is_maxed(level):
		border = GOLD
	elif level > 0:
		border = Color("#c08820")
	if selected:
		draw_rect(Rect2(Vector2(-3, -3), NODE_SIZE + Vector2(6, 6)), Color("#60d8f8"), false, 2.0)
	draw_rect(Rect2(Vector2.ZERO, NODE_SIZE), border, false, 2.0)
	if upgrade.is_crown_node():
		var gold := CROWN_GOLD if is_open() else CROWN_GOLD.darkened(0.55)
		draw_rect(Rect2(Vector2(2, 2), NODE_SIZE - Vector2(4, 4)), gold, false, 1.0)
		_draw_crown(Vector2(NODE_SIZE.x * 0.5, -1), gold)
	if _is_machine_in_use():
		# Green corner flag: this machine is used for the next runs.
		draw_colored_polygon(PackedVector2Array([Vector2(NODE_SIZE.x - 12, 0), Vector2(NODE_SIZE.x, 0), Vector2(NODE_SIZE.x, 12)]), IN_USE)


## Small three-pointed crown sitting on the top edge.
func _draw_crown(center: Vector2, color: Color) -> void:
	var w := 6.0
	var points := PackedVector2Array([
		center + Vector2(-w, 3), center + Vector2(-w, -3), center + Vector2(-w * 0.5, 0),
		center + Vector2(0, -4), center + Vector2(w * 0.5, 0), center + Vector2(w, -3), center + Vector2(w, 3)])
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0.25, 0.15, 0.02), 1.0)


func _is_machine_in_use() -> bool:
	var machine := GameState.machine_unlocked_by(upgrade)
	return machine != null and GameState.selected_machine() == machine
