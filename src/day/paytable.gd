class_name Paytable
extends PanelContainer
## Left panel during the day: explains what to hit. Lists every symbol on the
## reels with its chance and what 3 / 4 / 5 in a row pay, plus the owned paylines.

const VALUE_WIDTH := 20.0
const HEADER_COLOR := Color("#f8d038")
const DIM_COLOR := Color("#b0a088")

var _content: VBoxContainer
## Symbol id -> row Control, for flashing on wins.
var _rows: Dictionary = {}


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	box.add_child(_label("Paytable", 10, HEADER_COLOR))
	var hint := _label("Land 3+ matching symbols on a payline, starting from the LEFT reel.", 7, DIM_COLOR)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 136
	box.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 2)
	scroll.add_child(_content)
	GameState.machine_changed.connect(rebuild)
	rebuild()


## Highlights a symbol's row when it wins.
func flash(symbol_id: StringName) -> void:
	var row: Control = _rows.get(symbol_id)
	if row == null:
		return
	row.modulate = Color(2.2, 2.0, 1.2)
	row.create_tween().tween_property(row, "modulate", Color.WHITE, 0.6)


func rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_rows.clear()

	var header := HBoxContainer.new()
	var spacer := _label("Symbol", 7, DIM_COLOR)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	for count in [3, 4, 5]:
		header.add_child(_value_label("x%d" % count, DIM_COLOR))
	_content.add_child(header)

	var ids: Array = GameState.pool.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return GameState.copies_of(a) > GameState.copies_of(b))
	for id: StringName in ids:
		var row := _symbol_row(GameState.get_symbol(id))
		_rows[id] = row
		_content.add_child(row)

	_content.add_child(HSeparator.new())
	_content.add_child(_label("Your paylines (%d)" % GameState.paylines.size(), 8, HEADER_COLOR))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	var lines := GameState.paylines.duplicate()
	lines.sort()
	for line in lines:
		var icon := PaylineIcon.new()
		icon.setup(line, GameState.machine_rows)
		grid.add_child(icon)
	_content.add_child(grid)
	var more := _label("Buy more paylines from the merchant.", 7, DIM_COLOR)
	more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	more.custom_minimum_size.x = 130
	_content.add_child(more)


func _symbol_row(symbol: SymbolData) -> Control:
	var level := GameState.level_of(symbol.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = "%s (level %d)\n%s" % [symbol.display_name, level, symbol.description]

	var icon := TextureRect.new()
	icon.texture = symbol.texture
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	var title := symbol.display_name + ("  Lv%d" % level if level > 1 else "")
	text.add_child(_label(title, 7, Color.WHITE))
	var chance := roundi(GameState.chance_of(symbol.id) * 100.0)
	var noun := symbol.reward_label()
	if symbol.is_wild() and not symbol.wild_for.is_empty():
		noun = "for " + symbol.wild_targets_text()
	var sub := _label("%d%% %s" % [chance, ("- " + noun) if noun != "" else ""], 6, DIM_COLOR)
	sub.clip_text = true
	sub.custom_minimum_size.x = 60
	text.add_child(sub)
	row.add_child(text)

	match symbol.effect:
		SymbolData.Effect.WILD:
			var wild := _label("WILD", 8, Color("#d090ff"))
			wild.custom_minimum_size.x = VALUE_WIDTH * 3
			wild.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			wild.tooltip_text = "Counts as %s." % symbol.wild_targets_text()
			if not symbol.wild_for.is_empty():
				wild.text = "WILD*"
			row.add_child(wild)
		SymbolData.Effect.RESPIN:
			for count in [3, 4, 5]:
				var free := _value_label(str(symbol.reward_amount(count, 1)), Color("#80ff80"))
				free.tooltip_text = "Free spins, played automatically."
				row.add_child(free)
		SymbolData.Effect.CURSE:
			for count in [3, 4, 5]:
				var bad := _value_label("+%d" % symbol.reward_amount(count, 1), Color("#ff4050"))
				bad.tooltip_text = "Extra spirits tonight. Each Tombstone that lands also adds one."
				row.add_child(bad)
		SymbolData.Effect.NONE:
			var nothing := _label("nothing", 7, DIM_COLOR)
			nothing.custom_minimum_size.x = VALUE_WIDTH * 3
			nothing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(nothing)
		_:
			var color := Color("#f8d038") if symbol.effect == SymbolData.Effect.GOLD else \
				Color("#80f060") if symbol.effect == SymbolData.Effect.REPAIR else Color("#80d0ff")
			for count in [3, 4, 5]:
				row.add_child(_value_label(str(symbol.reward_amount(count, level)), color))
	return row


func _value_label(text: String, color: Color) -> Label:
	var label := _label(text, 8, color)
	label.custom_minimum_size.x = VALUE_WIDTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label
