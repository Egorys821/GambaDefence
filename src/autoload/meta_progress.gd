extends Node
## Progress kept between runs: Chrono Shards, Crowns and permanent (META)
## upgrade levels. Saved to user://meta_progress.cfg. Registered as the
## `MetaProgress` autoload.
##
## Crowns are won the first time each castle is conquered
## (CastleData.crown_reward) and buy the Time Forge's crown nodes. They are not
## saved: crowns() = crowns won by conquered castles - crowns spent on nodes.

signal changed

const SAVE_PATH := "user://meta_progress.cfg"
## Save format. 2 = the four-window Time Forge with Crowns.
const SAVE_VERSION := 2
## Shard prices (per level) of upgrades that were bought with shards before
## version 2 and cost Crowns now; refunded when an old save is loaded.
const LEGACY_SHARD_PRICES := {
	&"extra_row": [40, 80],
	&"rune_mastery": [45],
	&"recruit_crossbows": [35],
	&"recruit_clerics": [50],
}
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
## Crowns won by the last record_run() (0 unless a castle was conquered for the first time).
var last_crowns := 0
## Shards given back when an old save was moved to the new Time Forge (0 = none).
## Saved until the menu has told the player, then set back to 0.
var migrated_shards := 0
## Set to false (e.g. by tests) to keep progress in memory only.
var persist := true


func _ready() -> void:
	# Debug tools (tests, autoplay) never write the real save.
	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://tools/"):
			persist = false
	load_progress()


func level_of(id: StringName) -> int:
	return levels.get(id, 0)


## Crowns left to spend.
func crowns() -> int:
	return crowns_won() - crowns_spent()


func crowns_won() -> int:
	var total := 0
	for castle in GameState.castles:
		if is_conquered(castle):
			total += castle.crown_reward
	return total


func crowns_spent() -> int:
	var spent := 0
	for id: StringName in levels:
		var upgrade: UpgradeData = GameState.upgrades.get(id)
		if upgrade and upgrade.is_crown_node():
			spent += upgrade.crown_cost * levels[id]
	return spent


func is_conquered(castle: CastleData) -> bool:
	return castle.id in conquered


## The first castle is always open; each next one opens when the previous is won.
func is_castle_unlocked(castle: CastleData) -> bool:
	var index := GameState.castle_index(castle)
	# A castle won before stays open even if new castles were added before it.
	return index <= 0 or is_conquered(castle) or is_conquered(GameState.castles[index - 1])


## Shards or Crowns, whichever this node is paid with.
func can_afford(upgrade: UpgradeData) -> bool:
	var price := upgrade.cost_at(level_of(upgrade.id))
	return (crowns() if upgrade.is_crown_node() else shards) >= price


func can_buy(upgrade: UpgradeData) -> bool:
	return not upgrade.is_maxed(level_of(upgrade.id)) and can_afford(upgrade) and GameState.prerequisites_met(upgrade)


func buy(upgrade: UpgradeData) -> bool:
	if not can_buy(upgrade):
		return false
	if not upgrade.is_crown_node():
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


## Records a finished run and returns the shards earned. A first conquest
## also wins the castle's Crowns (see last_crowns).
func record_run(nights_survived: int, kills: int, victory: bool, castle: CastleData) -> int:
	var earned := shards_for_run(nights_survived, kills, victory, castle)
	shards += earned
	runs += 1
	best_night = maxi(best_night, nights_survived)
	last_crowns = 0
	if victory and castle.id not in conquered:
		conquered.append(castle.id)
		last_crowns = castle.crown_reward
	save_progress()
	changed.emit()
	return earned


## Removes every permanent upgrade and gives back all shards (and Crowns)
## spent on them. Returns the shards refunded.
func refund_upgrades() -> int:
	var refunded := shards_spent()
	shards += refunded
	levels.clear()
	save_progress()
	changed.emit()
	return refunded


func shards_spent() -> int:
	var spent := 0
	for id: StringName in levels:
		var upgrade: UpgradeData = GameState.upgrades.get(id)
		if upgrade and not upgrade.is_crown_node():
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
	file.set_value("progress", "version", SAVE_VERSION)
	file.set_value("progress", "runs", runs)
	file.set_value("progress", "tutorial_done", tutorial_done)
	file.set_value("progress", "migrated_shards", migrated_shards)
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
	migrated_shards = file.get_value("progress", "migrated_shards", 0)
	selected_machine = StringName(file.get_value("progress", "machine", String(MachineStyle.STANDARD_ID)))
	conquered.clear()
	for id in file.get_value("progress", "conquered", []):
		conquered.append(StringName(id))
	levels.clear()
	if file.has_section("upgrades"):
		for key in file.get_section_keys("upgrades"):
			levels[StringName(key)] = file.get_value("upgrades", key, 0)
	if file.get_value("progress", "version", 1) < SAVE_VERSION:
		_migrate_to_crowns()


## The Time Forge was rebuilt (four windows, Crowns, new tree): give back every
## shard spent so the player can forge again. Crowns come from conquered castles.
func _migrate_to_crowns() -> void:
	var refunded := 0
	for id: StringName in levels:
		# Loaded directly: this runs before the GameState autoload exists.
		var path := "res://data/upgrades/meta/%s.tres" % id
		var upgrade: UpgradeData = load(path) if ResourceLoader.exists(path) else null
		if LEGACY_SHARD_PRICES.has(id):
			var prices: Array = LEGACY_SHARD_PRICES[id]
			for level in mini(levels[id], prices.size()):
				refunded += prices[level]
		elif upgrade and not upgrade.is_crown_node():
			for level in levels[id]:
				refunded += upgrade.cost_at(level)
	levels.clear()
	shards += refunded
	migrated_shards = refunded
	save_progress()
