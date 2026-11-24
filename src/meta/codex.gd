class_name Codex
extends Control
## "Preview" screen: every symbol, troop and spirit with its stats.
## Spirits of castles not reached yet stay hidden.

signal closed

enum Tab { SYMBOLS, TROOPS, SPIRITS }

const TAB_NAMES := {Tab.SYMBOLS: "Symbols", Tab.TROOPS: "Troops", Tab.SPIRITS: "Spirits"}
const DIM := Color("#c8b8a0")
const GOLD := Color("#f8d038")

var _tab := Tab.SYMBOLS
var _tab_buttons: Dictionary = {}

@onready var _tabs: HBoxContainer = %Tabs
@onready var _list: VBoxContainer = %List
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	for tab: Tab in TAB_NAMES:
		var button := Button.new()
		button.text = TAB_NAMES[tab]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(90, 18)
		button.pressed.connect(_show_tab.bind(tab))
		_tabs.add_child(button)
		_tab_buttons[tab] = button
	_back_button.pressed.connect(_on_back_pressed)
	hide()


func open() -> void:
	show()
	_show_tab(_tab)


func _show_tab(tab: Tab) -> void:
	_tab = tab
	for each: Tab in _tab_buttons:
		(_tab_buttons[each] as Button).modulate = Color(1.3, 1.2, 0.8) if each == tab else Color(0.75, 0.75, 0.75)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match tab:
		Tab.SYMBOLS:
			_fill_symbols()
		Tab.TROOPS:
			_fill_troops()
		Tab.SPIRITS:
			_fill_spirits()


func _fill_symbols() -> void:
	var grid := _grid()
	var symbols: Array = GameState.symbols.values()
	symbols.sort_custom(func(a: SymbolData, b: SymbolData) -> bool: return a.shop_cost < b.shop_cost)
	for symbol: SymbolData in symbols:
		var pays := ""
		match symbol.effect:
			SymbolData.Effect.WILD:
				pays = "WILD - counts as %s." % symbol.wild_targets_text()
			SymbolData.Effect.NONE:
				pays = "Bonus symbol: pays nothing on lines." if symbol.is_bonus else "Pays nothing."
			SymbolData.Effect.CURSE:
				pays = "x3 / x4 / x5: +%d / +%d / +%d spirits tonight, +%d per copy that lands" % [
					symbol.reward_amount(3, 1), symbol.reward_amount(4, 1), symbol.reward_amount(5, 1), symbol.passive_threat]
			_:
				pays = "x3 / x4 / x5: %d / %d / %d %s" % [symbol.reward_amount(3, 1), symbol.reward_amount(4, 1),
					symbol.reward_amount(5, 1), symbol.reward_label()]
		grid.add_child(make_entry(symbol.texture, symbol.display_name, [symbol.description, pays]))


func _fill_troops() -> void:
	var grid := _grid()
	for symbol: SymbolData in GameState.symbols.values():
		if symbol.effect != SymbolData.Effect.SPAWN_UNIT or symbol.unit == null:
			continue
		var unit := symbol.unit
		var lines: Array[String] = [_stat_line(unit), "Summoned by: %s (%d per line)   Upkeep: %s gold/dawn" % [
			symbol.display_name, symbol.power, str(unit.upkeep)]]
		if symbol.unlock_stat != &"" and GameState.stat(symbol.unlock_stat) < 1.0:
			lines.append("Unlock in the Time Forge, or find it in later castles.")
		grid.add_child(make_entry(unit.texture, unit.display_name, lines))


func _fill_spirits() -> void:
	for castle in GameState.castles:
		var unlocked := MetaProgress.is_castle_unlocked(castle)
		var header := Label.new()
		header.text = castle.display_name if unlocked else "??? (locked castle)"
		header.add_theme_font_size_override("font_size", 10)
		header.add_theme_color_override("font_color", GOLD)
		_list.add_child(header)
		var grid := _grid()
		var units: Array[UnitData] = []
		for entry in castle.enemies:
			units.append(entry.unit)
		units.append(castle.boss)
		for unit in units:
			if unlocked:
				var lines: Array[String] = [_stat_line(unit)]
				lines.append("BOSS - appears on the last night." if unit.is_boss else "Gold when destroyed: %d" % unit.gold_reward)
				grid.add_child(make_entry(unit.texture, unit.display_name, lines))
			else:
				var hidden := make_entry(unit.texture, "???", ["Conquer the castle before to learn more."])
				(hidden.get_child(0).get_child(0) as TextureRect).modulate = Color(0, 0, 0, 0.8)
				grid.add_child(hidden)


func _stat_line(unit: UnitData) -> String:
	var text := "HP %d   DMG %d   Range %d   Speed %d" % [unit.max_hp, unit.damage, unit.attack_range, unit.move_speed]
	if unit.is_healer():
		text = "HP %d   Heals %d   Range %d   Speed %d" % [unit.max_hp, unit.heal_amount, unit.attack_range, unit.move_speed]
	if unit.is_ranged():
		text += "   Ranged"
	if unit.splash_radius > 0.0:
		text += " (splash)"
	if unit.flying:
		text += "   FLYING: only ranged troops and towers hit it"
	if unit.armor > 0.0:
		text += "   ARMOR %d: weak hits barely hurt" % unit.armor
	if unit.magic_resist > 0.0:
		text += "   MAGIC RESIST %d%%: mages and mage towers barely hurt it" % roundi(unit.magic_resist * 100.0)
	if unit.has_shockwave():
		text += "   SHOCKWAVE: hits every troop nearby (%d dmg) every %.1fs" % [unit.wave_damage, unit.wave_cooldown]
	if unit.assassin:
		text += "   ASSASSIN: teleports behind your army and hunts archers, mages and clerics"
	if unit.siege:
		text += "   SIEGE: lobs boulders into the middle of your army, mostly at melee troops; your troops march out to destroy it"
	if unit.death_damage > 0.0:
		text += "   EXPLODES on death (%d dmg around it)" % unit.death_damage
	if unit.burrower:
		text += "   BURROWS: digs under your army (can't be hit), comes up behind it and attacks from the back"
	if unit.is_boss:
		text += "   Calls escorts and ENRAGES at half HP"
	return text


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	_list.add_child(grid)
	return grid


## Card with an icon, a title and small description lines. Also used by MerchantWares.
static func make_entry(texture: Texture2D, title: String, lines: Array, style: StyleBox = null,
		title_color := Color.TRANSPARENT) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(296, 0)
	if style:
		card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 9)
	if title_color.a > 0.0:
		name_label.add_theme_color_override("font_color", title_color)
	text.add_child(name_label)
	for line: String in lines:
		var label := Label.new()
		label.text = line
		label.custom_minimum_size = Vector2(240, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 6)
		label.add_theme_color_override("font_color", DIM)
		text.add_child(label)
	return card


func _on_back_pressed() -> void:
	Audio.play(&"click")
	hide()
	closed.emit()
