class_name TimeForge
extends Control
## Upgrade tree: spend Chrono Shards and Crowns on permanent upgrades. Opened
## from the menu.
##
## Four windows (tabs): Slot Machines, Castle, Troops and Merchant. Every META
## upgrade (res://data/upgrades/meta/) is a node in its category's window,
## placed at its `tree_position` and linked to its `requires` parent. Only
## roots and children of owned nodes can be bought; the rest stays dimmed.
## Crown nodes (UpgradeData.crown_cost) cost Crowns, won by conquering castles:
## new slot machines and the keys that open whole subtrees. An owned machine
## node gets a "Use machine" button that picks it for the next runs.
## Each tree can be zoomed (mouse wheel / buttons) and dragged around.

signal closed
signal settings_pressed

const CELL := Vector2(62, 58)
const ORIGIN := Vector2(14, 24)
const MIN_ZOOM := 0.4
const MAX_ZOOM := 2.0
const ZOOM_STEP := 1.15
## The four windows: tab name and the categories shown in it.
const WINDOWS := [
	{"name": "Slot Machines", "categories": [UpgradeData.Category.MACHINE, UpgradeData.Category.MACHINES]},
	{"name": "Castle", "categories": [UpgradeData.Category.CASTLE]},
	{"name": "Troops", "categories": [UpgradeData.Category.ARMY]},
	{"name": "Merchant", "categories": [UpgradeData.Category.MERCHANT]},
]
## Branch titles inside a window that holds more than one category.
const BRANCHES := {
	UpgradeData.Category.MACHINE: "All Machines",
	UpgradeData.Category.MACHINES: "Machines and their upgrades",
}
const HINT := "Machine: %s.  Forge an upgrade to open the ones below it.  Crown nodes cost Crowns from conquered castles.  Wheel: zoom, drag: move."
const TAB_ON := Color("#f8d038")
const TAB_OFF := Color(0.75, 0.7, 0.62)
const LINE_OWNED := Color("#c08820")
const LINE_LOCKED := Color(0.4, 0.35, 0.3, 0.6)
## Minimum width of the detail text (keeps the bottom bar on screen).
const DETAIL_TEXT_WIDTH := 238.0

var _nodes: Array[UpgradeNode] = []
var _window := 0
var _tab_buttons: Array[Button] = []
var _selected: UpgradeData
var _reset_armed := false
var _zoom := 1.0
var _dragging := false
## Live picture of the selected machine (shown instead of the icon).
var _preview: MachinePreview

@onready var _tree: Control = %Tree
@onready var _tree_view: Control = %TreeView
@onready var _shard_label: Label = %ShardLabel
@onready var _crown_label: Label = %CrownLabel
@onready var _tabs: HBoxContainer = %Tabs
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_body: Label = %DetailBody
@onready var _buy_button: Button = %BuyButton
@onready var _use_button: Button = %UseButton
@onready var _hint: Label = %Hint
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
	_buy_button.theme_type_variation = &"AccentButton"
	# Room for four lines of detail text in the bottom bar.
	_buy_button.custom_minimum_size.x = 104
	_detail_body.add_theme_constant_override("line_spacing", -1)
	_use_button.pressed.connect(_on_use_pressed)
	_begin_button.pressed.connect(_on_back_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_settings_button.pressed.connect(settings_pressed.emit)
	for i in WINDOWS.size():
		var tab := Button.new()
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(0, 18)
		tab.add_theme_font_size_override("font_size", 8)
		tab.pressed.connect(show_window.bind(i))
		_tabs.add_child(tab)
		_tab_buttons.append(tab)
	MetaProgress.changed.connect(_refresh)
	_preview = MachinePreview.new()
	_preview.tooltip_text = ""
	_detail_icon.add_sibling(_preview)
	_preview.hide()
	hide()


func open() -> void:
	_reset_armed = false
	show()
	show_window(_window, false)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)


## Switches to one of the four windows (index into WINDOWS).
func show_window(index: int, click := true) -> void:
	if click:
		Audio.play(&"click", 1.1, -4.0)
	_window = index
	_build_tree()
	if _selected == null or not _in_window(_selected):
		_selected = _nodes[0].upgrade
	_refresh()
	_fit_tree()


func _in_window(upgrade: UpgradeData) -> bool:
	return upgrade.category in WINDOWS[_window]["categories"]


func _build_tree() -> void:
	for child in _tree.get_children():
		_tree.remove_child(child)
		child.queue_free()
	_nodes.clear()
	for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
		if not _in_window(upgrade):
			continue
		var node := UpgradeNode.new(upgrade)
		node.position = _cell_center(upgrade) - UpgradeNode.NODE_SIZE * 0.5
		node.pressed.connect(_select.bind(upgrade))
		_tree.add_child(node)
		_nodes.append(node)
	# Branch titles above each group of roots (windows with several categories).
	if WINDOWS[_window]["categories"].size() < 2:
		return
	for category: UpgradeData.Category in BRANCHES:
		var columns: Array[float] = []
		var top_row := INF
		for node in _nodes:
			if node.upgrade.category == category:
				columns.append(node.upgrade.tree_position.x)
				top_row = minf(top_row, node.upgrade.tree_position.y)
		if columns.is_empty():
			continue
		var label := Label.new()
		label.text = BRANCHES[category]
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color("#f8d038"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var center_x: float = ORIGIN.x + ((columns.min() + columns.max()) * 0.5 + 0.5) * CELL.x
		label.position = Vector2(center_x - 60, ORIGIN.y + top_row * CELL.y - 22)
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
	_shard_label.text = "%d" % MetaProgress.shards
	_crown_label.text = "%d" % MetaProgress.crowns()
	_hint.text = HINT % GameState.selected_machine().display_name
	_refresh_tabs()
	for node in _nodes:
		node.refresh()
		node.selected = node.upgrade == _selected
	_tree.queue_redraw()
	_refresh_detail()
	var spent_anything := MetaProgress.shards_spent() > 0 or MetaProgress.crowns_spent() > 0
	if not _reset_armed:
		_reset_button.text = "Refund all"
	_reset_button.tooltip_text = "Give back all %d shards and %d crowns spent." % [MetaProgress.shards_spent(), MetaProgress.crowns_spent()]
	_reset_button.disabled = not spent_anything


## Tab names; a "!" marks windows with something you can forge right now.
func _refresh_tabs() -> void:
	for i in WINDOWS.size():
		var tab := _tab_buttons[i]
		var affordable := 0
		for upgrade in GameState.get_upgrades(UpgradeData.Scope.META):
			if upgrade.category in WINDOWS[i]["categories"] and MetaProgress.can_buy(upgrade):
				affordable += 1
		tab.text = " %s%s " % [WINDOWS[i]["name"], " (%d)" % affordable if affordable > 0 else ""]
		tab.add_theme_color_override("font_color", TAB_ON if i == _window else TAB_OFF)
		tab.self_modulate = Color(1.3, 1.2, 0.85) if i == _window else Color.WHITE


func _refresh_detail() -> void:
	if _selected == null:
		return
	var level := MetaProgress.level_of(_selected.id)
	_detail_icon.texture = _selected.icon
	var machine := GameState.machine_unlocked_by(_selected)
	_detail_icon.visible = machine == null
	_preview.visible = machine != null
	# The preview is wider than the icon: the text gives up the difference.
	_detail_body.custom_minimum_size.x = DETAIL_TEXT_WIDTH - (_preview.custom_minimum_size.x - _detail_icon.custom_minimum_size.x if machine else 0.0)
	if machine:
		_preview.show_style(machine)
	_detail_title.text = _selected.display_name if _selected.max_level == 0 \
		else "%s   %d/%d" % [_selected.display_name, level, _selected.max_level]
	var body := _selected.describe()
	var requires := _selected.requires
	if requires and level == 0 and MetaProgress.level_of(requires.id) < _selected.requires_level:
		body += "\nRequires: %s level %d." % [requires.display_name, _selected.requires_level]
	var castle := _selected.requires_castle
	if castle and level == 0 and not MetaProgress.is_conquered(castle):
		body += "\nConquer %s first." % castle.display_name
	_detail_body.text = body
	if _selected.is_maxed(level):
		_buy_button.text = "Owned" if _selected.max_level <= 1 else "Maxed"
		_buy_button.disabled = true
	else:
		var price := _selected.cost_at(level)
		if _selected.is_crown_node():
			_buy_button.text = "Forge - %d Crown%s" % [price, "" if price == 1 else "s"]
		else:
			_buy_button.text = "Forge - %d shards" % price
		_buy_button.disabled = not MetaProgress.can_buy(_selected)
	_refresh_use_button()


## Owned machines can be picked (or put back to the Gamba Machine).
func _refresh_use_button() -> void:
	var machine := GameState.machine_unlocked_by(_selected)
	_use_button.visible = machine != null and GameState.is_machine_unlocked(machine)
	if _use_button.visible:
		var in_use := GameState.selected_machine() == machine
		var standard := machine.id == MachineStyle.STANDARD_ID
		_use_button.disabled = in_use and standard
		if in_use:
			_use_button.text = "In use" if standard else "In use: back to\nGamba Machine"
		else:
			_use_button.text = "Use machine"


func _on_use_pressed() -> void:
	var machine := GameState.machine_unlocked_by(_selected)
	if machine == null:
		return
	var in_use := GameState.selected_machine() == machine
	if in_use and machine.id == MachineStyle.STANDARD_ID:
		return
	MetaProgress.select_machine(MachineStyle.STANDARD_ID if in_use else machine.id)
	Audio.play(&"buy", 1.2)


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


## Refunds every shard and crown spent so the player can try a different build.
func _on_reset_pressed() -> void:
	if MetaProgress.shards_spent() == 0 and MetaProgress.crowns_spent() == 0:
		Audio.play(&"denied")
		return
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Sure? Click again"
		return
	MetaProgress.refund_upgrades()
	_reset_armed = false
	Audio.play(&"coin")
