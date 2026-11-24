class_name TradeButton
extends Button
## One Trading Post trade as a little card-button:
##   Name ("Upgrade", "Replace", "Remove")
##   [symbol the merchant takes, x2 badge] in a box bordered in its rarity
##   price
## The symbol you give is picked at random by the merchant; the player picks
## what to get after pressing it (Upgrade / Replace).

const ICON_SIZE := 16.0
const GOLD := Color("#f8d038")
const EMPTY_BG := Color(0.06, 0.04, 0.03, 0.85)

var mode: TradeRules.Mode
var give: SymbolData

var _content: VBoxContainer
var _box_style: StyleBoxFlat
var _give_icon: TextureRect
var _count: Label
var _price: Label


func _init(p_mode: TradeRules.Mode) -> void:
	mode = p_mode
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 50)

	var content := VBoxContainer.new()
	_content = content
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 1)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	var title := _label(7, Color(1, 0.93, 0.78))
	title.text = TradeRules.NAMES[mode]
	content.add_child(title)

	# The symbol the merchant takes, in a box bordered in its rarity colour.
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_style = StyleBoxFlat.new()
	_box_style.bg_color = EMPTY_BG
	_box_style.border_color = Color(0.45, 0.32, 0.18)
	_box_style.set_border_width_all(1)
	_box_style.set_corner_radius_all(2)
	_box_style.set_content_margin_all(1)
	box.add_theme_stylebox_override("panel", _box_style)
	content.add_child(box)
	_give_icon = TextureRect.new()
	_give_icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
	_give_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_give_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_give_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_give_icon)
	# The count sits on the icon as a badge (like the paytable).
	_count = _label(6, Color.WHITE)
	_count.add_theme_color_override("font_outline_color", Color.BLACK)
	_count.add_theme_constant_override("outline_size", 3)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count.offset_right = 4
	_count.offset_bottom = 4
	_give_icon.add_child(_count)

	_price = _label(11, GOLD)
	_price.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.02))
	_price.add_theme_constant_override("outline_size", 3)
	content.add_child(_price)


## Shows the symbol the merchant wants (null = nothing to trade).
func set_give(symbol: SymbolData) -> void:
	give = symbol
	_give_icon.texture = symbol.texture if symbol else null
	_count.text = "x%d" % TradeRules.GIVE_COUNT[mode] if symbol else ""
	if symbol:
		_box_style.border_color = MerchantRarity.BORDER_COLORS.get(symbol.rarity, Color.GRAY)
		_box_style.bg_color = MerchantRarity.BG_COLORS.get(symbol.rarity, EMPTY_BG).darkened(0.3)
	else:
		_box_style.border_color = Color(0.45, 0.32, 0.18)
		_box_style.bg_color = EMPTY_BG
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
