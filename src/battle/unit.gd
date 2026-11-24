class_name Unit
extends Node2D
## A troop or an evil spirit on the battlefield. Stats come from UnitData,
## targeting and projectiles from Battlefield.
##
## Troops hold their formation spot and step out to fight spirits that come
## close. Spirits drift towards the castle and fight whatever blocks them.
## Walkers path around the layout's terrain (Battlefield.nav); flyers don't.

signal died(unit: Unit)

enum Team { PLAYER, ENEMY }

const GROUP_TROOPS := &"troops"
const GROUP_ENEMIES := &"enemies"
## Spirits glow so they stay visible in the night tint.
const ENEMY_GLOW := Color(1.6, 1.6, 1.8)
const HP_BAR_WIDTH := 12.0
const RISE_DURATION := 0.6
## A walker re-plans its path when its goal moves this far (pixels)...
const REPLAN_DISTANCE := 10.0
## ...or when it hasn't got anywhere for this long (seconds).
const STUCK_TIME := 0.6
## How long a "can I walk straight at this target?" answer is trusted.
const REACH_CHECK_TIME := 0.4

## Bosses are much tougher than their base stats...
const BOSS_HP_MULTIPLIER := 2.2
const BOSS_DAMAGE_MULTIPLIER := 1.5
## ...call escorts from the castle's roster every so often...
const BOSS_SUMMON_INTERVAL := 7.0
const BOSS_SUMMON_COUNT := 2
## ...and enrage below this share of their HP: faster attacks and steps.
const BOSS_ENRAGE_AT := 0.5
const ENRAGE_SPEED := 1.35
const ENRAGE_ATTACK_RATE := 1.6
const ENRAGE_TINT := Color(2.0, 0.8, 0.8)
## Assassins wait this long after rising before blinking behind the army.
const ASSASSIN_BLINK_DELAY := 1.2
## How far an assassin looks for back-row prey once it has blinked.
const ASSASSIN_HUNT_RANGE := 160.0
## Burrowers come up this far behind the army's rearmost troop (towards the castle)...
const SURFACE_BEHIND := 14.0
## ...and give up digging after this long, surfacing wherever they are.
const MAX_BURROW_TIME := 18.0
const DIRT := Color("#7a5230")
const DIRT_DARK := Color("#4a2e18")

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
## Path to the current goal (BattleNav waypoints; the last one is the goal).
var _path := PackedVector2Array()
var _path_goal := Vector2.INF
var _stuck_time := 0.0
var _reach_target: Unit
var _reach_ok := true
var _reach_timer := 0.0
var _wave_timer := 0.0
var _summon_timer := BOSS_SUMMON_INTERVAL
var _enraged := false
var _blink_timer := ASSASSIN_BLINK_DELAY
var _has_blinked := false
## Burrower underground: invisible, can't be targeted or hurt (see is_active).
var _burrowed := false
var _surfaced := false
var _burrow_time := 0.0
var _dust_timer := 0.0

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
	if team == Team.ENEMY and data.is_boss:
		max_hp *= BOSS_HP_MULTIPLIER
		hp = max_hp
		damage *= BOSS_DAMAGE_MULTIPLIER
	_wave_timer = data.wave_cooldown * randf_range(0.5, 1.0)
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
	_reach_timer -= delta
	_is_moving = false
	if _burrowed:
		_think_burrowed(delta)
		return
	if team == Team.PLAYER:
		_think_troop(delta)
	else:
		_update_enemy_abilities(delta)
		if not is_dead:
			_think_enemy(delta)
	_animate(delta)


## `magic` damage is reduced by magic_resist instead of armor.
func take_damage(amount: float, magic: bool = false) -> void:
	if is_dead or _burrowed:
		return
	if magic and data.magic_resist > 0.0:
		amount *= 1.0 - data.magic_resist
	elif data.armor > 0.0:
		amount = maxf(amount * 0.15, amount - data.armor)
	hp -= amount
	queue_redraw()
	_flash()
	if hp <= 0.0:
		_die()
	elif data.is_boss and team == Team.ENEMY and not _enraged and hp <= max_hp * BOSS_ENRAGE_AT:
		_enrage()


## New stat multiplier (e.g. its symbol was upgraded): HP and damage scale
## with it, keeping the same share of HP.
func set_power(new_power: float) -> void:
	if is_dead or new_power <= 0.0 or is_equal_approx(new_power, power):
		return
	var ratio := new_power / power
	power = new_power
	max_hp *= ratio
	hp *= ratio
	damage *= ratio
	queue_redraw()


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
	if target != null and not _can_engage(target):
		target = null  # across a river or behind rocks: hold the line instead
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
	if team != Team.PLAYER or not is_node_ready() or battlefield == null:
		return
	var gray := 1.0 - battlefield.morale
	_base_modulate = Color(1.0 - gray * 0.6, 1.0 - gray * 0.6, 1.0 - gray * 0.4)
	_sprite.modulate = _base_modulate


func heal(amount: float) -> void:
	if is_dead:
		return
	hp = minf(max_hp, hp + amount)
	queue_redraw()


## Shockwaves, assassin blinks and boss summons (timers run while fighting).
func _update_enemy_abilities(delta: float) -> void:
	if data.has_shockwave():
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_wave_timer = data.wave_cooldown
			_shockwave()
	if data.assassin and not _has_blinked:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_behind_army()
	if data.is_boss:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = BOSS_SUMMON_INTERVAL * (0.6 if _enraged else 1.0)
			battlefield.summon_escorts(self, BOSS_SUMMON_COUNT)


## Ring that hits every troop (and the castle wall) within wave_radius.
func _shockwave() -> void:
	var hit_damage := data.wave_damage * power
	var hit_any := false
	for troop in battlefield.get_troops():
		if not troop.is_dead and troop.position.distance_to(position) <= data.wave_radius:
			troop.take_damage(hit_damage)
			hit_any = true
	var castle := battlefield.castle
	if position.distance_to(castle.wall_point(position)) <= data.wave_radius:
		castle.take_damage(hit_damage)
		hit_any = true
	var ring := BurstEffect.new()
	ring.position = get_aim_point()
	ring.radius = data.wave_radius
	ring.color = Color("#ff60c0")
	battlefield.effects_layer().add_child(ring)
	if hit_any:
		Audio.play(&"burst", 0.55, -4.0, 0.1)
	_lunge()


## Vanishes and reappears just behind the back row (ranged troops and
## clerics stand closest to the castle). No troops = no blink.
func _blink_behind_army() -> void:
	_has_blinked = true
	var prey := battlefield.back_row_troop(position)
	if prey == null:
		return
	Fx.burst(battlefield.effects_layer(), get_aim_point(), Color("#401020"), 14, 40.0)
	var spot := prey.position + Vector2(randf_range(-8.0, 8.0), -randf_range(6.0, 10.0))
	spot = spot.clamp(Battlefield.FIELD.position, Battlefield.FIELD.end)
	position = battlefield.nav.nearest_free(spot) if battlefield.nav else spot
	_path = PackedVector2Array()
	_path_goal = Vector2.INF
	Fx.burst(battlefield.effects_layer(), get_aim_point(), Color("#ff3050"), 14, 50.0)
	Audio.play(&"magic", 0.5, -6.0, 0.1)


func _enrage() -> void:
	_enraged = true
	move_speed *= ENRAGE_SPEED
	_base_modulate = ENRAGE_TINT
	_sprite.modulate = _base_modulate
	_summon_timer = minf(_summon_timer, 1.0)
	battlefield.shake(4.0, 0.4)
	FloatingText.spawn(battlefield.effects_layer(), "ENRAGED!", get_aim_point() + Vector2(0, -12), Color("#ff5050"), 9)
	Fx.burst(battlefield.effects_layer(), get_aim_point(), Color("#ff4040"), 24, 70.0)


func _think_enemy(delta: float) -> void:
	# Assassins that got behind the army (and burrowers that dug up behind it)
	# hunt its back row first.
	if (data.assassin and _has_blinked) or (data.burrower and _surfaced):
		var prey := battlefield.back_row_troop(position, ASSASSIN_HUNT_RANGE)
		if prey != null:
			if position.distance_to(prey.position) <= data.attack_range:
				_attack(prey)
			else:
				_move_to(prey.position, delta)
			return
	# Siege engines lob shots into the middle of the army (melee first).
	if data.siege:
		var aim := battlefield.siege_target(position, data.attack_range)
		if aim != null:
			_attack(aim)
			return
	# Flying spirits ignore troops and go straight for the castle.
	var target: Unit = null if data.flying else battlefield.nearest_unit(position, data.aggro_range, Team.PLAYER)
	if target != null and not _can_engage(target):
		target = null  # can't get at it from here: keep marching on the castle
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
	_cooldown = data.attack_cooldown / (ENRAGE_ATTACK_RATE if _enraged else 1.0)
	var hit := damage * (battlefield.morale if team == Team.PLAYER else 1.0)
	if data.is_ranged():
		battlefield.fire_projectile(get_aim_point(), target, hit, data.projectile_texture, data.splash_radius, team, data.magic_damage)
	else:
		target.take_damage(hit)
	if data.attack_sound != &"":
		Audio.play(data.attack_sound, 1.0 if team == Team.PLAYER else 0.6, -8.0, 0.12)
	_lunge()


func _move_to(point: Vector2, delta: float) -> void:
	var offset := point - position
	if offset.length() < 1.0:
		_stuck_time = 0.0
		return
	var step_to := _steer(point)
	_is_moving = true
	_face(step_to.x - position.x)
	var next := position.move_toward(step_to, move_speed * delta)
	next = next.clamp(Battlefield.FIELD.position, Battlefield.FIELD.end)
	if not data.flying:
		next = _slide(next)
	if next.distance_squared_to(position) < 0.0001:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	position = next


## Next point to walk towards on the way to `goal`: the goal itself on open
## ground or for flyers, otherwise the next waypoint around the terrain.
func _steer(goal: Vector2) -> Vector2:
	var nav := battlefield.nav
	if data.flying or nav == null or not nav.has_obstacles:
		return goal
	if goal.distance_to(_path_goal) > REPLAN_DISTANCE or _stuck_time > STUCK_TIME:
		_path = nav.find_path(position, goal)
		_path_goal = goal
		_stuck_time = 0.0
	while _path.size() > 1 and position.distance_to(_path[0]) < 1.5:
		_path.remove_at(0)
	if _path.size() > 1:
		return _path[0]
	return goal


## Keeps walkers out of terrain: slides along an edge instead of entering it.
func _slide(next: Vector2) -> Vector2:
	var nav := battlefield.nav
	if nav == null or not nav.is_blocked(next) or nav.is_blocked(position):
		return next
	var along_x := Vector2(next.x, position.y)
	if not nav.is_blocked(along_x):
		return along_x
	var along_y := Vector2(position.x, next.y)
	if not nav.is_blocked(along_y):
		return along_y
	return position


## Melee walkers only go for targets they can walk straight at; arrows, spells
## and flyers cross terrain freely.
func _can_engage(target: Unit) -> bool:
	if data.is_ranged() or data.flying or battlefield.nav == null or not battlefield.nav.has_obstacles:
		return true
	if target != _reach_target or _reach_timer <= 0.0:
		_reach_target = target
		_reach_timer = REACH_CHECK_TIME
		_reach_ok = battlefield.nav.is_clear_line(position, target.position)
	return _reach_ok


## False while a spirit is still rising from its grave or digging underground:
## nothing can target it then.
func is_active() -> bool:
	return _rise_time <= 0.0 and not _burrowed


func is_burrowed() -> bool:
	return _burrowed


# --- Burrowers ----------------------------------------------------------------

## Goes underground right away: only a moving mound of dirt shows where it is.
func _start_burrow() -> void:
	_burrowed = true
	_burrow_time = 0.0
	_sprite.visible = false
	queue_redraw()
	Fx.burst(battlefield.effects_layer(), position, DIRT, 10, 35.0, null, 0.6, 120.0)


## Tunnels straight (under troops, rivers and rocks) to a spot just behind
## the army's rearmost troop, then digs up. No troops: it comes up at the wall.
func _think_burrowed(delta: float) -> void:
	_burrow_time += delta
	_anim_time += delta
	var goal := _surface_spot()
	if position.distance_to(goal) <= 3.0 or _burrow_time >= MAX_BURROW_TIME:
		_surface()
		return
	_is_moving = true
	position = position.move_toward(goal, move_speed * delta).clamp(Battlefield.FIELD.position, Battlefield.FIELD.end)
	_dust_timer -= delta
	if _dust_timer <= 0.0:
		_dust_timer = 0.25
		Fx.burst(battlefield.effects_layer(), position, DIRT, 3, 18.0, null, 0.5, 80.0)
	queue_redraw()


## Just behind the troop closest to the castle (the army's back), on the castle side.
func _surface_spot() -> Vector2:
	var castle := battlefield.castle
	var rear: Unit = null
	var rear_distance := INF
	for troop in battlefield.get_troops():
		if troop.is_dead:
			continue
		var distance := troop.position.distance_to(castle.position)
		if distance < rear_distance:
			rear = troop
			rear_distance = distance
	if rear == null:
		var wall := castle.wall_point(position)
		return wall + (position - wall).normalized() * (data.attack_range * 0.6)
	var to_castle := (castle.position - rear.position).normalized()
	var spot := rear.position + to_castle * SURFACE_BEHIND + Vector2(randf_range(-4.0, 4.0), 0.0)
	return spot.clamp(Battlefield.FIELD.position, Battlefield.FIELD.end)


func _surface() -> void:
	_burrowed = false
	_surfaced = true
	if battlefield.nav and battlefield.nav.is_blocked(position):
		position = battlefield.nav.nearest_free(position)
	_path = PackedVector2Array()
	_path_goal = Vector2.INF
	_sprite.visible = true
	Fx.burst(battlefield.effects_layer(), position, DIRT, 18, 60.0, null, 0.8, 160.0)
	FloatingText.spawn(battlefield.effects_layer(), "From below!", position + Vector2(0, -22), Color("#d8a060"), 7)
	Audio.play(&"burst", 0.6, -6.0, 0.1)
	battlefield.shake(1.5, 0.15)
	_rise_time = RISE_DURATION * 0.5
	_sprite.scale = Vector2(data.sprite_scale * 1.3, 0.2)
	create_tween().tween_property(_sprite, "scale", Vector2.ONE * data.sprite_scale, RISE_DURATION * 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


## Spirit entrance: fades in and stretches up out of the ground.
## Burrowers dig straight down instead.
func play_rise() -> void:
	if data.burrower:
		_start_burrow()
		return
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
	if data.death_damage > 0.0 and battlefield:
		# Zombie Miners blow up: everyone on the other side nearby takes damage.
		battlefield.damage_area(get_aim_point(), data.death_radius, data.death_damage * power, team, self)
		Fx.burst(battlefield.effects_layer(), get_aim_point(), Color("#ff9030"), 16, 70.0)
		battlefield.shake(2.0, 0.2)
	died.emit(self)
	if data.death_sound != &"":
		Audio.play(data.death_sound, 1.0, -6.0, 0.15)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_property(_sprite, "position:y", _sprite.position.y - 8.0, 0.4)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	if _burrowed and not is_dead:
		# A mound of fresh dirt moving through the field.
		var wobble := sin(_anim_time * 10.0) * 0.6
		draw_set_transform(Vector2(0, wobble), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 9.0, DIRT_DARK)
		draw_circle(Vector2(0, -2.5), 7.0, DIRT)
		draw_circle(Vector2(-1.5, -4.5), 3.0, DIRT.lightened(0.2))
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(-5, -3 + wobble, 2, 1), DIRT_DARK)
		draw_rect(Rect2(3, -2 + wobble, 2, 1), DIRT_DARK)
		return
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
