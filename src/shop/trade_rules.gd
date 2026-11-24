class_name TradeRules
extends RefCounted
## The merchant's Trading Post: bought once per run, then three trades that can
## be used any number of times a day at a fixed price. The merchant picks the
## symbol you give at random (shown on the button, re-picked after each trade
## and every day); the player chooses what to get:
##   SWAP_UP   - give 2 copies of a symbol, get 1 symbol of your choice one
##               rarity higher (e.g. 2 Bows -> 1 Crossbow).
##   SWAP_SAME - give 1 copy, get 1 other symbol of the same rarity.
##   REMOVE    - take 1 copy of that symbol off the reels.
## "Tier" here is the symbol's merchant rarity (MerchantRarity.Tier).
## You can only receive symbols already on your reels this run (of the right
## rarity), and never another machine's signature symbol.

enum Mode { SWAP_UP, SWAP_SAME, REMOVE }

## Price to open the Trading Post for the rest of the run.
const UNLOCK_COST := 20
## Fixed price of each trade (before the Haggling discount).
const COSTS := {
	Mode.SWAP_UP: 60,
	Mode.SWAP_SAME: 30,
	Mode.REMOVE: 50,
}
## Copies given in each trade.
const GIVE_COUNT := {
	Mode.SWAP_UP: 2,
	Mode.SWAP_SAME: 1,
	Mode.REMOVE: 1,
}

const NAMES := {
	Mode.SWAP_UP: "Upgrade",
	Mode.SWAP_SAME: "Replace",
	Mode.REMOVE: "Remove",
}
const HINTS := {
	Mode.SWAP_UP: "Give 2x %s, pick 1 %s symbol.",
	Mode.SWAP_SAME: "Give 1x %s, pick 1 other %s symbol.",
	Mode.REMOVE: "Take 1x %s off your reels.",
}


## Fixed price after the Haggling discount and Fair Trades (Time Forge).
static func cost(mode: Mode) -> int:
	return maxi(1, ShopCatalog.price(COSTS[mode]) - GameState.stat_int(Stats.TRADE_DISCOUNT))


static func unlock_cost() -> int:
	return ShopCatalog.price(UNLOCK_COST)


## Skulls and Tombstones can be removed, never traded for something better.
static func is_tradeable(symbol: SymbolData) -> bool:
	return not symbol.is_junk() and not symbol.is_cursed() and not GameState.is_special_symbol(symbol)


## Owned symbols the player can give in this mode (that also have something to get).
static func give_options(mode: Mode) -> Array[SymbolData]:
	var result: Array[SymbolData] = []
	for id: StringName in GameState.pool:
		var symbol := GameState.get_symbol(id)
		if symbol == null or GameState.copies_of(id) < GIVE_COUNT[mode]:
			continue
		if mode == Mode.REMOVE:
			# Junk and curses can always go; good symbols stop at the floor.
			var junk := symbol.is_junk() or symbol.is_cursed()
			if not GameState.is_special_symbol(symbol) and (junk or GameState.pool_total() > GameState.min_kept_symbols()):
				result.append(symbol)
		elif is_tradeable(symbol) and not get_options(mode, symbol).is_empty():
			result.append(symbol)
	result.sort_custom(_by_rarity_then_cost)
	return result


## What the player can receive for `give`: symbols already on the reels this
## run with the wanted rarity (never another machine's symbol).
static func get_options(mode: Mode, give: SymbolData) -> Array[SymbolData]:
	var result: Array[SymbolData] = []
	if mode == Mode.REMOVE or give == null:
		return result
	var wanted_rarity := receive_rarity(mode, give)
	for id: StringName in GameState.pool:
		var symbol := GameState.get_symbol(id)
		if symbol == null or symbol.id == give.id or symbol.rarity != wanted_rarity or not is_tradeable(symbol):
			continue
		if symbol.max_copies > 0 and GameState.copies_of(symbol.id) >= symbol.max_copies:
			continue
		if GameState.is_other_machine_symbol(symbol):
			continue
		result.append(symbol)
	result.sort_custom(_by_rarity_then_cost)
	return result


## Random symbol from give_options (what the button offers to take), or null.
static func pick_give(mode: Mode) -> SymbolData:
	var options := give_options(mode)
	return options.pick_random() if not options.is_empty() else null


## The trade button can be used: open, affordable, and `give` is still allowed.
static func can_offer(mode: Mode, give: SymbolData) -> bool:
	return GameState.trade_unlocked and give != null and GameState.gold >= cost(mode) \
		and give in give_options(mode)


## Rarity of what `give` turns into (REMOVE: its own rarity).
static func receive_rarity(mode: Mode, give: SymbolData) -> int:
	return give.rarity + 1 if mode == Mode.SWAP_UP else give.rarity


## Tooltip text for a trade button.
static func describe(mode: Mode, give: SymbolData) -> String:
	if give == null:
		return "%s: nothing to trade right now." % NAMES[mode]
	if mode == Mode.REMOVE:
		return HINTS[mode] % give.display_name
	return HINTS[mode] % [give.display_name, MerchantRarity.tier_name(receive_rarity(mode, give))]


static func can_trade(mode: Mode, give: SymbolData, receive: SymbolData) -> bool:
	if not GameState.trade_unlocked or give == null or GameState.gold < cost(mode):
		return false
	if give not in give_options(mode):
		return false
	return mode == Mode.REMOVE or receive in get_options(mode, give)


## Pays and performs the trade. Returns false (and changes nothing) if not allowed.
static func trade(mode: Mode, give: SymbolData, receive: SymbolData = null) -> bool:
	if not can_trade(mode, give, receive) or not GameState.spend_gold(cost(mode)):
		return false
	for i in GIVE_COUNT[mode]:
		GameState.remove_symbol(give.id)
	if mode != Mode.REMOVE:
		GameState.add_symbol(receive.id)
	return true


## Opens the Trading Post for this run.
static func unlock() -> bool:
	if GameState.trade_unlocked or not GameState.spend_gold(unlock_cost()):
		return false
	GameState.trade_unlocked = true
	return true


static func _by_rarity_then_cost(a: SymbolData, b: SymbolData) -> bool:
	if a.rarity != b.rarity:
		return a.rarity < b.rarity
	return a.shop_cost < b.shop_cost
