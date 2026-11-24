class_name Watchtower
extends Node2D
## A passive tower on the field that shoots spirits at night.
## How many stand is Stats.EXTRA_TOWERS. Some can be upgraded into Mage Towers
## (splash orbs) or Ballista Towers (heavy long-range bolts) through
## Stats.MAGE_TOWERS / Stats.BALLISTA_TOWERS. Damage and fire rate scale with
## the castle's tower stats. The node origin is the bottom centre.

enum Kind { ARCHER, MAGE, BALLISTA }

## Per kind: texture, range, damage factor (x Stats.TOWER_DAMAGE),
## fire-rate factor (x Stats.TOWER_SPEED), projectile, splash radius, sound.
const KINDS := {
	Kind.ARCHER: {
		"texture": preload("res://assets/sprites/environment/tower.png"),
		"range": 150.0, "damage": 0.75, "rate": 1.0,
		"projectile": preload("res://assets/sprites/projectiles/bolt.png"), "splash": 0.0, "sound": &"bolt",
	},
	Kind.MAGE: {
		"texture": preload("res://assets/sprites/environment/mage_tower.png"),
		"range": 140.0, "damage": 1.0, "rate": 0.6,
		"projectile": preload("res://assets/sprites/projectiles/magic_orb.png"), "splash": 24.0, "sound": &"magic",
	},
	Kind.BALLISTA: {
		"texture": preload("res://assets/sprites/environment/ballista_tower.png"),
		"range": 210.0, "damage": 2.6, "rate": 0.45,
		"projectile": preload("res://assets/sprites/projectiles/bolt.png"), "splash": 0.0, "sound": &"bolt",
	},
}
const SHOOT_OFFSET := Vector2(0, -26)

var battlefield: Battlefield
var kind: Kind = Kind.ARCHER
## Duck-typing compatibility with Unit for projectiles.
var is_dead := false
var _cooldown := 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_apply_kind()


func set_kind(new_kind: Kind) -> void:
	if new_kind == kind:
		return
	kind = new_kind
	if is_node_ready():
		_apply_kind()
		play_build()


func _process(delta: float) -> void:
	if battlefield == null or not battlefield.is_night:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var config: Dictionary = KINDS[kind]
	var from := position + SHOOT_OFFSET
	var tower_range: float = config["range"] * (1.0 + GameState.stat(Stats.TOWER_RANGE))
	var target := battlefield.nearest_unit(from, tower_range, Unit.Team.ENEMY)
	if target == null:
		return
	var damage: float = GameState.stat(Stats.TOWER_DAMAGE) * config["damage"]
	battlefield.fire_projectile(from, target, damage, config["projectile"], config["splash"], Unit.Team.PLAYER, kind == Kind.MAGE)
	Audio.play(config["sound"], 0.8 if kind == Kind.BALLISTA else 1.2, -8.0, 0.1)
	_cooldown = 1.0 / maxf(0.1, GameState.stat(Stats.TOWER_SPEED) * config["rate"])


func get_aim_point() -> Vector2:
	return position + Vector2(0, -16)


## Rises out of the ground when built or upgraded.
func play_build() -> void:
	_sprite.scale = Vector2(1.3, 0.1)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_kind() -> void:
	var texture: Texture2D = KINDS[kind]["texture"]
	_sprite.texture = texture
	_sprite.offset = Vector2(0, -texture.get_height() * 0.5)
