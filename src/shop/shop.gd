class_name Shop
extends VBoxContainer
## The wandering merchant: random offers each day (Stats.SHOP_SLOTS) plus repair and reroll.
## Offers are drawn by rarity from a hidden bag, see ShopCatalog.roll_offers().

var _offers: Array[ShopOffer] = []
var _reroll_cost := ShopCatalog.REROLL_BASE_COST

@onready var _cards: VBoxContainer = %Cards
@onready var _repair_button: Button = %RepairButton
@onready var _reroll_button: Button = %RerollButton


func _ready() -> void:
	_repair_button.pressed.connect(_on_repair_pressed)
	_reroll_button.pressed.connect(_on_reroll_pressed)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.castle_hp_changed.connect(_on_castle_hp_changed)


## New stock for a new day.
func restock() -> void:
	_reroll_cost = ShopCatalog.price(ShopCatalog.REROLL_BASE_COST)
	_roll_offers()


func _roll_offers() -> void:
	_offers = ShopCatalog.roll_offers()
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for offer in _offers:
		var card := OfferCard.new(offer)
		card.buy_pressed.connect(_on_buy_pressed.bind(card))
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


func _on_repair_pressed() -> void:
	if GameState.is_castle_full() or not GameState.spend_gold(ShopCatalog.price(ShopCatalog.REPAIR_COST)):
		Audio.play(&"denied")
		return
	GameState.repair_castle(ShopCatalog.REPAIR_AMOUNT)
	Audio.play(&"buy", 0.8)


func _on_reroll_pressed() -> void:
	if not GameState.spend_gold(_reroll_cost):
		Audio.play(&"denied")
		return
	_reroll_cost += ShopCatalog.REROLL_COST_STEP
	Audio.play(&"click")
	_roll_offers()


func _on_gold_changed(_gold: int) -> void:
	_refresh()


func _on_castle_hp_changed(_hp: int, _max_hp: int) -> void:
	_refresh()


func _refresh() -> void:
	for card in _cards.get_children():
		(card as OfferCard).refresh()
	_repair_button.text = "Repair +%d (%dg)" % [ShopCatalog.REPAIR_AMOUNT, ShopCatalog.price(ShopCatalog.REPAIR_COST)]
	_repair_button.disabled = GameState.is_castle_full() or GameState.gold < ShopCatalog.price(ShopCatalog.REPAIR_COST)
	_reroll_button.text = "Reroll (%dg)" % _reroll_cost
	_reroll_button.disabled = GameState.gold < _reroll_cost
