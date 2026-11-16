class_name KingdomMap
extends Control
## Map of the castles. The first is always open; winning a castle opens the next.
## Emits `closed` with the chosen castle, or null when the player goes back.

signal closed(castle: CastleData)

const CASTLE_TEXTURE := preload("res://assets/sprites/environment/castle.png")
const NODE_SIZE := Vector2(72, 58)
const INK := Color("#5a3a20")

var _selected: CastleData
var _nodes: Dictionary = {}

@onready var _map_area: Control = %MapArea
@onready var _info_title: Label = %InfoTitle
@onready var _info_body: Label = %InfoBody
@onready var _march_button: Button = %MarchButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_map_area.draw.connect(_draw_map)
	_march_button.pressed.connect(_on_march_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	hide()


func open() -> void:
	_build_nodes()
	var default := GameState.castles[0]
	for castle in GameState.castles:
		if MetaProgress.is_castle_unlocked(castle):
			default = castle  # newest open castle
	_select(default)
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func _build_nodes() -> void:
	for child in _map_area.get_children():
		child.queue_free()
	_nodes.clear()
	for castle in GameState.castles:
		var unlocked := MetaProgress.is_castle_unlocked(castle)
		var node := Button.new()
		node.flat = true
		node.focus_mode = Control.FOCUS_NONE
		node.size = NODE_SIZE
		node.position = castle.map_position - NODE_SIZE * 0.5
		node.tooltip_text = castle.description
		node.pressed.connect(_select.bind(castle))
		var icon := TextureRect.new()
		icon.texture = CASTLE_TEXTURE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(6, 0)
		icon.size = Vector2(NODE_SIZE.x - 12, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = castle.ground_tint if unlocked else Color(0.35, 0.3, 0.3)
		node.add_child(icon)
		var label := Label.new()
		label.text = castle.display_name if unlocked else "???"
		label.add_theme_font_size_override("font_size", 7)
		label.add_theme_color_override("font_color", INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-14, 40)
		label.size = Vector2(NODE_SIZE.x + 28, 10)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(label)
		if MetaProgress.is_conquered(castle):
			var flag := Label.new()
			flag.text = "Conquered"
			flag.add_theme_font_size_override("font_size", 6)
			flag.add_theme_color_override("font_color", Color("#2c7a30"))
			flag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			flag.position = Vector2(0, 49)
			flag.size = Vector2(NODE_SIZE.x, 8)
			flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(flag)
		_map_area.add_child(node)
		_nodes[castle] = node
	_map_area.queue_redraw()


func _select(castle: CastleData) -> void:
	_selected = castle
	Audio.play(&"click")
	var unlocked := MetaProgress.is_castle_unlocked(castle)
	for each: CastleData in _nodes:
		(_nodes[each] as Control).modulate = Color(1.15, 1.1, 0.9) if each == castle else Color.WHITE
	if not unlocked:
		_info_title.text = "Locked"
		_info_body.text = "Conquer %s to reach this castle." % GameState.castles[GameState.castle_index(castle) - 1].display_name
	else:
		_info_title.text = castle.display_name
		var spirits: Array[String] = []
		for entry in castle.enemies:
			spirits.append(entry.unit.display_name)
		_info_body.text = "%s\nSpirits: %s. Boss: %s.\nChrono Shards x%.1f" % [
			castle.description, ", ".join(spirits), castle.boss.display_name, castle.shard_multiplier]
	_march_button.disabled = not unlocked
	_march_button.text = "March to %s" % castle.display_name if unlocked else "Locked"
	_map_area.queue_redraw()


func _draw_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Hills and trees doodled on the parchment.
	for i in 40:
		var at := Vector2(rng.randf_range(8, _map_area.size.x - 8), rng.randf_range(8, _map_area.size.y - 8))
		if rng.randf() < 0.5:
			_map_area.draw_polyline(PackedVector2Array([at + Vector2(-4, 2), at + Vector2(0, -3), at + Vector2(4, 2)]), Color(INK, 0.35), 1.0)
		else:
			_map_area.draw_circle(at, 2.0, Color("#4a7a3a", 0.45))
	# Dashed road between castles: solid once the next castle is open.
	for i in range(1, GameState.castles.size()):
		var from := GameState.castles[i - 1].map_position
		var to := GameState.castles[i].map_position
		var open := MetaProgress.is_castle_unlocked(GameState.castles[i])
		_map_area.draw_dashed_line(from, to, Color(INK, 0.9 if open else 0.4), 2.0, 6.0 if open else 3.0)


func _on_march_pressed() -> void:
	if _selected == null or not MetaProgress.is_castle_unlocked(_selected):
		return
	Audio.play(&"spawn")
	hide()
	closed.emit(_selected)


func _on_back_pressed() -> void:
	Audio.play(&"click")
	hide()
	closed.emit(null)
