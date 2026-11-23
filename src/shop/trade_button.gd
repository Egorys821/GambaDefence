class_name TradeButton
extends Button
## One Trading Post trade as a little card-button:
##   name / the symbol you give (picked at random by the merchant) > ? / price.
## What you get stays a surprise; the "?" is tinted with its rarity.

const ICON_SIZE := 16.0
const GOLD := Color("#f8d038")

var mode: TradeRules.Mode
var give: SymbolData

var _give_icon: TextureRect
var _count: Label
var _arrow: Label
var _result: Label
var _price: Label


func _init(p_mode: TradeRules.Mode) -> void:
	mode = p_mode
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 50)

	var box := VBoxContainer.new()
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
	_give_icon = TextureRect.new()
	_give_icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
	_give_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_give_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_give_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_give_icon)
	_count = _label(7, Color.WHITE)
	row.add_child(_count)
	_arrow = _label(7, GOLD)
	_arrow.text = ">"
	row.add_child(_arrow)
	_result = _label(9, Color.WHITE)
	_result.text = "?"
	row.add_child(_result)

	_price = _label(11, GOLD)
	_price.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.02))
	_price.add_theme_constant_override("outline_size", 3)
	box.add_child(_price)
	var removing := mode == TradeRules.Mode.REMOVE
	_arrow.visible = not removing
	_result.visible = not removing


## Shows the symbol the merchant wants (null = nothing to trade).
func set_give(symbol: SymbolData) -> void:
	give = symbol
	_give_icon.texture = symbol.texture if symbol else null
	_count.text = "x%d" % TradeRules.GIVE_COUNT[mode] if symbol else "-"
	if symbol and mode != TradeRules.Mode.REMOVE:
		_result.add_theme_color_override("font_color",
			MerchantRarity.text_color(TradeRules.receive_rarity(mode, symbol)))
	tooltip_text = "%s\n%d gold, use it as often as you like." % [TradeRules.describe(mode, symbol), TradeRules.cost(mode)]
	refresh()


func refresh() -> void:
	_price.text = "%dg" % TradeRules.cost(mode)
	disabled = not TradeRules.can_trade(mode, give, TradeRules.random_receive(mode, give))
	modulate = Color(1, 1, 1, 0.5) if disabled else Color.WHITE


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
