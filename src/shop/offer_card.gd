class_name OfferCard
extends PanelContainer
## Compact card (two per row) showing one ShopOffer: icon, title and a buy button.
## The full description shows in the shop's detail line on hover (and the tooltip).

signal buy_pressed
signal hovered

## Two cards side by side fill the 138 px wide merchant column (3 px gap).
const CARD_WIDTH := 67.0
const ICON_SIZE := 18.0
## Inner width = card width minus the card style's left/right content margins.
const INNER_WIDTH := CARD_WIDTH - 10.0

var offer: ShopOffer
var _button: Button


func _init(p_offer: ShopOffer) -> void:
	offer = p_offer
	custom_minimum_size = Vector2(CARD_WIDTH, 0)
	add_theme_stylebox_override("panel", MerchantRarity.card_style(offer.rarity))
	tooltip_text = "%s (%s)\n%s" % [offer.title, MerchantRarity.tier_name(offer.rarity), offer.description]
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	add_child(box)

	var icon := TextureRect.new()
	icon.texture = offer.icon
	icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	# Wrapped labels need a known width, otherwise they report a huge minimum
	# height and push the buy button out of the card. Fixed 2-line height keeps
	# the buttons of a row aligned.
	var title := Label.new()
	title.text = offer.title
	title.custom_minimum_size = Vector2(INNER_WIDTH, 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 7)
	title.add_theme_constant_override("line_spacing", -2)
	if offer.rarity != MerchantRarity.Tier.COMMON:
		title.add_theme_color_override("font_color", MerchantRarity.text_color(offer.rarity))
	box.add_child(title)

	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override("font_size", 10)
	_button.pressed.connect(buy_pressed.emit)
	_button.mouse_entered.connect(hovered.emit)
	box.add_child(_button)
	refresh()


func refresh() -> void:
	if offer.sold:
		_button.text = "Sold"
		_button.disabled = true
		modulate = Color(1, 1, 1, 0.45)
	else:
		_button.text = "%dg" % offer.cost
		_button.disabled = GameState.gold < offer.cost


## Little bounce when bought.
func play_bought() -> void:
	pivot_offset = size * 0.5
	Fx.pop(self, 1.08, 0.2)


func _on_hover(is_hovered: bool) -> void:
	if is_hovered:
		hovered.emit()
	if offer.sold:
		return
	self_modulate = Color(1.25, 1.2, 1.1) if is_hovered else Color.WHITE
