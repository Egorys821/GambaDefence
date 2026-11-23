extends Node
## Progress kept between runs: Chrono Shards and permanent (META) upgrade levels.
## Saved to user://meta_progress.cfg. Registered as the `MetaProgress` autoload.

signal changed

const SAVE_PATH := "user://meta_progress.cfg"
## Shards earned per run: per night survived, per spirits destroyed, and for winning.
const SHARDS_PER_NIGHT := 4
const KILLS_PER_SHARD := 4
const VICTORY_SHARDS := 30

var shards := 0
var best_night := 0
var runs := 0
## The first-run tutorial has been shown.
var tutorial_done := false
## Upgrade id -> level.
var levels: Dictionary = {}
## Ids of castles won at least once.
var conquered: Array[StringName] = []
## Id of the slot machine picked in the Time Forge (see MachineStyle).
var selected_machine: StringName = MachineStyle.STANDARD_ID
## Set to false (e.g. by tests) to keep progress in memory only.
var persist := true


func _ready() -> void:
	load_progress()


## Level owned. Castle rewards (UpgradeData.unlock_castle) are owned once
## their castle is conquered, never bought.
func level_of(id: StringName) -> int:
	var upgrade: UpgradeData = GameState.upgrades.get(id)
	if upgrade and upgrade.is_castle_reward():
		return 1 if is_conquered(upgrade.unlock_castle) else 0
	return levels.get(id, 0)


func is_conquered(castle: CastleData) -> bool:
	return castle.id in conquered


## The first castle is always open; each next one opens when the previous is won.
func is_castle_unlocked(castle: CastleData) -> bool:
	var index := GameState.castle_index(castle)
	return index <= 0 or is_conquered(GameState.castles[index - 1])


func can_buy(upgrade: UpgradeData) -> bool:
	var level := level_of(upgrade.id)
	return not upgrade.is_castle_reward() and not upgrade.is_maxed(level) and shards >= upgrade.cost_at(level) \
		and GameState.prerequisites_met(upgrade)


func buy(upgrade: UpgradeData) -> bool:
	if not can_buy(upgrade):
		return false
	shards -= upgrade.cost_at(level_of(upgrade.id))
	levels[upgrade.id] = level_of(upgrade.id) + 1
	save_progress()
	changed.emit()
	return true


func select_machine(id: StringName) -> void:
	selected_machine = id
	save_progress()
	changed.emit()


func shards_for_run(nights_survived: int, kills: int, victory: bool, castle: CastleData) -> int:
	var base := nights_survived * SHARDS_PER_NIGHT + floori(float(kills) / KILLS_PER_SHARD) + (VICTORY_SHARDS if victory else 0)
	return roundi(base * castle.shard_multiplier)


## Records a finished run and returns the shards earned.
func record_run(nights_survived: int, kills: int, victory: bool, castle: CastleData) -> int:
	var earned := shards_for_run(nights_survived, kills, victory, castle)
	shards += earned
	runs += 1
	best_night = maxi(best_night, nights_survived)
	if victory and castle.id not in conquered:
		conquered.append(castle.id)
	save_progress()
	changed.emit()
	return earned


## Removes every permanent upgrade and gives back all shards spent on them.
func refund_upgrades() -> int:
	var refunded := 0
	for id: StringName in levels:
		var upgrade: UpgradeData = GameState.upgrades.get(id)
		if upgrade == null:
			continue
		for level in levels[id]:
			refunded += upgrade.cost_at(level)
	shards += refunded
	levels.clear()
	save_progress()
	changed.emit()
	return refunded


func shards_spent() -> int:
	var spent := 0
	for id: StringName in levels:
		var upgrade: UpgradeData = GameState.upgrades.get(id)
		if upgrade:
			for level in levels[id]:
				spent += upgrade.cost_at(level)
	return spent


## Deletes everything: shards, upgrades, conquered castles, stats.
func reset_progress() -> void:
	shards = 0
	best_night = 0
	runs = 0
	levels.clear()
	conquered.clear()
	selected_machine = MachineStyle.STANDARD_ID
	save_progress()
	changed.emit()


func save_progress() -> void:
	if not persist:
		return
	var file := ConfigFile.new()
	file.set_value("progress", "shards", shards)
	file.set_value("progress", "best_night", best_night)
	file.set_value("progress", "runs", runs)
	file.set_value("progress", "tutorial_done", tutorial_done)
	file.set_value("progress", "machine", String(selected_machine))
	file.set_value("progress", "conquered", conquered.map(func(id: StringName) -> String: return String(id)))
	for id: StringName in levels:
		file.set_value("upgrades", String(id), levels[id])
	file.save(SAVE_PATH)


func load_progress() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	shards = file.get_value("progress", "shards", 0)
	best_night = file.get_value("progress", "best_night", 0)
	runs = file.get_value("progress", "runs", 0)
	tutorial_done = file.get_value("progress", "tutorial_done", false)
	selected_machine = StringName(file.get_value("progress", "machine", String(MachineStyle.STANDARD_ID)))
	conquered.clear()
	for id in file.get_value("progress", "conquered", []):
		conquered.append(StringName(id))
	levels.clear()
	if file.has_section("upgrades"):
		for key in file.get_section_keys("upgrades"):
			levels[StringName(key)] = file.get_value("upgrades", key, 0)
