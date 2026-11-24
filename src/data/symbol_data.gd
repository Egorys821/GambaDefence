class_name SymbolData
extends Resource
## One symbol that can land on the slot machine reels.
## Instances live in res://data/symbols/ and are loaded by GameState.

enum Effect {
	NONE,       ## Dead symbol (e.g. Cursed Skull).
	GOLD,       ## Line pays gold.
	SPAWN_UNIT, ## Line summons troops in front of the castle.
	REPAIR,     ## Line repairs the castle.
	WILD,       ## Counts as any symbol. A full line of wilds pays gold.
	CURSE,      ## Bad symbol: a line adds spirits to tonight's wave.
}

@export var id: StringName
@export var display_name: String
@export var texture: Texture2D
@export_multiline var description: String

@export_group("Effect")
@export var effect: Effect = Effect.NONE
## Reward for a 3-of-a-kind at level 1: gold, troops summoned or HP repaired.
## Longer matches multiply it (see MachineStyle.match_multiplier).
@export var power: int = 1
## Added to `power` for every level above 1 (gold and repair symbols).
## Levels add, they don't multiply, so upgrades can't explode the economy.
@export var power_per_level: int = 0
## Troop summoned by SPAWN_UNIT lines.
@export var unit: UnitData
## Gold paid for every copy that lands anywhere on the reels.
@export var passive_gold: int = 0
## Threat points (about one spirit each) added to tonight for every copy that lands.
@export var passive_threat: int = 0
## WILD only: the symbols this wild can stand in for. Empty = any symbol.
@export var wild_for: Array[SymbolData] = []
## WILD only: also stands in for curse symbols (Tombstones), so it can
## complete a cursed line too (the Magic Rune).
@export var wild_for_curses: bool = false
## WILD only: a winning line through this wild is multiplied by this (Old Cellar's Crown).
@export var wild_multiplier: int = 1
## Family for mixed wins: three different symbols of one group pay (MachineStyle.group_pays).
@export var group: StringName
## Starts a feature when enough land anywhere (Tome of Ages' Tome).
@export var is_scatter: bool = false
## Bonus symbol for a machine feature, never junk (Dragon's Hoard's chest).
@export var is_bonus: bool = false
## Bad symbol even though it can win (Cursed Coin): never traded, and the
## merchant offers to banish it like a curse. CURSE symbols always count as cursed.
@export var cursed: bool = false
## A winning line through this symbol adds this spirit to tonight's wave
## (the Cursed Coin's Greed Monster). One per winning line.
@export var win_spirit: UnitData

## Fixed chance per copy that any cell shows this symbol, no matter how many
## other symbols are on the reels (special symbols: Crown, Jester, Chest, Tome).
## 0 = normal: the chance is copies / all copies, so it shrinks as reels grow.
@export_range(0.0, 0.5) var static_chance: float = 0.0

@export_group("Shop")
@export var in_shop: bool = true
## The merchant stops selling it once this many are on the reels (0 = no limit).
## Keeps feature symbols (Tomes, chests...) from triggering every spin.
@export var max_copies: int = 0
@export var shop_cost: int = 5
## Rarity of the merchant's "Add" offer for this symbol (see MerchantRarity).
@export var rarity: MerchantRarity.Tier = MerchantRarity.Tier.COMMON
## First night on which the merchant may offer this symbol.
@export var min_night: int = 1
## If set, the merchant sells this symbol in every castle once this stat is
## at least 1 (a Time Forge unlock). Otherwise only castles that list it.
@export var unlock_stat: StringName
## Price of the merchant's "Upgrade" offer: base + per_level * current level.
@export var upgrade_cost_base: int = 6
@export var upgrade_cost_per_level: int = 5


## What a line of `count` matching symbols gives at this symbol `level`
## (gold, troops or HP). Troop count does not grow with level; troop power does.
func reward_amount(count: int, level: int) -> int:
	var multiplier := GameState.match_multiplier(count)
	if effect == Effect.SPAWN_UNIT or effect == Effect.CURSE:
		return maxi(1, roundi(power * multiplier))
	var base := power + power_per_level * (level - 1)
	var amount := maxi(1, roundi(base * multiplier)) if base > 0 else 0
	if effect == Effect.GOLD or (effect == Effect.WILD and wild_for.is_empty()):
		amount = roundi(amount * (1.0 + GameState.stat(Stats.GOLD_MULTIPLIER)))
	if effect == Effect.GOLD:
		return amount + GameState.stat_int(Stats.COIN_LINE_BONUS)
	return amount


## Short noun for the reward, e.g. "gold", "Swordsman", "HP".
func reward_label() -> String:
	match effect:
		Effect.GOLD:
			return "gold"
		Effect.WILD:
			return "gold" if wild_for.is_empty() else "wild"
		Effect.SPAWN_UNIT:
			return unit.display_name if unit else "troops"
		Effect.REPAIR:
			return "HP"
		Effect.CURSE:
			return "spirits"
	return ""


## "any symbol" or "Bow, Crossbow" - what this wild stands in for.
func wild_targets_text() -> String:
	if wild_for.is_empty():
		return "any symbol"
	var names: Array[String] = []
	for symbol in wild_for:
		names.append(symbol.display_name)
	return ", ".join(names)


func is_wild() -> bool:
	return effect == Effect.WILD


## Curse or cursed symbol: the merchant offers to banish it, it can't be traded.
func is_cursed() -> bool:
	return cursed or effect == Effect.CURSE


## Useless symbol the merchant offers to banish.
func is_junk() -> bool:
	return effect == Effect.NONE and not is_bonus


## True if this wild can count as `other` on a payline.
func is_wild_for(other: SymbolData) -> bool:
	if not is_wild() or other.is_wild():
		return false
	if other.effect == Effect.CURSE:
		return wild_for_curses
	if wild_for.is_empty():
		return true
	for symbol in wild_for:
		if symbol.id == other.id:
			return true
	return false
