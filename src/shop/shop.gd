class_name Shop
extends VBoxContainer
## The wandering merchant: random offers each day (Stats.SHOP_SLOTS) plus repair and reroll.
## Offers are drawn by rarity from a hidden bag, see ShopCatalog.roll_offers().
## Below the offers: the Trading Post (bought once per run, see TradeRules).

const DETAIL_HINT := "Point at a ware to read about it."
const DETAIL_COLOR := Color(0.85, 0.78, 0.66)

var _offers: Array[ShopOffer] = []
var _reroll_cost := ShopCatalog.REROLL_BASE_COST
## Free rerolls left today (Time Forge: Reroll Tokens).
var _free_rerolls := 0

## Trading Post buttons by TradeRules.Mode.
var _trade_mode_buttons: Dictionary = {}
## The trade whose "pick what you get" row is open, or null.
var _choosing: TradeButton
## The symbol that trade was taking when the row opened.
var _choosing_give: SymbolData

@onready var _cards: GridContainer = %Cards
@onready var _detail: Label = %Detail
@onready var _repair_button: Button = %RepairButton
@onready var _reroll_button: Button = %RerollButton
@onready var _unlock_trade_button: Button = %UnlockTradeButton
@onready var _trade_buttons: HBoxContainer = %TradeButtons
@onready var _trade_choice: VBoxContainer = %TradeChoice
@onready var _choice_label: Label = %ChoiceLabel
@onready var _choice_grid: GridContainer = %ChoiceGrid


func _ready() -> void:
	_repair_button.pressed.connect(_on_repair_pressed)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_unlock_trade_button.pressed.connect(_on_unlock_trade_pressed)
	for mode: TradeRules.Mode in TradeRules.Mode.values():
		var button := TradeButton.new(mode)
		button.pressed.connect(_on_trade_pressed.bind(button))
		_trade_buttons.add_child(button)
		_trade_mode_buttons[mode] = button
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.castle_hp_changed.connect(_on_castle_hp_changed)
	GameState.machine_changed.connect(_refresh)


## New stock for a new day.
func restock() -> void:
	_reroll_cost = ShopCatalog.price(ShopCatalog.REROLL_BASE_COST)
	_free_rerolls = GameState.stat_int(Stats.FREE_REROLLS)
	_repick_trades(true)
	_close_choice()
	_roll_offers()


func _roll_offers() -> void:
	_offers = ShopCatalog.roll_offers()
	_detail.text = DETAIL_HINT
	_detail.add_theme_color_override("font_color", DETAIL_COLOR)
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for offer in _offers:
		var card := OfferCard.new(offer)
		card.buy_pressed.connect(_on_buy_pressed.bind(card))
		card.hovered.connect(_show_detail.bind(offer))
		_cards.add_child(card)
		# Cards deal in one after another.
		card.modulate.a = 0.0
		var tween := card.create_tween()
		tween.tween_interval(0.08 * card.get_index())
		tween.tween_property(card, "modulate:a", 1.0, 0.15)
		if offer.rarity == MerchantRarity.Tier.LEGENDARY:
			tween.tween_callback(_announce_legendary.bind(card))
	_refresh()


## A Legendary ware gets a little fanfare.
func _announce_legendary(card: OfferCard) -> void:
	Audio.play(&"tease")
	card.pivot_offset = card.size * 0.5
	Fx.pop(card, 1.1, 0.3)


func _on_buy_pressed(card: OfferCard) -> void:
	var offer := card.offer
	if offer.sold or not GameState.spend_gold(offer.cost):
		Audio.play(&"denied")
		return
	offer.sold = true
	offer.apply.call()
	Audio.play(&"buy")
	card.play_bought()
	_refresh()


func _show_detail(offer: ShopOffer) -> void:
	_detail.text = "%s: %s" % [offer.title, offer.description]
	_detail.add_theme_color_override("font_color", MerchantRarity.text_color(offer.rarity).lerp(Color.WHITE, 0.4))


func _on_unlock_trade_pressed() -> void:
	if not TradeRules.unlock():
		Audio.play(&"denied")
		return
	Audio.play(&"buy")
	_repick_trades(true)
	_refresh()
	for button: Button in _trade_mode_buttons.values():
		button.pivot_offset = button.size * 0.5
		Fx.pop(button, 1.15, 0.25)


## The merchant picks at random which symbol each trade takes. Picks stay until
## used (or a new day); a pick that is no longer possible is replaced.
func _repick_trades(force: bool = false) -> void:
	for mode: TradeRules.Mode in _trade_mode_buttons:
		var button: TradeButton = _trade_mode_buttons[mode]
		if force or button.give not in TradeRules.give_options(mode):
			button.set_give(TradeRules.pick_give(mode))


## Remove trades at once; the swaps open a row of symbols to pick from.
func _on_trade_pressed(button: TradeButton) -> void:
	if button.mode == TradeRules.Mode.REMOVE:
		_do_trade(button, null)
		return
	Audio.play(&"click")
	if _choosing == button:
		_close_choice()
		return
	_open_choice(button)


func _open_choice(button: TradeButton) -> void:
	_choosing = button
	_choosing_give = button.give
	for child in _choice_grid.get_children():
		_choice_grid.remove_child(child)
		child.queue_free()
	var give := button.give
	_choice_label.text = "Give %dx %s - pick what you get:" % [TradeRules.GIVE_COUNT[button.mode], give.display_name]
	for symbol in TradeRules.get_options(button.mode, give):
		var choice := Button.new()
		choice.focus_mode = Control.FOCUS_NONE
		choice.custom_minimum_size = Vector2(26, 24)
		choice.icon = symbol.texture
		choice.expand_icon = true
		choice.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice.tooltip_text = "%s (%s)\n%s" % [symbol.display_name, MerchantRarity.tier_name(symbol.rarity), symbol.description]
		_style_choice(choice, symbol.rarity)
		choice.pressed.connect(_do_trade.bind(button, symbol))
		choice.mouse_entered.connect(_show_symbol_detail.bind(symbol))
		_choice_grid.add_child(choice)
	_trade_choice.show()
	for each: TradeButton in _trade_mode_buttons.values():
		each.set_selected(each == button)


func _close_choice() -> void:
	_choosing = null
	_trade_choice.hide()
	for each: TradeButton in _trade_mode_buttons.values():
		each.set_selected(false)


func _do_trade(button: TradeButton, receive: SymbolData) -> void:
	var give := button.give
	if not TradeRules.trade(button.mode, give, receive):
		Audio.play(&"denied")
		return
	_close_choice()
	if receive:
		_detail.text = "Traded %dx %s for 1x %s!" % [TradeRules.GIVE_COUNT[button.mode], give.display_name, receive.display_name]
		_detail.add_theme_color_override("font_color", MerchantRarity.text_color(receive.rarity).lerp(Color.WHITE, 0.4))
		Audio.play(&"win" if receive.rarity >= MerchantRarity.Tier.MYTHIC else &"buy")
	else:
		_detail.text = "Removed 1x %s from the reels." % give.display_name
		_detail.add_theme_color_override("font_color", DETAIL_COLOR)
		Audio.play(&"buy")
	button.set_give(TradeRules.pick_give(button.mode))
	button.pivot_offset = button.size * 0.5
	Fx.pop(button, 1.1, 0.2)
	_refresh()


func _show_symbol_detail(symbol: SymbolData) -> void:
	_detail.text = "%s: %s" % [symbol.display_name, symbol.description]
	_detail.add_theme_color_override("font_color", MerchantRarity.text_color(symbol.rarity).lerp(Color.WHITE, 0.4))


## Small rarity-bordered icon button.
func _style_choice(button: Button, rarity: int) -> void:
	var style := MerchantRarity.card_style(rarity)
	style.set_content_margin_all(2)
	style.shadow_size = 0
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = style.bg_color.lightened(0.25)
	hover.border_color = Color.WHITE
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)


func _on_repair_pressed() -> void:
	if GameState.is_castle_full() or not GameState.spend_gold(ShopCatalog.price(ShopCatalog.REPAIR_COST)):
		Audio.play(&"denied")
		return
	GameState.repair_castle(ShopCatalog.repair_amount())
	Audio.play(&"buy", 0.8)


func _on_reroll_pressed() -> void:
	if _free_rerolls > 0:
		_free_rerolls -= 1
	elif GameState.spend_gold(_reroll_cost):
		_reroll_cost += ShopCatalog.REROLL_COST_STEP
	else:
		Audio.play(&"denied")
		return
	Audio.play(&"click")
	_roll_offers()


func _on_gold_changed(_gold: int) -> void:
	_refresh()


func _on_castle_hp_changed(_hp: int, _max_hp: int) -> void:
	_refresh()


func _refresh() -> void:
	for card in _cards.get_children():
		(card as OfferCard).refresh()
	_repair_button.text = "Repair +%d (%dg)" % [ShopCatalog.repair_amount(), ShopCatalog.price(ShopCatalog.REPAIR_COST)]
	_repair_button.disabled = GameState.is_castle_full() or GameState.gold < ShopCatalog.price(ShopCatalog.REPAIR_COST)
	if _free_rerolls > 0:
		_reroll_button.text = "Reroll (free x%d)" % _free_rerolls
		_reroll_button.disabled = false
	else:
		_reroll_button.text = "Reroll (%dg)" % _reroll_cost
		_reroll_button.disabled = GameState.gold < _reroll_cost
	_unlock_trade_button.visible = not GameState.trade_unlocked
	_trade_buttons.visible = GameState.trade_unlocked
	_unlock_trade_button.text = "Open Trading Post - %d gold" % TradeRules.unlock_cost()
	_unlock_trade_button.disabled = GameState.gold < TradeRules.unlock_cost()
	_repick_trades()
	for button: TradeButton in _trade_mode_buttons.values():
		button.refresh()
	# The open choice row belongs to a pick that changed or can't be paid any more.
	if _choosing and (_choosing.give != _choosing_give or not TradeRules.can_offer(_choosing.mode, _choosing.give)):
		_close_choice()
