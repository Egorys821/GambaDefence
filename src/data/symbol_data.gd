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
	RESPIN,     ## A line grants free spins that start automatically.
}

@export var id: StringName
@export var display_name: String
@export var texture: Texture2D
@export_multiline var description: String

@export_group("Effect")
@export var effect: Effect = Effect.NONE
## Reward for a 3-of-a-kind at level 1: gold, troops summoned or HP repaired.
## 4 and 5 of a kind multiply it (see Paylines.MATCH_MULTIPLIER).
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

@export_group("Shop")
@export var in_shop: bool = true
@export var shop_cost: int = 5
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
	var multiplier: int = Paylines.MATCH_MULTIPLIER.get(count, 1)
	if effect == Effect.RESPIN:
		return power * (count - Paylines.MIN_MATCH + 1)  # 1 / 2 / 3 free spins
	if effect == Effect.SPAWN_UNIT or effect == Effect.CURSE:
		return power * multiplier
	var base := power + power_per_level * (level - 1)
	if effect == Effect.GOLD:
		return base * multiplier + GameState.stat_int(Stats.COIN_LINE_BONUS)
	return base * multiplier


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
		Effect.RESPIN:
			return "free spins"
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


## True if this wild can count as `other` on a payline.
func is_wild_for(other: SymbolData) -> bool:
	if not is_wild() or other.is_wild() or other.effect == Effect.CURSE:
		return false
	if wild_for.is_empty():
		return true
	for symbol in wild_for:
		if symbol.id == other.id:
			return true
	return false
