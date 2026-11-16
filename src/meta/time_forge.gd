class_name TimeForge
extends Control
## Upgrade tree: spend Chrono Shards on permanent upgrades. Opened from the menu.
##
## Every META upgrade (res://data/upgrades/meta/) is a node placed at its
## `tree_position`, linked to its `requires` parent. Only roots and children
## of owned nodes can be bought; the rest stays dimmed until reached.
## The tree can be zoomed (mouse wheel / buttons) and dragged around.

signal closed
signal settings_pressed

const CELL := Vector2(62, 58)
const ORIGIN := Vector2(14, 24)
const MIN_ZOOM := 0.4
const MAX_ZOOM := 2.0
const ZOOM_STEP := 1.15
const BRANCHES := {
	UpgradeData.Category.MACHINE: "Slot Machine",
	UpgradeData.Category.CASTLE: "Castle",
	UpgradeData.Category.ARMY: "Army",
}
const LINE_OWNED := Color("#c08820")
const LINE_LOCKED := Color(0.4, 0.35, 0.3, 0.6)

var _nodes: Array[UpgradeNode] = []
var _selected: UpgradeData
var _reset_armed := false
var _zoom := 1.0
var _dragging := false

@onready var _tree: Control = %Tree
@onready var _tree_view: Control = %TreeView
@onready var _shard_label: Label = %ShardLabel
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_body: Label = %DetailBody
@onready var _buy_button: Button = %BuyButton
@onready var _begin_button: Button = %BeginButton
@onready var _reset_button: Button = %ResetButton
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	_tree.draw.connect(_draw_tree)
	_tree_view.gui_input.connect(_on_tree_view_input)
	%ZoomInButton.pressed.connect(func() -> void: _zoom_at(_tree_view.size * 0.5, ZOOM_STEP))
	%ZoomOutButton.pressed.connect(func() -> void: _zoom_at(_tree_view.size * 0.5, 1.0 / ZOOM_STEP))
	%FitButton.pressed.connect(_fit_tree)
	_buy_button.pressed.connect(_on_buy_pressed)
	_begin_button.pressed.connect(_on_back_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_settings_button.pressed.connect(settings_pressed.emit)
	MetaProgress.changed.connect(_refresh)
	hide()


func open() -> void:
	_reset_armed = false
	_build_tree()
	if _selected == null:
		_selected = _nodes[0].upgrade
	_refresh()
	show()
	_fit_tree()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)


func _build_tree() -> void:
	for child in _tree.get_children():
		child.queue_free()
	_nodes.clear()
	for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
		var node := UpgradeNode.new(upgrade)
		node.position = _cell_center(upgrade) - UpgradeNode.NODE_SIZE * 0.5
		node.pressed.connect(_select.bind(upgrade))
		_tree.add_child(node)
		_nodes.append(node)
	# Branch titles above each group of roots.
	for category: UpgradeData.Category in BRANCHES:
		var columns: Array[float] = []
		for node in _nodes:
			if node.upgrade.category == category:
				columns.append(node.upgrade.tree_position.x)
		var label := Label.new()
		label.text = BRANCHES[category]
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color("#f8d038"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var center_x: float = ORIGIN.x + ((columns.min() + columns.max()) * 0.5 + 0.5) * CELL.x
		label.position = Vector2(center_x - 60, ORIGIN.y - 22)
		label.size = Vector2(120, 12)
		_tree.add_child(label)


# --- Zoom and pan ------------------------------------------------------------

## Size of the whole tree at zoom 1.
func _tree_bounds() -> Vector2:
	var far := Vector2.ZERO
	for node in _nodes:
		far = far.max(node.upgrade.tree_position)
	return ORIGIN * 2.0 + (far + Vector2.ONE) * CELL


func _fit_tree() -> void:
	var bounds := _tree_bounds()
	_tree.size = bounds
	var view := _tree_view.size
	_zoom = clampf(minf(view.x / bounds.x, view.y / bounds.y), MIN_ZOOM, MAX_ZOOM)
	_tree.scale = Vector2.ONE * _zoom
	_tree.position = (view - bounds * _zoom) * 0.5


## Zooms keeping the point under `focus` (in TreeView space) still.
func _zoom_at(focus: Vector2, factor: float) -> void:
	var new_zoom := clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(new_zoom, _zoom):
		return
	_tree.position = focus - (focus - _tree.position) * (new_zoom / _zoom)
	_zoom = new_zoom
	_tree.scale = Vector2.ONE * _zoom
	_clamp_pan()


## Keeps at least part of the tree on screen.
func _clamp_pan() -> void:
	var scaled := _tree_bounds() * _zoom
	var view := _tree_view.size
	var margin := 60.0
	_tree.position.x = clampf(_tree.position.x, margin - scaled.x, view.x - margin)
	_tree.position.y = clampf(_tree.position.y, margin - scaled.y, view.y - margin)


func _on_tree_view_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(button.position, ZOOM_STEP)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(button.position, 1.0 / ZOOM_STEP)
		elif button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = button.pressed
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_tree.position += motion.relative
		_clamp_pan()


func _cell_center(upgrade: UpgradeData) -> Vector2:
	return ORIGIN + (upgrade.tree_position + Vector2(0.5, 0.5)) * CELL


func _draw_tree() -> void:
	for node in _nodes:
		var parent := node.upgrade.requires
		if parent == null:
			continue
		var owned := MetaProgress.level_of(parent.id) >= node.upgrade.requires_level
		_tree.draw_line(_cell_center(parent), _cell_center(node.upgrade), LINE_OWNED if owned else LINE_LOCKED, 2.0 if owned else 1.0)


func _select(upgrade: UpgradeData) -> void:
	_selected = upgrade
	Audio.play(&"click", 1.2, -6.0)
	_refresh()


func _refresh() -> void:
	_shard_label.text = "%d Chrono Shards" % MetaProgress.shards
	for node in _nodes:
		node.refresh()
		node.selected = node.upgrade == _selected
	_tree.queue_redraw()
	_refresh_detail()
	if not _reset_armed:
		_reset_button.text = "Refund all (%d)" % MetaProgress.shards_spent()
	_reset_button.disabled = MetaProgress.shards_spent() == 0


func _refresh_detail() -> void:
	if _selected == null:
		return
	var level := MetaProgress.level_of(_selected.id)
	_detail_icon.texture = _selected.icon
	_detail_title.text = "%s   %d/%d" % [_selected.display_name, level, _selected.max_level]
	var body := _selected.describe()
	if not GameState.prerequisites_met(_selected) and level == 0:
		body += "\nRequires: %s level %d." % [_selected.requires.display_name, _selected.requires_level]
	_detail_body.text = body
	if _selected.is_maxed(level):
		_buy_button.text = "Maxed"
		_buy_button.disabled = true
	else:
		_buy_button.text = "Forge - %d shards" % _selected.cost_at(level)
		_buy_button.disabled = not MetaProgress.can_buy(_selected)


func _on_buy_pressed() -> void:
	if _selected == null or not MetaProgress.buy(_selected):
		Audio.play(&"denied")
		return
	Audio.play(&"buy")
	for node in _nodes:
		if node.upgrade == _selected:
			node.pivot_offset = node.size * 0.5
			Fx.pop(node, 1.25, 0.25)
			Fx.burst(_tree, node.position + node.size * 0.5, Color("#60d8f8"), 18, 80.0)


func _on_back_pressed() -> void:
	Audio.play(&"click")
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween.finished
	hide()
	closed.emit()


## Refunds every shard spent so the player can try a different build.
func _on_reset_pressed() -> void:
	if MetaProgress.shards_spent() == 0:
		Audio.play(&"denied")
		return
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Sure? Click again"
		return
	MetaProgress.refund_upgrades()
	_reset_armed = false
	Audio.play(&"coin")
