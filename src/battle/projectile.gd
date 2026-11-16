class_name Projectile
extends Node2D
## Arrow, bolt or magic orb. Homes in on its target and deals damage on impact.

const SPEED := 220.0

var battlefield: Battlefield
## Unit or Castle.
var target
var damage := 1.0
var splash_radius := 0.0
var team: Unit.Team = Unit.Team.PLAYER
var _texture: Texture2D
var _target_point := Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite2D


func setup(field: Battlefield, from: Vector2, p_target, p_damage: float, texture: Texture2D, splash: float, p_team: Unit.Team) -> void:
	battlefield = field
	position = from
	target = p_target
	damage = p_damage
	_texture = texture
	splash_radius = splash
	team = p_team
	_target_point = p_target.get_aim_point()


func _ready() -> void:
	_sprite.texture = _texture
	rotation = (_target_point - position).angle()


func _physics_process(delta: float) -> void:
	if _target_alive():
		_target_point = target.get_aim_point()
	var offset := _target_point - position
	var step := SPEED * delta
	if offset.length() <= step:
		_impact()
		return
	rotation = offset.angle()
	position += offset.normalized() * step


func _target_alive() -> bool:
	return is_instance_valid(target) and not target.is_dead


func _impact() -> void:
	var hit = target if _target_alive() else null
	if hit != null:
		hit.take_damage(damage)
	if splash_radius > 0.0:
		battlefield.damage_area(_target_point, splash_radius, damage, team, hit)
	queue_free()
