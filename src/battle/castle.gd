class_name Castle
extends Node2D
## The kingdom's castle at the top of the field. Its two towers fire bolts at
## night (damage and rate from Stats.TOWER_DAMAGE / TOWER_SPEED); damage taken
## is forwarded to GameState.castle_hp.
## The node origin is the bottom centre of the front wall.

const BOLT_TEXTURE := preload("res://assets/sprites/projectiles/bolt.png")
const BOLT_RANGE := 190.0
## Tower tops the bolts fly from (relative to the origin). Towers take turns.
const TOWER_TOPS: Array[Vector2] = [Vector2(-50, -54), Vector2(50, -54)]
## The wall spirits attack (relative to the origin).
const WALL_RECT := Rect2(-58, -40, 116, 40)

var battlefield: Battlefield
## Duck-typing compatibility with Unit for projectiles.
var is_dead := false
var _cooldown := 0.0
var _next_tower := 0

@onready var _sprite: Sprite2D = $Sprite2D


func _process(delta: float) -> void:
	if battlefield == null or not battlefield.is_night:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var from := position + TOWER_TOPS[_next_tower]
	var target := battlefield.nearest_unit(from, BOLT_RANGE * (1.0 + GameState.stat(Stats.TOWER_RANGE)), Unit.Team.ENEMY)
	if target != null:
		battlefield.fire_projectile(from, target, GameState.stat(Stats.TOWER_DAMAGE), BOLT_TEXTURE, 0.0, Unit.Team.PLAYER)
		Audio.play(&"bolt", 1.0, -4.0, 0.08)
		_cooldown = 1.0 / maxf(0.1, GameState.stat(Stats.TOWER_SPEED))
		_next_tower = (_next_tower + 1) % TOWER_TOPS.size()


## Closest point on the wall to `from`, in world space.
func wall_point(from: Vector2) -> Vector2:
	var rect := Rect2(position + WALL_RECT.position, WALL_RECT.size)
	return Vector2(clampf(from.x, rect.position.x, rect.end.x), clampf(from.y, rect.position.y, rect.end.y))


func half_width() -> float:
	return WALL_RECT.size.x * 0.5


func get_aim_point() -> Vector2:
	return position + Vector2(0, -24)


func take_damage(amount: float) -> void:
	GameState.damage_castle(amount)
	Audio.play(&"castle_hit", 1.0, -2.0, 0.1)
	if battlefield:
		battlefield.shake(2.0, 0.15)
	_sprite.modulate = Color(1.8, 0.6, 0.6)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)
