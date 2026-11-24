class_name UnitData
extends Resource
## Base stats of a troop or an evil spirit. Instances live in res://data/units/.

@export var id: StringName
@export var display_name: String
@export var texture: Texture2D
@export var sprite_scale: float = 1.0

@export_group("Combat")
@export var max_hp: float = 20.0
@export var damage: float = 5.0
@export var attack_range: float = 14.0
@export var attack_cooldown: float = 1.0
@export var move_speed: float = 30.0
## How far the unit looks for something to fight.
@export var aggro_range: float = 70.0

@export_group("Ranged")
## Leave empty for melee units.
@export var projectile_texture: Texture2D
## Damage radius on impact. 0 = single target.
@export var splash_radius: float = 0.0

@export_group("Upkeep")
## Gold this troop costs every dawn (beyond the free troops, Stats.FREE_TROOPS).
@export var upkeep: float = 1.0

@export_group("Support")
## Healers restore this much HP to a wounded troop within attack_range
## instead of attacking (attack_cooldown = time between heals).
@export var heal_amount: float = 0.0

@export_group("Sound")
## Names of files in assets/audio/sfx/ (without .wav). Empty = silent.
@export var attack_sound: StringName
@export var death_sound: StringName

@export_group("Enemy")
## Gold earned when this spirit is destroyed.
@export var gold_reward: int = 0
## While a boss is alive, troops spot spirits from much farther away.
@export var is_boss: bool = false

@export_group("Traits")
## Flies over troops straight to the castle. Only ranged troops, mages and
## towers can hit it.
@export var flying: bool = false
## Flat damage removed from every hit (a hit always does at least 15%).
## Punishes many weak hits; heavy hitters ignore it.
@export var armor: float = 0.0
## Share of magic damage (mages, mage towers) ignored. 0.75 = takes a quarter.
@export_range(0.0, 1.0) var magic_resist: float = 0.0
## Deals magic damage (troops only; enemy magic_resist reduces it).
@export var magic_damage: bool = false
## Teleports behind the army's back row (archers, mages, clerics) shortly
## after rising and hunts them first.
@export var assassin: bool = false
## Digs a tunnel from its grave: underground it can't be seen, hit or
## attacked, and it passes under the army and the terrain. It comes up just
## behind the army's back row (castle side) and attacks the troops from behind.
@export var burrower: bool = false
## Siege engine (Orc Catapult): lobs splash shots into the middle of the army,
## aiming mostly at melee troops, from far away.
@export var siege: bool = false

@export_group("Death")
## Explodes when it dies, hitting every opponent within death_radius (Zombie Miner).
@export var death_damage: float = 0.0
@export var death_radius: float = 22.0

@export_group("Shockwave")
## Every wave_cooldown seconds sends out a ring that hits every opponent
## (and the castle) within wave_radius. 0 = no shockwave.
@export var wave_damage: float = 0.0
@export var wave_radius: float = 40.0
@export var wave_cooldown: float = 3.5


func is_ranged() -> bool:
	return projectile_texture != null


func has_shockwave() -> bool:
	return wave_damage > 0.0


func is_healer() -> bool:
	return heal_amount > 0.0
