class_name ShopCatalog
extends RefCounted
## Decides what the merchant sells and for how much. Balance prices here.
## Offers come from: symbols (add / upgrade / banish), paylines, and RUN
## upgrades in res://data/upgrades/run/ (castle, machine and army upgrades).

const REPAIR_AMOUNT := 20
const REPAIR_COST := 6
const REROLL_BASE_COST := 5
## Each reroll on the same day costs this much more.
const REROLL_COST_STEP := 4
const BANISH_COST := 4
const BANISH_CURSE_COST := 8
## Symbols can't be upgraded past this level.
const MAX_SYMBOL_LEVEL := 5
const PAYLINE_BASE_COST := 8
const PAYLINE_COST_STEP := 4

const PAYLINE_ICON := preload("res://assets/sprites/ui/payline.png")


## Price after the Haggling discount (Stats.SHOP_DISCOUNT).
static func price(base: int) -> int:
	return maxi(1, roundi(base * (1.0 - GameState.stat(Stats.SHOP_DISCOUNT))))


## Random selection of offers for today (count from Stats.SHOP_SLOTS).
static func roll_offers() -> Array[ShopOffer]:
	var candidates: Array[ShopOffer] = []
	for symbol: SymbolData in GameState.symbols.values():
		if GameState.is_symbol_available(symbol):
			candidates.append(add_symbol_offer(symbol))
		if GameState.copies_of(symbol.id) > 0:
			if symbol.effect == SymbolData.Effect.NONE or symbol.effect == SymbolData.Effect.CURSE:
				candidates.append(banish_offer(symbol))
				if symbol.effect == SymbolData.Effect.CURSE:
					candidates.append(banish_offer(symbol))  # cursed symbols show up twice as often
			elif not symbol.is_wild() and symbol.effect != SymbolData.Effect.RESPIN 					and GameState.level_of(symbol.id) < MAX_SYMBOL_LEVEL:
				candidates.append(upgrade_symbol_offer(symbol))
	var line := GameState.next_locked_payline()
	if line >= 0:
		candidates.append(payline_offer(line))
	for upgrade in GameState.get_upgrades(UpgradeData.Scope.RUN):
		if GameState.night >= upgrade.min_night and not upgrade.is_maxed(GameState.upgrade_level(upgrade)) 				and GameState.prerequisites_met(upgrade):
			candidates.append(run_upgrade_offer(upgrade))
	candidates.shuffle()
	var offers: Array[ShopOffer] = []
	offers.assign(candidates.slice(0, GameState.stat_int(Stats.SHOP_SLOTS)))
	return offers


static func add_symbol_offer(symbol: SymbolData) -> ShopOffer:
	return ShopOffer.new(
		"Add %s" % symbol.display_name,
		"+1 on the reels. %s" % symbol.description,
		symbol.texture,
		symbol.shop_cost,
		func() -> void: GameState.add_symbol(symbol.id))


static func upgrade_symbol_offer(symbol: SymbolData) -> ShopOffer:
	var level := GameState.level_of(symbol.id)
	var bonus := ""
	if symbol.effect == SymbolData.Effect.SPAWN_UNIT:
		bonus = "%s +%d%% HP and damage." % [symbol.unit.display_name, roundi(GameState.LEVEL_POWER_BONUS * 100)]
	else:
		bonus = "3 in a row: %d -> %d %s." % [symbol.reward_amount(3, level), symbol.reward_amount(3, level + 1), symbol.reward_label()]
	return ShopOffer.new(
		"Upgrade %s (Lv%d)" % [symbol.display_name, level + 1],
		bonus,
		symbol.texture,
		symbol.upgrade_cost_base + symbol.upgrade_cost_per_level * level,
		func() -> void: GameState.upgrade_symbol(symbol.id))


static func banish_offer(symbol: SymbolData) -> ShopOffer:
	return ShopOffer.new(
		"Banish %s" % symbol.display_name,
		"-1 on the reels, so better symbols land more often.",
		symbol.texture,
		BANISH_CURSE_COST if symbol.effect == SymbolData.Effect.CURSE else BANISH_COST,
		func() -> void: GameState.remove_symbol(symbol.id))


static func payline_offer(line: int) -> ShopOffer:
	var extra_lines := GameState.paylines.size() - Paylines.row_lines(GameState.machine_rows).size()
	return ShopOffer.new(
		"Payline: %s" % Paylines.name_of(line),
		"A new line shape that pays out.",
		PAYLINE_ICON,
		PAYLINE_BASE_COST + PAYLINE_COST_STEP * extra_lines,
		func() -> void: GameState.unlock_payline(line))


static func run_upgrade_offer(upgrade: UpgradeData) -> ShopOffer:
	var level := GameState.upgrade_level(upgrade)
	var title := upgrade.display_name
	if upgrade.max_level > 1:
		title += " %d/%d" % [level + 1, upgrade.max_level]
	return ShopOffer.new(
		title,
		upgrade.describe(),
		upgrade.icon,
		upgrade.cost_at(level),
		func() -> void: GameState.add_run_upgrade(upgrade.id))
