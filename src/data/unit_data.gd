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
## Bosses draw every troop into the fight, wherever they are.
@export var is_boss: bool = false

@export_group("Traits")
## Flies over troops straight to the castle. Only ranged troops, mages and
## towers can hit it.
@export var flying: bool = false
## Flat damage removed from every hit (a hit always does at least 15%).
## Punishes many weak hits; heavy hitters ignore it.
@export var armor: float = 0.0


func is_ranged() -> bool:
	return projectile_texture != null


func is_healer() -> bool:
	return heal_amount > 0.0
