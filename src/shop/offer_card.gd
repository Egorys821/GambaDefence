class_name OfferCard
extends PanelContainer
## Compact card showing one ShopOffer with a buy button.

signal buy_pressed

const CARD_WIDTH := 138.0
const ICON_SIZE := 20.0
## Inner width = card width minus the card style's left/right content margins.
const INNER_WIDTH := CARD_WIDTH - 10.0

var offer: ShopOffer
var _button: Button


func _init(p_offer: ShopOffer) -> void:
	offer = p_offer
	custom_minimum_size = Vector2(CARD_WIDTH, 0)
	tooltip_text = offer.description
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	box.add_child(header)
	var icon := TextureRect.new()
	icon.texture = offer.icon
	icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	# Wrapped labels need a known width, otherwise they report a huge minimum
	# height and push the buy button out of the card.
	var title := Label.new()
	title.text = offer.title
	title.custom_minimum_size = Vector2(INNER_WIDTH - ICON_SIZE - 4.0, 0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 8)
	header.add_child(title)

	var description := Label.new()
	description.text = offer.description
	description.custom_minimum_size = Vector2(INNER_WIDTH, 0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2
	description.add_theme_font_size_override("font_size", 6)
	description.add_theme_color_override("font_color", Color("#d8c8a8"))
	box.add_child(description)

	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override("font_size", 8)
	_button.pressed.connect(buy_pressed.emit)
	box.add_child(_button)
	refresh()


func refresh() -> void:
	if offer.sold:
		_button.text = "Sold"
		_button.disabled = true
		modulate = Color(1, 1, 1, 0.45)
	else:
		_button.text = "Buy - %d gold" % offer.cost
		_button.disabled = GameState.gold < offer.cost


## Little bounce when bought.
func play_bought() -> void:
	pivot_offset = size * 0.5
	Fx.pop(self, 1.08, 0.2)


func _on_hover(hovered: bool) -> void:
	if offer.sold:
		return
	self_modulate = Color(1.25, 1.2, 1.1) if hovered else Color.WHITE
