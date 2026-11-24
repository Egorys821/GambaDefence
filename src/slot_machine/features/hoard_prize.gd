class_name HoardPrize
extends RefCounted
## What one Dragon's Hoard chest holds. Rolled when the chest locks in place.

enum Kind { GOLD, TROOPS, REPAIR, MINI, MINOR, MAJOR, GRAND }

## Kind -> chance weight. Tune the hoard here.
const WEIGHTS := {
	Kind.GOLD: 71.0,
	Kind.TROOPS: 12.0,
	Kind.REPAIR: 8.0,
	Kind.MINI: 3.0,
	Kind.MINOR: 0.9,
	Kind.MAJOR: 0.0,  # only the Dragon's Treasure (HoardRound.BIG_HOARD_CHANCE)
}
## Big gold chests are this rare among GOLD chests.
const BIG_GOLD_CHANCE := 0.22
const TROOPS_PER_CHEST := 2
const REPAIR_PER_CHEST := 15
## Jackpots: gold, troops, repair (-1 = full repair).
const JACKPOTS := {
	Kind.MINI: [15, 0, 0],
	Kind.MINOR: [40, 3, 0],
	Kind.MAJOR: [160, 10, -1],  # the Dragon's Treasure: a big army and a pile of gold
	Kind.GRAND: [200, 8, -1],
}
const JACKPOT_NAMES := {Kind.MINI: "MINI", Kind.MINOR: "MINOR", Kind.MAJOR: "MAJOR", Kind.GRAND: "GRAND"}

var kind: Kind = Kind.GOLD
var gold := 0
var troops := 0
## -1 = repair the castle fully.
var repair := 0
## Unit symbol whose troops this chest summons.
var unit_symbol: SymbolData


## Rolls a chest. `coin_power` scales gold chests; troops come from one of
## `unit_symbols` (the troop symbols on the player's reels).
static func roll(rng: RandomNumberGenerator, coin_power: int, unit_symbols: Array) -> HoardPrize:
	var prize := HoardPrize.new()
	prize.kind = _roll_kind(rng)
	if prize.kind == Kind.TROOPS and unit_symbols.is_empty():
		prize.kind = Kind.GOLD
	match prize.kind:
		Kind.GOLD:
			var big := rng.randf() < BIG_GOLD_CHANCE
			prize.gold = maxi(1, roundi(coin_power * (4 if big else rng.randi_range(1, 2)) * HoardRound.PAYOUT_SCALE))
		Kind.TROOPS:
			prize.troops = TROOPS_PER_CHEST
			prize.unit_symbol = unit_symbols[rng.randi() % unit_symbols.size()]
		Kind.REPAIR:
			prize.repair = REPAIR_PER_CHEST
		_:
			prize.set_jackpot(prize.kind, unit_symbols, rng)
	return prize


static func grand(unit_symbols: Array, rng: RandomNumberGenerator) -> HoardPrize:
	var prize := HoardPrize.new()
	prize.set_jackpot(Kind.GRAND, unit_symbols, rng)
	return prize


func set_jackpot(p_kind: Kind, unit_symbols: Array, rng: RandomNumberGenerator) -> void:
	kind = p_kind
	var values: Array = JACKPOTS[kind]
	gold = roundi(values[0] * HoardRound.PAYOUT_SCALE)
	troops = values[1] if not unit_symbols.is_empty() else 0
	repair = values[2]
	if troops > 0:
		unit_symbol = unit_symbols[rng.randi() % unit_symbols.size()]


func is_jackpot() -> bool:
	return JACKPOT_NAMES.has(kind)


## Short text drawn on the chest.
func short_text() -> String:
	if is_jackpot():
		return JACKPOT_NAMES[kind]
	if troops > 0:
		return "+%d" % troops
	if repair != 0:
		return "HP"
	return str(gold)


static func _roll_kind(rng: RandomNumberGenerator) -> Kind:
	var total := 0.0
	for weight: float in WEIGHTS.values():
		total += weight
	var roll := rng.randf() * total
	for kind: Kind in WEIGHTS:
		roll -= WEIGHTS[kind]
		if roll < 0.0:
			return kind
	return Kind.GOLD
