class_name Paytable
extends PanelContainer
## Left panel during the day: explains what to hit on the run's machine.
## Lists every symbol on the reels with its chance and what each match length
## pays, plus the owned paylines (machines that pay by lines).

const VALUE_WIDTH := 20.0
const HEADER_COLOR := Color("#f8d038")
const DIM_COLOR := Color("#b0a088")

const DEFAULT_HINT := "Land 3+ matching symbols on a payline, starting from the LEFT reel."
## Paytable columns shown at most (long ways machines show the first ones).
const MAX_COLUMNS := 4

var _content: VBoxContainer
var _title: Label
var _hint: Label
## Symbol id -> row Control, for flashing on wins.
var _rows: Dictionary = {}


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_title = _label("Paytable", 10, HEADER_COLOR)
	box.add_child(_title)
	_hint = _label(DEFAULT_HINT, 7, DIM_COLOR)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 136
	box.add_child(_hint)
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
	var machine := GameState.machine
	_title.text = "Paytable - %s" % machine.display_name
	_hint.text = machine.rules_hint if machine.rules_hint != "" else DEFAULT_HINT

	var header := HBoxContainer.new()
	var spacer := _label("Symbol", 7, DIM_COLOR)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	for count in _counts():
		header.add_child(_value_label("x%d" % count, DIM_COLOR))
	_content.add_child(header)

	var ids: Array = GameState.pool.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return GameState.copies_of(a) > GameState.copies_of(b))
	if GameState.empty_slots() > 0:
		ids.append(GameState.EMPTY_SLOT_ID)  # thin reels: blanks fill the missing cells
	for id: StringName in ids:
		var row := _symbol_row(GameState.get_symbol(id))
		_rows[id] = row
		_content.add_child(row)

	if machine.uses_lines():
		_add_patterns()


func _add_patterns() -> void:
	_content.add_child(HSeparator.new())
	var line_count := GameState.active_paylines().size()
	var shape_count := GameState.shapes.size()
	_content.add_child(_label("Patterns: %d shape%s = %d lines" % [shape_count, "" if shape_count == 1 else "s", line_count], 8, HEADER_COLOR))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	for shape in GameState.shapes:
		var icon := PaylineIcon.new()
		icon.setup(GameState.line_table(), shape, GameState.machine_rows)
		grid.add_child(icon)
	_content.add_child(grid)
	var shop_hint := "All patterns are owned on this machine." if GameState.next_locked_shape() < 0 \
		else "Buy more from the merchant."
	var more := _label("Each shape pays at every height it fits. " + shop_hint, 7, DIM_COLOR)
	more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	more.custom_minimum_size.x = 130
	_content.add_child(more)


func _symbol_row(symbol: SymbolData) -> Control:
	var level := GameState.level_of(symbol.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = "%s (level %d) - %d on the reels\n%s" % [
		symbol.display_name, level, GameState.reel_copies(symbol.id), symbol.description]

	var icon := TextureRect.new()
	icon.texture = symbol.texture
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(icon)
	# Badge: how many copies are on the reels.
	var copies := _label("x%d" % GameState.reel_copies(symbol.id), 6, Color.WHITE)
	copies.add_theme_color_override("font_outline_color", Color.BLACK)
	copies.add_theme_constant_override("outline_size", 3)
	copies.position = Vector2(7, 7)
	icon.add_child(copies)

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

	var counts := _counts()
	match symbol.effect:
		SymbolData.Effect.WILD:
			var badge := "WILD" if symbol.wild_for.is_empty() else "WILD*"
			if symbol.is_scatter:
				badge += "+SCATTER"
			elif symbol.wild_multiplier > 1:
				badge += " x%d" % symbol.wild_multiplier
			var wild := _wide_label(badge, Color("#d090ff"), counts.size())
			wild.tooltip_text = "Counts as %s." % symbol.wild_targets_text()
			row.add_child(wild)
		SymbolData.Effect.CURSE:
			for count in counts:
				var bad := _value_label("+%d" % symbol.reward_amount(count, 1), Color("#ff4050"))
				bad.tooltip_text = "Extra spirits tonight. Each Tombstone that lands also adds one."
				row.add_child(bad)
		SymbolData.Effect.NONE:
			var badge := "BONUS" if symbol.is_bonus else "nothing"
			row.add_child(_wide_label(badge, Color("#30c070") if symbol.is_bonus else DIM_COLOR, counts.size()))
		_:
			var color := Color("#f8d038") if symbol.effect == SymbolData.Effect.GOLD else \
				Color("#80f060") if symbol.effect == SymbolData.Effect.REPAIR else Color("#80d0ff")
			for count in counts:
				row.add_child(_value_label(str(symbol.reward_amount(count, level)), color))
	return row


## Match lengths shown as columns.
func _counts() -> Array[int]:
	var counts := GameState.machine.match_counts()
	return counts.slice(0, MAX_COLUMNS)


func _wide_label(text: String, color: Color, columns: int) -> Label:
	var label := _label(text, 7, color)
	label.custom_minimum_size.x = VALUE_WIDTH * columns
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


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
