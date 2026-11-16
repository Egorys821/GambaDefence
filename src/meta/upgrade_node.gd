class_name UpgradeNode
extends Button
## One upgrade in the Time Forge tree: an icon with its level underneath.
## States: locked (parent not owned), available, maxed; plus selected.

const NODE_SIZE := Vector2(36, 36)
const LOCKED_COLOR := Color(0.25, 0.22, 0.25)
const GOLD := Color("#f8d038")

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
		_level.text = "%d/%d" % [level, upgrade.max_level]
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
