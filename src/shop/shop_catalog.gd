class_name ShopCatalog
extends RefCounted
## Decides what the merchant sells and for how much. Balance prices here.
## Offers come from: symbols (add / upgrade / banish), paylines, and the
## merchant upgrade tree in res://data/upgrades/merchant/. Every offer has a
## rarity (MerchantRarity): symbol upgrades and banishes are Common, patterns
## Rare, symbols and merchant upgrades use their own `rarity` field.

const REPAIR_AMOUNT := 20
const REPAIR_COST := 6
const REROLL_BASE_COST := 5
## Each reroll on the same day costs this much more.
const REROLL_COST_STEP := 4
const BANISH_COST := 4
const BANISH_CURSE_COST := 8
## Symbols can't be upgraded past this level.
const MAX_SYMBOL_LEVEL := 5
const PAYLINE_BASE_COST := 10
const PAYLINE_COST_STEP := 6
const PATTERN_RARITY := MerchantRarity.Tier.RARE

const PAYLINE_ICON := preload("res://assets/sprites/ui/payline.png")


## Price after the Haggling discount (Stats.SHOP_DISCOUNT).
## HP from one repair (Time Forge: Stonemasons add to it).
static func repair_amount() -> int:
	return REPAIR_AMOUNT + GameState.stat_int(Stats.REPAIR_BONUS)


static func price(base: int) -> int:
	return maxi(1, roundi(base * (1.0 - GameState.stat(Stats.SHOP_DISCOUNT))))


## Today's offers (count from Stats.SHOP_SLOTS). Each slot draws a rarity token
## from the merchant's hidden bag (MerchantRarity), then a random ware of that
## rarity. If nothing of that rarity can be sold right now, the next lower
## rarity is used (then higher, if nothing lower exists).
static func roll_offers() -> Array[ShopOffer]:
	var by_tier := {}
	for tier: int in MerchantRarity.Tier.values():
		by_tier[tier] = [] as Array[ShopOffer]
	for offer in candidate_offers():
		by_tier[offer.rarity].append(offer)
	for tier: int in by_tier:
		(by_tier[tier] as Array).shuffle()
	var offers: Array[ShopOffer] = []
	for i in GameState.stat_int(Stats.SHOP_SLOTS):
		var tier := _available_tier(by_tier, GameState.draw_merchant_rarity())
		if tier < 0:
			break
		offers.append((by_tier[tier] as Array).pop_back())
	return offers


## `wanted` if it has wares left, else the closest lower tier, else the closest higher one.
static func _available_tier(by_tier: Dictionary, wanted: int) -> int:
	for tier in range(wanted, -1, -1):
		if not (by_tier[tier] as Array).is_empty():
			return tier
	for tier in range(wanted + 1, MerchantRarity.Tier.size()):
		if not (by_tier[tier] as Array).is_empty():
			return tier
	return -1


## Everything the merchant could sell right now (before rarity draws).
static func candidate_offers() -> Array[ShopOffer]:
	var candidates: Array[ShopOffer] = []
	for symbol: SymbolData in GameState.symbols.values():
		if GameState.is_symbol_available(symbol):
			candidates.append(add_symbol_offer(symbol))
		if GameState.copies_of(symbol.id) > 0:
			if symbol.is_junk() or symbol.effect == SymbolData.Effect.CURSE:
				candidates.append(banish_offer(symbol))
				if symbol.effect == SymbolData.Effect.CURSE:
					candidates.append(banish_offer(symbol))  # cursed symbols show up twice as often
			elif not symbol.is_wild() and not symbol.is_bonus and GameState.level_of(symbol.id) < MAX_SYMBOL_LEVEL:
				candidates.append(upgrade_symbol_offer(symbol))
	var shape := GameState.next_locked_shape()
	if shape >= 0:
		candidates.append(pattern_offer(shape))
	for upgrade in GameState.get_upgrades(UpgradeData.Scope.RUN):
		if GameState.night >= upgrade.min_night and not upgrade.is_maxed(GameState.upgrade_level(upgrade)) 				and GameState.prerequisites_met(upgrade):
			candidates.append(run_upgrade_offer(upgrade))
	return candidates


static func add_symbol_offer(symbol: SymbolData) -> ShopOffer:
	return ShopOffer.new(
		"Add %s" % symbol.display_name,
		"+1 on the reels. %s" % symbol.description,
		symbol.texture,
		symbol.shop_cost,
		func() -> void: GameState.add_symbol(symbol.id),
		symbol.rarity)


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


static func pattern_offer(shape: int) -> ShopOffer:
	var table := GameState.line_table()
	var lines := Paylines.lines_of(table, shape, GameState.machine_rows).size()
	return ShopOffer.new(
		"Pattern: %s" % Paylines.shape_name(table, shape),
		"New winning shape. Works at every height it fits: +%d lines now, more with extra rows." % lines,
		PAYLINE_ICON,
		PAYLINE_BASE_COST + PAYLINE_COST_STEP * (GameState.shapes.size() - 1),
		func() -> void: GameState.unlock_shape(shape),
		PATTERN_RARITY)


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
		func() -> void: GameState.add_run_upgrade(upgrade.id),
		upgrade.rarity)
