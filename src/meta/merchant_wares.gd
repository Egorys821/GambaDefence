class_name MerchantWares
extends Control
## "Merchant Wares" screen (main menu): every ware the merchant can sell,
## grouped by rarity tab. The rarity bag itself stays hidden.

signal closed

const HINTS := {
	MerchantRarity.Tier.COMMON: "Common wares - the merchant's everyday stock.",
	MerchantRarity.Tier.RARE: "Rare wares - castle works, gold boosts and stronger symbols.",
	MerchantRarity.Tier.MYTHIC: "Mythic wares - seldom seen. Grab them when they appear!",
	MerchantRarity.Tier.LEGENDARY: "Legendary wares - the merchant almost never has these.",
}
const CATEGORY_NAMES := {
	UpgradeData.Category.MACHINE: "Machine",
	UpgradeData.Category.CASTLE: "Castle",
	UpgradeData.Category.ARMY: "Army",
	UpgradeData.Category.MACHINES: "Machine",
}
const UPGRADE_ICON := preload("res://assets/sprites/symbols/sword.png")
const BANISH_ICON := preload("res://assets/sprites/symbols/skull.png")

var _tier := MerchantRarity.Tier.COMMON
var _tab_buttons: Dictionary = {}

@onready var _tabs: HBoxContainer = %Tabs
@onready var _list: VBoxContainer = %List
@onready var _hint: Label = %Hint
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	for tier: int in MerchantRarity.Tier.values():
		var button := Button.new()
		button.text = MerchantRarity.tier_name(tier)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(72, 18)
		button.add_theme_color_override("font_color", MerchantRarity.text_color(tier))
		button.add_theme_color_override("font_hover_color", MerchantRarity.text_color(tier).lightened(0.3))
		button.pressed.connect(_on_tab_pressed.bind(tier))
		_tabs.add_child(button)
		_tab_buttons[tier] = button
	_back_button.pressed.connect(_on_back_pressed)
	hide()


func open() -> void:
	show()
	_show_tier(_tier)


func _on_tab_pressed(tier: int) -> void:
	Audio.play(&"click")
	_show_tier(tier)


func _show_tier(tier: int) -> void:
	_tier = tier
	for each: int in _tab_buttons:
		(_tab_buttons[each] as Button).modulate = Color(1.3, 1.3, 1.3) if each == tier else Color(0.7, 0.7, 0.7)
	_hint.text = HINTS[tier]
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	_list.add_child(grid)
	for entry in _entries(tier):
		grid.add_child(Codex.make_entry(entry["icon"], entry["title"], entry["lines"],
			MerchantRarity.card_style(tier), MerchantRarity.text_color(tier)))


## Icon / title / lines for every ware of this rarity.
func _entries(tier: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if tier == MerchantRarity.Tier.COMMON:
		result.append({"icon": UPGRADE_ICON, "title": "Upgrade a Symbol", "lines": [
			"Raises one of your symbols a level (up to Lv%d): more gold, repairs or stronger troops." % ShopCatalog.MAX_SYMBOL_LEVEL,
			"Price depends on the symbol and its level."]})
		result.append({"icon": BANISH_ICON, "title": "Banish a Symbol", "lines": [
			"Removes a Cursed Skull or Tombstone from the reels.",
			"%d gold (Tombstone: %d gold)" % [ShopCatalog.BANISH_COST, ShopCatalog.BANISH_CURSE_COST]]})
	if tier == ShopCatalog.PATTERN_RARITY:
		result.append({"icon": ShopCatalog.PAYLINE_ICON, "title": "New Pattern", "lines": [
			"Unlocks the next winning line shape for this run.",
			"%d gold, +%d for every pattern owned" % [ShopCatalog.PAYLINE_BASE_COST, ShopCatalog.PAYLINE_COST_STEP]]})

	var symbols: Array = GameState.symbols.values().filter(
		func(symbol: SymbolData) -> bool: return symbol.in_shop and symbol.rarity == tier)
	symbols.sort_custom(func(a: SymbolData, b: SymbolData) -> bool: return a.shop_cost < b.shop_cost)
	for symbol: SymbolData in symbols:
		var price := "Add to reels: %d gold" % symbol.shop_cost
		if symbol.min_night > 1:
			price += "  -  from night %d" % symbol.min_night
		result.append({"icon": symbol.texture, "title": "Symbol: %s" % symbol.display_name,
			"lines": [symbol.description, price, _where_sold(symbol)]})

	var upgrades := GameState.get_upgrades(UpgradeData.Scope.RUN).filter(
		func(upgrade: UpgradeData) -> bool: return upgrade.rarity == tier)
	upgrades.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.base_cost < b.base_cost)
	for upgrade: UpgradeData in upgrades:
		var price := "%d gold" % upgrade.base_cost
		if upgrade.max_level > 1:
			price += " (+%d per level), up to %d levels" % [upgrade.cost_per_level, upgrade.max_level]
		if upgrade.min_night > 1:
			price += "  -  from night %d" % upgrade.min_night
		var lines: Array[String] = [upgrade.describe(), price]
		if upgrade.stat in [Stats.MAGE_TOWERS, Stats.BALLISTA_TOWERS]:
			lines.append("Needs a Watchtower to convert.")
		elif upgrade.requires:
			lines.append("Needs: %s" % upgrade.requires.display_name)
		result.append({"icon": upgrade.icon,
			"title": "%s  [%s]" % [upgrade.display_name, CATEGORY_NAMES.get(upgrade.category, "")], "lines": lines})
	return result


## Where the merchant sells this symbol: castles / machines that list it, or a Time Forge unlock.
func _where_sold(symbol: SymbolData) -> String:
	var places: Array[String] = []
	for castle in GameState.castles:
		if symbol in castle.merchant_symbols:
			var name := castle.display_name if MetaProgress.is_castle_unlocked(castle) else "???"
			if name not in places:
				places.append(name)
	for machine: MachineStyle in GameState.machines.values():
		if symbol in machine.merchant_symbols:
			places.append(machine.display_name)
	var text := "Sold at: %s" % ", ".join(places) if not places.is_empty() else ""
	if symbol.unlock_stat != &"":
		var unlock := "Everywhere once unlocked in the Time Forge"
		if GameState.stat(symbol.unlock_stat) >= 1.0:
			unlock = "Everywhere (unlocked)"
		text = unlock if text.is_empty() else "%s; %s" % [text, unlock.to_lower()]
	return text if not text.is_empty() else "Not sold by the merchant yet."


func _on_back_pressed() -> void:
	Audio.play(&"click")
	hide()
	closed.emit()
