class_name Unit
extends Node2D
## A troop or an evil spirit on the battlefield. Stats come from UnitData,
## targeting and projectiles from Battlefield.
##
## Troops hold their formation spot and step out to fight spirits that come
## close. Spirits drift towards the castle and fight whatever blocks them.

signal died(unit: Unit)

enum Team { PLAYER, ENEMY }

const GROUP_TROOPS := &"troops"
const GROUP_ENEMIES := &"enemies"
## Spirits glow so they stay visible in the night tint.
const ENEMY_GLOW := Color(1.6, 1.6, 1.8)
const HP_BAR_WIDTH := 12.0
const RISE_DURATION := 0.6

var data: UnitData
var team: Team = Team.PLAYER
var battlefield: Battlefield
var max_hp := 1.0
var hp := 1.0
var damage := 1.0
var move_speed := 1.0
## Stat multiplier from symbol level / upgrades (troops) or night (spirits).
var power := 1.0
## Formation spot for troops.
var home_position := Vector2.ZERO
var is_dead := false

var _cooldown := 0.0
var _anim_time := 0.0
var _is_moving := false
var _height := 16.0
var _base_modulate := Color.WHITE
var _rise_time := 0.0
## Where along the castle wall this spirit attacks (-1 = left end, 1 = right end).
var _wall_offset := randf_range(-0.85, 0.85)

@onready var _sprite: Sprite2D = $Sprite2D


## Call before adding to the tree. `power` multiplies hp and damage.
func setup(unit_data: UnitData, unit_team: Team, power_multiplier: float, field: Battlefield) -> void:
	data = unit_data
	team = unit_team
	power = power_multiplier
	battlefield = field
	max_hp = data.max_hp * power_multiplier
	hp = max_hp
	damage = data.damage * power_multiplier
	move_speed = data.move_speed * randf_range(0.9, 1.1)
	if team == Team.ENEMY:
		move_speed *= 1.0 - GameState.stat(Stats.ENEMY_SLOW)
	else:
		move_speed *= 1.0 + GameState.stat(Stats.TROOP_SPEED)
	add_to_group(GROUP_TROOPS if team == Team.PLAYER else GROUP_ENEMIES)


func _ready() -> void:
	_anim_time = randf() * TAU
	_sprite.texture = data.texture
	_sprite.scale = Vector2.ONE * data.sprite_scale
	_sprite.offset = Vector2(0, -data.texture.get_height() * 0.5)
	_height = data.texture.get_height() * data.sprite_scale
	if team == Team.ENEMY:
		_base_modulate = ENEMY_GLOW
	_sprite.modulate = _base_modulate
	refresh_morale()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _rise_time > 0.0:
		_rise_time -= delta
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_is_moving = false
	if team == Team.PLAYER:
		_think_troop(delta)
	else:
		_think_enemy(delta)
	_animate(delta)


func take_damage(amount: float) -> void:
	if is_dead:
		return
	if data.armor > 0.0:
		amount = maxf(amount * 0.15, amount - data.armor)
	hp -= amount
	queue_redraw()
	_flash()
	if hp <= 0.0:
		_die()


func heal_full() -> void:
	hp = max_hp
	queue_redraw()


## Where projectiles should aim.
func get_aim_point() -> Vector2:
	return position + Vector2(0, -_height * 0.5)


func _think_troop(delta: float) -> void:
	if not battlefield.is_night:
		_move_to(home_position, delta)
		return
	if data.is_healer():
		_think_healer(delta)
		return
	# Melee troops guard the area around their spot; ranged troops shoot from it.
	var search_from := position if data.is_ranged() else home_position
	var aggro := data.aggro_range * battlefield.troop_aggro_multiplier()
	var target := battlefield.nearest_unit(search_from, aggro, Team.ENEMY, data.is_ranged())
	var charging := false
	if target == null:
		# Nothing close: go after a boss, or a ranged spirit that can hit us.
		target = battlefield.priority_target(self)
		charging = target != null
	if target == null:
		_move_to(home_position, delta)
	elif position.distance_to(target.position) <= data.attack_range:
		_attack(target)
	elif data.is_ranged() and not charging:
		_move_to(home_position, delta)
	else:
		_move_to(target.position, delta)


## Clerics stay near their spot and heal the most wounded troop in reach.
func _think_healer(delta: float) -> void:
	var patient := battlefield.most_wounded_troop(position, data.attack_range)
	if patient == null or _cooldown > 0.0:
		_move_to(home_position, delta)
		return
	_cooldown = data.attack_cooldown
	_face(patient.position.x - position.x)
	patient.heal(data.heal_amount * power)
	Fx.burst(battlefield.effects_layer(), patient.get_aim_point(), Color("#a0ff90"), 8, 30.0, null, 0.5, -40.0)
	if data.attack_sound != &"":
		Audio.play(data.attack_sound, 1.3, -10.0, 0.1)


## Unpaid troops (low morale) look washed out and hit softer (see _attack).
func refresh_morale() -> void:
	if team != Team.PLAYER or not is_node_ready():
		return
	var gray := 1.0 - battlefield.morale
	_base_modulate = Color(1.0 - gray * 0.6, 1.0 - gray * 0.6, 1.0 - gray * 0.4)
	_sprite.modulate = _base_modulate


func heal(amount: float) -> void:
	if is_dead:
		return
	hp = minf(max_hp, hp + amount)
	queue_redraw()


func _think_enemy(delta: float) -> void:
	# Flying spirits ignore troops and go straight for the castle.
	var target: Unit = null if data.flying else battlefield.nearest_unit(position, data.aggro_range, Team.PLAYER)
	if target != null:
		if position.distance_to(target.position) <= data.attack_range:
			_attack(target)
		else:
			_move_to(target.position, delta)
		return
	# Head for our own spot along the castle wall and attack it once in reach.
	var castle := battlefield.castle
	if position.distance_to(castle.wall_point(position)) <= data.attack_range * 0.8 + 2.0:
		_attack(castle)
	else:
		_move_to(castle.position + Vector2(_wall_offset * castle.half_width(), 2.0), delta)


## `target` is a Unit or the Castle (anything with take_damage and get_aim_point).
func _attack(target) -> void:
	_face(target.position.x - position.x)
	if _cooldown > 0.0:
		return
	_cooldown = data.attack_cooldown
	var hit := damage * (battlefield.morale if team == Team.PLAYER else 1.0)
	if data.is_ranged():
		battlefield.fire_projectile(get_aim_point(), target, hit, data.projectile_texture, data.splash_radius, team)
	else:
		target.take_damage(hit)
	if data.attack_sound != &"":
		Audio.play(data.attack_sound, 1.0 if team == Team.PLAYER else 0.6, -8.0, 0.12)
	_lunge()


func _move_to(point: Vector2, delta: float) -> void:
	var offset := point - position
	if offset.length() < 1.0:
		return
	_is_moving = true
	_face(offset.x)
	position = position.move_toward(point, move_speed * delta)
	position = position.clamp(Battlefield.FIELD.position, Battlefield.FIELD.end)


## False while a spirit is still rising from its grave.
func is_active() -> bool:
	return _rise_time <= 0.0


## Spirit entrance: fades in and stretches up out of the ground.
func play_rise() -> void:
	_rise_time = RISE_DURATION
	modulate.a = 0.0
	_sprite.scale = Vector2(data.sprite_scale * 1.4, 0.1)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, RISE_DURATION)
	tween.tween_property(_sprite, "scale", Vector2.ONE * data.sprite_scale, RISE_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Troop sprites face right, spirit sprites face left.
func _face(direction_x: float) -> void:
	if absf(direction_x) < 0.5:
		return
	_sprite.flip_h = direction_x < 0.0 if team == Team.PLAYER else direction_x > 0.0


func _animate(delta: float) -> void:
	_anim_time += delta
	if team == Team.ENEMY:
		var lift := -10.0 if data.flying else -1.5
		_sprite.position.y = sin(_anim_time * 4.0) * 1.5 + lift  # spirits hover, flyers higher
	elif _is_moving:
		_sprite.position.y = -absf(sin(_anim_time * 12.0)) * 1.5  # walking hop
	else:
		_sprite.position.y = 0.0


func _lunge() -> void:
	var facing_right := not _sprite.flip_h if team == Team.PLAYER else _sprite.flip_h
	var tween := create_tween()
	tween.tween_property(_sprite, "position:x", 3.0 if facing_right else -3.0, 0.06)
	tween.tween_property(_sprite, "position:x", 0.0, 0.1)


func _flash() -> void:
	_sprite.modulate = Color(2.0, 0.5, 0.5)
	create_tween().tween_property(_sprite, "modulate", _base_modulate, 0.15)


func _die() -> void:
	is_dead = true
	remove_from_group(GROUP_TROOPS)
	remove_from_group(GROUP_ENEMIES)
	died.emit(self)
	if data.death_sound != &"":
		Audio.play(data.death_sound, 1.0, -6.0, 0.15)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_property(_sprite, "position:y", _sprite.position.y - 8.0, 0.4)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	if data and data.flying and not is_dead:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 5.0 * data.sprite_scale, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
	if is_dead or hp >= max_hp:
		return
	var bar := Rect2(-HP_BAR_WIDTH * 0.5, -_height - 4.0, HP_BAR_WIDTH, 2.0)
	draw_rect(bar, Color(0.1, 0.05, 0.05))
	bar.size.x *= clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(bar, Color("#58d048") if team == Team.PLAYER else Color("#e04848"))
