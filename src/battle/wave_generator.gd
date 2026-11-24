class_name WaveGenerator
extends RefCounted
## Builds the list of spirits attacking each night from the current castle's
## roster and budget (see CastleData). Balance castles in res://data/castles/.

## Global difficulty knobs on top of every castle's own numbers.
## More threat points per night (bigger waves)...
const THREAT_MULTIPLIER := 1.35
## ...tougher spirits (hp and damage)...
const POWER_MULTIPLIER := 1.25
## ...arriving faster.
const SPAWN_INTERVAL_MULTIPLIER := 0.85
## Every point of curse threat (Tombstones on the reels) adds exactly one of
## these to the night, so "Curse +30" really means 30 more spirits.
const CURSE_SPIRIT: UnitData = preload("res://data/units/ghost.tres")
## Spirit added for every winning line through a Cursed Coin (GameState.greed_spirits).
const GREED_SPIRIT: UnitData = preload("res://data/units/greed_monster.tres")
## The exponential horde never grows past this multiple of the base wave.
const MAX_GROWTH := 4.0
## Troops beyond this many make the horde bigger (CastleData.army_threat each).
const ARMY_FREE_TROOPS := 20
## With more threat than this left to spend, the wave buys the heavier half of
## the roster, so huge late waves are tougher spirits instead of endless swarms.
const HEAVY_BUDGET := 60


## Threat points tonight: the castle's budget, its exponential growth and the
## size of the player's army (`troops` alive when the night starts).
static func threat_for(night: int, troops: int = 0) -> int:
	var castle := GameState.castle
	var budget := castle.budget_for(night) * THREAT_MULTIPLIER * minf(castle.growth_for(night), MAX_GROWTH)
	budget += maxi(0, troops - ARMY_FREE_TROOPS) * castle.army_threat
	return roundi(budget)


## Threat a big army adds tonight (0 below ARMY_FREE_TROOPS or on early castles).
static func army_extra(troops: int) -> int:
	return roundi(maxi(0, troops - ARMY_FREE_TROOPS) * GameState.castle.army_threat)


static func build(night: int, troops: int = 0) -> Array[UnitData]:
	var castle := GameState.castle
	var wave: Array[UnitData] = []
	var budget := threat_for(night, troops)
	var available := castle.enemies.filter(func(entry: SpawnEntry) -> bool: return entry.first_night <= night)
	while budget > 0 and not available.is_empty():
		var affordable := available.filter(func(entry: SpawnEntry) -> bool: return entry.cost <= budget)
		if affordable.is_empty():
			break
		if budget > HEAVY_BUDGET and affordable.size() > 1:
			affordable.sort_custom(func(a: SpawnEntry, b: SpawnEntry) -> bool: return a.cost > b.cost)
			affordable = affordable.slice(0, ceili(affordable.size() * 0.5))
		var pick: SpawnEntry = affordable.pick_random()
		wave.append(pick.unit)
		budget -= pick.cost
	# Cursed ghosts are mixed into the wave, not all at the end.
	for i in GameState.curse_threat:
		wave.insert(randi_range(0, wave.size()), CURSE_SPIRIT)
	for i in GameState.greed_spirits:
		wave.insert(randi_range(0, wave.size()), GREED_SPIRIT)
	if night >= castle.nights and castle.boss:
		wave.append(castle.boss)  # The last night ends with the boss.
	return wave


static func enemy_power(night: int) -> float:
	return GameState.castle.power_for(night) * POWER_MULTIPLIER


## Seconds between two spirits appearing.
static func spawn_interval(night: int) -> float:
	return maxf(0.35, (GameState.castle.spawn_interval - night * 0.08) * SPAWN_INTERVAL_MULTIPLIER)
