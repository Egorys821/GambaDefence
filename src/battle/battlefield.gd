class_name Battlefield
extends Node2D
## Top-down field with the castle at the top centre. Troops summoned during the
## day line up in front of the gate; at night spirits rise from the graveyards
## and march up. Each castle has its own BattleLayout (terrain, graveyards,
## tower slots, rally points); `nav` paths walkers around its terrain.
## Also owns the camera: zoomed on the castle by day, the whole battle by night.

signal night_cleared
## Emitted whenever the number of spirits or defenders changes.
signal status_changed(enemies_left: int, defenders: int)
## Troop morale changed (1.0 = fully paid, lower = weaker troops).
signal morale_changed(morale: float)

const UNIT_SCENE := preload("res://src/battle/unit.tscn")
const PROJECTILE_SCENE := preload("res://src/battle/projectile.tscn")
const WATCHTOWER_SCENE := preload("res://src/battle/watchtower.tscn")

## Area units can move in (spirits start a little below the graveyard).
const FIELD := Rect2(6, 40, 628, 350)
const GATE_POSITION := Vector2(320, 108)

## Formation in front of the castle: ranged rows first, melee rows in front of them.
const FORMATION_TOP := 116.0
const FORMATION_PER_ROW := 14
## Rows widen for big armies so the formation stays out of the graveyard.
const FORMATION_MAX_PER_ROW := 34
const FORMATION_MAX_ROWS := 6
const FORMATION_SPACING := Vector2(13, 11)
const FORMATION_GAP := 2.0

## Camera framing. By day the camera frames the castle and the whole army in
## the screen area between the side panels, above the slot machine, zooming
## out as the army grows.
const DAY_VIEW_RECT := Rect2(150, 16, 340, 140)
## World y of the top of the castle banner.
const DAY_VIEW_TOP := 18.0
const DAY_MAX_ZOOM := 1.5
const DAY_MIN_ZOOM := 0.7
const NIGHT_ZOOM := 1.0
const NIGHT_CAMERA_POSITION := Vector2(320, 180)
const VIEW_TRANSITION_TIME := 1.4
## Seconds after nightfall before the first spirit rises (camera is zooming out).
const FIRST_SPAWN_DELAY := 2.2

const DAY_TINT := Color.WHITE
const NIGHT_TINT := Color(0.36, 0.38, 0.7)
const GOLD_COLOR := Color("#f8d038")
## Damage multiplier when no upkeep at all could be paid.
const MIN_MORALE := 0.5
## While a boss is on the field, troops spot spirits this much farther away
## (they still fight the nearest one rather than all rushing the boss).
const BOSS_AGGRO_MULTIPLIER := 2.5

var is_night := false
## The terrain this castle is fought on, and its walking grid.
var layout: BattleLayout
var nav: BattleNav
## Troop damage multiplier from paying upkeep (see pay_upkeep).
var morale := 1.0
var _spawn_queue: Array[UnitData] = []
var _spawn_timer := 0.0
var _spawn_interval := 1.0
var _enemy_power := 1.0
var _enemies_alive := 0
var _bosses_alive := 0
var _shake_strength := 0.0
var _shake_time := 0.0
var _watchtowers: Array[Watchtower] = []
var _camera_tween: Tween

@onready var castle: Castle = $Units/Castle
@onready var camera: Camera2D = $Camera2D
@onready var _units: Node2D = $Units
@onready var _projectiles: Node2D = $Projectiles
@onready var _terrain: LayoutView = $Terrain
@onready var _effects: Node2D = $Effects
@onready var _tint: CanvasModulate = $NightTint
@onready var _castle_light: PointLight2D = $CastleLight
@onready var _vignette: CanvasItem = $Vignette/Overlay


func _ready() -> void:
	castle.battlefield = self
	_tint.color = DAY_TINT
	_castle_light.energy = 0.0
	_vignette.modulate.a = 0.0
	_set_view(false, true)
	_dress(GameState.castle)  # the menu shows the last castle played
	GameState.upgrades_changed.connect(sync_watchtowers)
	sync_watchtowers()


## Wide, calm view of the whole field (behind the main menu).
func show_overview() -> void:
	camera.zoom = Vector2.ONE * NIGHT_ZOOM
	camera.position = NIGHT_CAMERA_POSITION


## Dresses the field for a castle: its layout and ground tint.
func apply_castle(castle: CastleData) -> void:
	_dress(castle)
	_frame_day_camera()


func _dress(castle: CastleData) -> void:
	var tint := castle.ground_tint if castle else Color.WHITE
	$Background.modulate = tint
	$Surround.modulate = tint
	_terrain.modulate = tint
	apply_layout(castle.layout if castle else null)


## Swaps the terrain (null = open field). Rebuilds the walking grid, redraws
## the field and moves watchtowers and the formation onto open ground.
func apply_layout(new_layout: BattleLayout) -> void:
	if new_layout == null:
		new_layout = BattleLayout.new()
	layout = new_layout
	nav = BattleNav.new(layout)
	_terrain.show_layout(layout, nav, GATE_POSITION)
	for i in _watchtowers.size():
		_watchtowers[i].position = _tower_slot(i)
	if not get_troops().is_empty():
		_reform()


## Named spots troops could be sent to (see RallyPoint). Not used yet.
func rally_points() -> Array[RallyPoint]:
	return layout.rally_points


func _tower_slots() -> Array[Vector2]:
	return layout.get_tower_slots() if layout else BattleLayout.DEFAULT_TOWER_SLOTS


func _tower_slot(index: int) -> Vector2:
	var slot := _tower_slots()[index]
	return nav.nearest_free(slot) if nav else slot


## Builds or removes watchtowers to match Stats.EXTRA_TOWERS.
func sync_watchtowers() -> void:
	var wanted := mini(GameState.stat_int(Stats.EXTRA_TOWERS), _tower_slots().size())
	while _watchtowers.size() > wanted:
		_watchtowers.pop_back().queue_free()
	while _watchtowers.size() < wanted:
		var tower: Watchtower = WATCHTOWER_SCENE.instantiate()
		tower.battlefield = self
		tower.position = _tower_slot(_watchtowers.size())
		_units.add_child(tower)
		_watchtowers.append(tower)
		if is_inside_tree() and get_tree().get_frame() > 1:
			tower.play_build()
			Fx.burst(_effects, tower.position, Color("#c8b890"), 16, 50.0)
			Audio.play(&"castle_hit", 1.4, -6.0)
	# Upgrades: the first towers become Ballistae, the next ones Mage Towers.
	var ballistae := GameState.stat_int(Stats.BALLISTA_TOWERS)
	var mages := GameState.stat_int(Stats.MAGE_TOWERS)
	for i in _watchtowers.size():
		var kind := Watchtower.Kind.ARCHER
		if i < ballistae:
			kind = Watchtower.Kind.BALLISTA
		elif i < ballistae + mages:
			kind = Watchtower.Kind.MAGE
		if _watchtowers[i].kind != kind:
			_watchtowers[i].set_kind(kind)
			Fx.burst(_effects, _watchtowers[i].position + Vector2(0, -16), Color("#c060ff") if kind == Watchtower.Kind.MAGE else Color("#e8c890"), 14, 50.0)


func _process(delta: float) -> void:
	_update_shake(delta)
	if not is_night:
		return
	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_enemy(_spawn_queue.pop_front())
			_spawn_timer = _spawn_interval
	elif _enemies_alive <= 0:
		_end_night()


# --- Troops -----------------------------------------------------------------

func spawn_troops(data: UnitData, count: int, power: float) -> void:
	for i in count:
		var troop: Unit = UNIT_SCENE.instantiate()
		troop.setup(data, Unit.Team.PLAYER, power, self)
		troop.position = GATE_POSITION + Vector2(randf_range(-6, 6), randf_range(-2, 2))
		troop.died.connect(_on_troop_died)
		_units.add_child(troop)
	Fx.burst(_effects, GATE_POSITION + Vector2(0, -4), Color("#e8d8b0"), 14, 50.0)
	FloatingText.spawn(_effects, "+%d %s" % [count, data.display_name], GATE_POSITION + Vector2(0, -50), Color("#80d0ff"))
	Audio.play(&"spawn", 1.0, 0.0, 0.05)
	_reform()
	_emit_status()


func get_troops() -> Array[Unit]:
	var troops: Array[Unit] = []
	for node in get_tree().get_nodes_in_group(Unit.GROUP_TROOPS):
		troops.append(node as Unit)
	return troops


## Reassigns formation spots so the army stays tidy after spawns and deaths.
func _reform() -> void:
	var melee: Array[Unit] = []
	var ranged: Array[Unit] = []
	for troop in get_troops():
		if troop.data.is_ranged():
			ranged.append(troop)
		else:
			melee.append(troop)
	var next_row_y := _assign_formation(ranged, FORMATION_TOP)
	if ranged.is_empty():
		next_row_y = FORMATION_TOP + FORMATION_SPACING.y
	_assign_formation(melee, next_row_y + FORMATION_GAP)
	if not is_night:
		_frame_day_camera()


## Lays troops out in centred rows starting at `top_y`. Returns the y below the last row.
func _assign_formation(troops: Array[Unit], top_y: float) -> float:
	var per_row := clampi(ceili(float(troops.size()) / FORMATION_MAX_ROWS), FORMATION_PER_ROW, FORMATION_MAX_PER_ROW)
	var rows := ceili(float(troops.size()) / per_row)
	for i in troops.size():
		var row := floori(float(i) / per_row)
		var column := i % per_row
		var in_row := mini(per_row, troops.size() - row * per_row)
		var x := GATE_POSITION.x + (column - (in_row - 1) * 0.5) * FORMATION_SPACING.x
		x += (row % 2) * FORMATION_SPACING.x * 0.5
		var spot := Vector2(x, top_y + row * FORMATION_SPACING.y)
		troops[i].home_position = nav.nearest_free(spot) if nav else spot
	return top_y + rows * FORMATION_SPACING.y


## Gold the army will cost at the next dawn. The most expensive troops fill
## the free slots (Stats.FREE_TROOPS); everyone else pays their upkeep.
func upkeep_cost() -> int:
	var total := 0.0
	for troop in _paying_troops():
		total += troop.data.upkeep
	return ceili(total * (1.0 - GameState.stat(Stats.UPKEEP_DISCOUNT)))


## Charges the dawn upkeep with whatever gold there is. If it can't all be
## paid, morale drops: troops deal less damage until the next dawn.
## Returns {"paid": gold spent, "cost": full bill}.
func pay_upkeep() -> Dictionary:
	var cost := upkeep_cost()
	var paid := mini(GameState.gold, cost)
	GameState.spend_gold(paid)
	var share := 1.0 if cost == 0 else float(paid) / cost
	set_morale(lerpf(min_morale(), 1.0, share))
	return {"paid": paid, "cost": cost}


## Lowest morale unpaid troops can fall to (Time Forge: Discipline raises it).
func min_morale() -> float:
	return minf(1.0, MIN_MORALE + GameState.stat(Stats.MORALE_FLOOR))


func set_morale(value: float) -> void:
	morale = clampf(value, min_morale(), 1.0)
	for troop in get_troops():
		troop.refresh_morale()
	morale_changed.emit(morale)


## Troops outside the free slots, cheapest first.
func _paying_troops() -> Array[Unit]:
	var troops := get_troops()
	troops.sort_custom(func(a: Unit, b: Unit) -> bool: return a.data.upkeep > b.data.upkeep)
	var free := GameState.stat_int(Stats.FREE_TROOPS)
	var paying: Array[Unit] = troops.slice(mini(free, troops.size()))
	paying.reverse()
	return paying


func _on_troop_died(_troop: Unit) -> void:
	_reform()
	_emit_status()


# --- Night ------------------------------------------------------------------

func start_night(night: int) -> void:
	_spawn_queue = WaveGenerator.build(night)
	GameState.clear_curse_threat()
	_spawn_interval = WaveGenerator.spawn_interval(night)
	_enemy_power = WaveGenerator.enemy_power(night)
	_spawn_timer = FIRST_SPAWN_DELAY
	_enemies_alive = 0
	_bosses_alive = 0
	is_night = true
	_set_view(true)
	_emit_status()


## Freezes the battle (used when the castle falls).
func stop_battle() -> void:
	is_night = false
	_spawn_queue.clear()
	_units.process_mode = Node.PROCESS_MODE_DISABLED
	_projectiles.process_mode = Node.PROCESS_MODE_DISABLED


func _end_night() -> void:
	is_night = false
	for troop in get_troops():
		troop.heal_full()
	for projectile in _projectiles.get_children():
		projectile.queue_free()
	_set_view(false)
	night_cleared.emit()


func _spawn_enemy(data: UnitData) -> void:
	var enemy: Unit = UNIT_SCENE.instantiate()
	enemy.setup(data, Unit.Team.ENEMY, _enemy_power, self)
	enemy.position = _spawn_point()
	enemy.died.connect(_on_enemy_died)
	if data.is_boss:
		_bosses_alive += 1
	_units.add_child(enemy)
	enemy.play_rise()
	_enemies_alive += 1
	_emit_status()


## A random open spot in one of the layout's graveyards (bigger ones more often).
func _spawn_point() -> Vector2:
	var zones := layout.get_spawn_zones()
	var total := 0.0
	for zone in zones:
		total += zone.get_area()
	var roll := randf() * total
	var zone := zones[0]
	for each in zones:
		zone = each
		roll -= each.get_area()
		if roll <= 0.0:
			break
	var point := Vector2(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y, zone.end.y))
	return nav.nearest_free(point)


func _on_enemy_died(enemy: Unit) -> void:
	_enemies_alive -= 1
	if enemy.data.is_boss:
		_bosses_alive -= 1
	GameState.kills += 1
	Fx.burst(_effects, enemy.get_aim_point(), Color("#d0f4ec"), 10, 40.0, null, 0.6, -30.0)
	var reward := enemy.data.gold_reward + GameState.stat_int(Stats.KILL_BOUNTY)
	if reward > 0:
		GameState.add_gold(reward)
		FloatingText.spawn(_effects, "+%d" % reward, enemy.get_aim_point(), GOLD_COLOR, 7)
	_emit_status()


func _emit_status() -> void:
	status_changed.emit(_spawn_queue.size() + _enemies_alive, get_tree().get_node_count_in_group(Unit.GROUP_TROOPS))


# --- Camera and atmosphere --------------------------------------------------

## Zoom that fits the castle plus the whole formation into DAY_VIEW_RECT.
func _day_zoom() -> float:
	var bottom := castle.position.y + 10.0
	var half_width := castle.half_width() + 8.0
	for troop in get_troops():
		bottom = maxf(bottom, troop.home_position.y + 3.0)
		half_width = maxf(half_width, absf(troop.home_position.x - GATE_POSITION.x) + 9.0)
	var fit := minf(DAY_VIEW_RECT.size.y / (bottom - DAY_VIEW_TOP), DAY_VIEW_RECT.size.x / (half_width * 2.0))
	return clampf(fit, DAY_MIN_ZOOM, DAY_MAX_ZOOM)


func _set_view(night: bool, instant: bool = false) -> void:
	var zoom_value := NIGHT_ZOOM if night else _day_zoom()
	var zoom := Vector2.ONE * zoom_value
	var target := NIGHT_CAMERA_POSITION
	if not night:
		# Put the castle top at the top of the day view rect.
		var half_screen := get_viewport_rect().size.y * 0.5
		target = Vector2(GATE_POSITION.x, DAY_VIEW_TOP + (half_screen - DAY_VIEW_RECT.position.y) / zoom_value)
	if instant:
		camera.zoom = zoom
		camera.position = target
		return
	if _camera_tween:
		_camera_tween.kill()
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "zoom", zoom, VIEW_TRANSITION_TIME)
	tween.tween_property(camera, "position", target, VIEW_TRANSITION_TIME)
	tween.tween_property(_tint, "color", NIGHT_TINT if night else DAY_TINT, VIEW_TRANSITION_TIME)
	tween.tween_property(_castle_light, "energy", 1.1 if night else 0.0, VIEW_TRANSITION_TIME)
	tween.tween_property(_vignette, "modulate:a", 1.0 if night else 0.0, VIEW_TRANSITION_TIME)


## Re-frames the day view when the army changes size (camera only).
func _frame_day_camera() -> void:
	var zoom_value := _day_zoom()
	var half_screen := get_viewport_rect().size.y * 0.5
	var target := Vector2(GATE_POSITION.x, DAY_VIEW_TOP + (half_screen - DAY_VIEW_RECT.position.y) / zoom_value)
	if _camera_tween:
		_camera_tween.kill()
	_camera_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(camera, "zoom", Vector2.ONE * zoom_value, 0.6)
	_camera_tween.tween_property(camera, "position", target, 0.6)


func shake(strength: float, duration: float = 0.25) -> void:
	_shake_strength = maxf(strength, _shake_strength if _shake_time > 0.0 else 0.0)
	_shake_time = maxf(_shake_time, duration)


func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_shake_time -= delta
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength * clampf(_shake_time * 4.0, 0.0, 1.0)


## Converts a world position to screen (UI) coordinates, e.g. for flying icons.
func world_to_screen(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position


func gate_screen_position() -> Vector2:
	return world_to_screen(GATE_POSITION + Vector2(0, -10))


func castle_screen_position() -> Vector2:
	return world_to_screen(castle.get_aim_point())


# --- Combat helpers used by units, the castle and projectiles ---------------

## `can_hit_flying` = false skips flying units (melee attackers can't reach them).
func nearest_unit(from: Vector2, max_distance: float, team: Unit.Team, can_hit_flying: bool = true) -> Unit:
	var group := Unit.GROUP_TROOPS if team == Unit.Team.PLAYER else Unit.GROUP_ENEMIES
	var best: Unit = null
	var best_distance := max_distance
	for node in get_tree().get_nodes_in_group(group):
		var unit := node as Unit
		if unit.is_dead or not unit.is_active() or (unit.data.flying and not can_hit_flying):
			continue
		var distance := from.distance_to(unit.position)
		if distance <= best_distance:
			best = unit
			best_distance = distance
	return best


## Multiplier on troops' aggro range (bigger while a boss is on the field).
func troop_aggro_multiplier() -> float:
	return BOSS_AGGRO_MULTIPLIER if _bosses_alive > 0 else 1.0


## A spirit worth leaving the formation for: a ranged spirit close enough to
## shoot this troop. Nearest first.
func priority_target(troop: Unit) -> Unit:
	var best: Unit = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Unit.GROUP_ENEMIES):
		var enemy := node as Unit
		if enemy.is_dead or not enemy.is_active():
			continue
		if enemy.data.flying and not troop.data.is_ranged():
			continue
		var distance := troop.position.distance_to(enemy.position)
		var threat := enemy.data.is_ranged() and distance <= enemy.data.attack_range + 24.0
		if threat and distance < best_distance:
			best = enemy
			best_distance = distance
	return best


## Troop missing the most HP within `max_distance`, or null if all are healthy.
func most_wounded_troop(from: Vector2, max_distance: float) -> Unit:
	var best: Unit = null
	var most_missing := 0.5
	for node in get_tree().get_nodes_in_group(Unit.GROUP_TROOPS):
		var troop := node as Unit
		var missing := troop.max_hp - troop.hp
		if not troop.is_dead and missing > most_missing and from.distance_to(troop.position) <= max_distance:
			best = troop
			most_missing = missing
	return best


func effects_layer() -> Node2D:
	return _effects


func fire_projectile(from: Vector2, target, damage: float, texture: Texture2D, splash: float, team: Unit.Team) -> void:
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.setup(self, from, target, damage, texture, splash, team)
	_projectiles.add_child(projectile)


## Damages every opponent of `attacker_team` within `radius` of `point`.
func damage_area(point: Vector2, radius: float, damage: float, attacker_team: Unit.Team, exclude = null) -> void:
	var group := Unit.GROUP_ENEMIES if attacker_team == Unit.Team.PLAYER else Unit.GROUP_TROOPS
	for node in get_tree().get_nodes_in_group(group):
		var unit := node as Unit
		if unit == exclude or unit.is_dead:
			continue
		if unit.get_aim_point().distance_to(point) <= radius:
			unit.take_damage(damage)
	var burst := BurstEffect.new()
	burst.position = point
	burst.radius = radius
	burst.color = Color("#60d8f8") if attacker_team == Unit.Team.PLAYER else Color("#c060ff")
	_effects.add_child(burst)
	Audio.play(&"burst", 1.0, -6.0, 0.1)
