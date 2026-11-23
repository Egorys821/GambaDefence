class_name CastleData
extends Resource
## One castle on the kingdom map: its reels, merchant, spirits, boss and rewards.
## Castles live in res://data/castles/ and unlock in `order` as each is conquered.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var order: int = 0
## Position on the map screen (in a 400x220 area).
@export var map_position: Vector2
@export var nights: int = 10
## Tint applied to the ground (snow, ash...).
@export var ground_tint: Color = Color.WHITE
## The battlefield in front of the castle (terrain, graveyards, rally points).
## null = open field. Layouts live in res://data/layouts/.
@export var layout: BattleLayout

@export_group("Reels")
## Symbols on the reels at the start of a run (Cursed Skulls come from Stats).
@export var starting_pool: Array[PoolEntry] = []
## Symbols the merchant can sell here (Time Forge unlocks add more).
@export var merchant_symbols: Array[SymbolData] = []
## Highest pattern tier sold here (see Paylines.SHAPES "tier").
@export var payline_tier: int = 1

@export_group("Spirits")
@export var enemies: Array[SpawnEntry] = []
## Appears at the end of the last night.
@export var boss: UnitData
## Threat points per night: base + night * per_night + night^2 / ramp_divisor.
@export var budget_base: int = 3
@export var budget_per_night: int = 4
@export var budget_ramp_divisor: int = 5
## Spirit hp/damage multiplier on night 1, and its growth per night.
@export var power_base: float = 1.0
@export var power_per_night: float = 0.18
## Seconds between spirits on night 1 (gets faster each night).
@export var spawn_interval: float = 1.4

@export_group("Curse")
## From this night on, every dawn adds Tombstones to the reels.
@export var curse_start_night: int = 4
@export var curses_per_dawn: int = 1

@export_group("Rewards")
## Multiplies the Chrono Shards earned here.
@export var shard_multiplier: float = 1.0
## Crowns won the first time this castle is conquered (spent in the Time Forge).
@export var crown_reward: int = 1


func budget_for(night: int) -> int:
	return budget_base + night * budget_per_night + floori(night * night / float(maxi(1, budget_ramp_divisor)))


func power_for(night: int) -> float:
	return power_base + (night - 1) * power_per_night
