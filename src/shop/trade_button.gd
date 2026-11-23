class_name TradeButton
extends Button
## One Trading Post trade as a little card-button:
##   name / [symbol you give, count badge] > [empty slot] / price.
## The symbol you give is picked at random by the merchant.
## The player picks what to get after pressing it; the empty square is bordered in that rarity.

const ICON_SIZE := 16.0
const GOLD := Color("#f8d038")

var mode: TradeRules.Mode
var give: SymbolData

var _content: VBoxContainer
var _give_icon: TextureRect
var _count: Label
var _arrow: Label
var _slot: PanelContainer
var _slot_style: StyleBoxFlat
var _price: Label


func _init(p_mode: TradeRules.Mode) -> void:
	mode = p_mode
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 50)

	var box := VBoxContainer.new()
	_content = box
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var title := _label(7, Color(1, 0.93, 0.78))
	title.text = TradeRules.NAMES[mode]
	box.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	# The count sits on the icon as a badge (like the paytable), so the row fits the button.
	_give_icon = TextureRect.new()
	_give_icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
	_give_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_give_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_give_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_give_icon)
	_count = _label(6, Color.WHITE)
	_count.add_theme_color_override("font_outline_color", Color.BLACK)
	_count.add_theme_constant_override("outline_size", 3)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count.offset_right = 3
	_count.offset_bottom = 3
	_give_icon.add_child(_count)
	_arrow = _label(7, GOLD)
	_arrow.text = ">"
	row.add_child(_arrow)
	# Empty square slot for the symbol you will pick, bordered in its rarity colour.
	_slot = PanelContainer.new()
	_slot.custom_minimum_size = Vector2.ONE * ICON_SIZE
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = Color(0.06, 0.04, 0.03, 0.85)
	_slot_style.set_border_width_all(1)
	_slot_style.set_content_margin_all(0)
	_slot.add_theme_stylebox_override("panel", _slot_style)
	var mark := _label(8, Color.WHITE)
	mark.text = "?"
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slot.add_child(mark)
	row.add_child(_slot)

	_price = _label(11, GOLD)
	_price.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.02))
	_price.add_theme_constant_override("outline_size", 3)
	box.add_child(_price)
	var removing := mode == TradeRules.Mode.REMOVE
	_arrow.visible = not removing
	_slot.visible = not removing


## Shows the symbol the merchant wants (null = nothing to trade).
func set_give(symbol: SymbolData) -> void:
	give = symbol
	_give_icon.texture = symbol.texture if symbol else null
	_count.text = "x%d" % TradeRules.GIVE_COUNT[mode] if symbol else ""
	if symbol and mode != TradeRules.Mode.REMOVE:
		var rarity := TradeRules.receive_rarity(mode, symbol)
		_slot_style.border_color = MerchantRarity.BORDER_COLORS.get(rarity, Color.GRAY)
		(_slot.get_child(0) as Label).add_theme_color_override("font_color", MerchantRarity.text_color(rarity))
	tooltip_text = "%s\n%d gold, use it as often as you like." % [TradeRules.describe(mode, symbol), TradeRules.cost(mode)]
	refresh()


func refresh() -> void:
	_price.text = "%dg" % TradeRules.cost(mode)
	disabled = not TradeRules.can_offer(mode, give)
	_content.modulate = Color(1, 1, 1, 0.55) if disabled else Color.WHITE


## Highlight while its "pick what you get" row is open.
func set_selected(selected: bool) -> void:
	self_modulate = Color(1.5, 1.35, 0.9) if selected else Color.WHITE


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
