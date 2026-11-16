class_name WaveGenerator
extends RefCounted
## Builds the list of spirits attacking each night from the current castle's
## roster and budget (see CastleData). Balance castles in res://data/castles/.


static func build(night: int) -> Array[UnitData]:
	var castle := GameState.castle
	var wave: Array[UnitData] = []
	var budget := castle.budget_for(night) + GameState.curse_threat
	var available := castle.enemies.filter(func(entry: SpawnEntry) -> bool: return entry.first_night <= night)
	while budget > 0 and not available.is_empty():
		var affordable := available.filter(func(entry: SpawnEntry) -> bool: return entry.cost <= budget)
		if affordable.is_empty():
			break
		var pick: SpawnEntry = affordable.pick_random()
		wave.append(pick.unit)
		budget -= pick.cost
	if night >= castle.nights and castle.boss:
		wave.append(castle.boss)  # The last night ends with the boss.
	return wave


static func enemy_power(night: int) -> float:
	return GameState.castle.power_for(night)


## Seconds between two spirits appearing.
static func spawn_interval(night: int) -> float:
	return maxf(0.4, GameState.castle.spawn_interval - night * 0.08)
