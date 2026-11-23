class_name LayoutView
extends Node2D
## Draws a BattleLayout on the battlefield: graveyards where spirits rise,
## dirt trails along the routes they walk, then the terrain itself (lakes,
## rivers, cliffs, groves, walls, lava) and bridges, with props (peaks, trees,
## rocks) scattered on top. Everything is drawn once, from the same outlines
## the pathing grid uses, so what you see is what blocks.

const TERRAIN_DIR := "res://assets/sprites/environment/terrain/"
const TILES := {
	LayoutFeature.Kind.MOUNTAIN: preload(TERRAIN_DIR + "rock_tile.png"),
	LayoutFeature.Kind.WATER: preload(TERRAIN_DIR + "water_tile.png"),
	LayoutFeature.Kind.FOREST: preload("res://assets/sprites/environment/forest_tile.png"),
	LayoutFeature.Kind.WALL: preload(TERRAIN_DIR + "ruin_tile.png"),
	LayoutFeature.Kind.LAVA: preload(TERRAIN_DIR + "lava_tile.png"),
	LayoutFeature.Kind.BRIDGE: preload(TERRAIN_DIR + "plank_tile.png"),
}
## Border drawn around each kind (colour, width in pixels).
const BORDERS := {
	LayoutFeature.Kind.MOUNTAIN: [Color("#1a1220"), 1.5],
	LayoutFeature.Kind.WATER: [Color("#8a7448"), 2.5],
	LayoutFeature.Kind.FOREST: [Color("#1a3a20"), 1.5],
	LayoutFeature.Kind.WALL: [Color("#1a1220"), 1.0],
	LayoutFeature.Kind.LAVA: [Color("#2a1814"), 3.0],
}
const PEAKS: Array[Texture2D] = [preload(TERRAIN_DIR + "peak_large.png"), preload(TERRAIN_DIR + "peak_small.png")]
const BOULDER := preload(TERRAIN_DIR + "boulder.png")
const TREE := preload(TERRAIN_DIR + "tree.png")
const REEDS := preload(TERRAIN_DIR + "reeds.png")
const DEAD_TREE := preload(TERRAIN_DIR + "dead_tree.png")
const EMBER_ROCK := preload(TERRAIN_DIR + "ember_rock.png")

const GRAVE_GROUND := Color("#465e4c")
const GRAVE_EDGE := Color("#3c5444")
const FENCE := Color("#5a3a20")
const STONE := Color("#a8a8b4")
const STONE_DARK := Color("#6a6a78")
const OUTLINE := Color("#1a1220")
const DIRT := Color("#9a7a4c")
const DIRT_EDGE := Color("#7a5e3a")
const RAIL := Color("#4a2c14")
const WALL_FACE := Color("#4a4652")
const TRAIL_WIDTH := 12.0

## Show rally points and nav cells (debug / screenshots only).
var show_debug := false
var _layout: BattleLayout
var _nav: BattleNav
var _gate := Vector2.ZERO
## [texture, position (bottom centre), flip] sorted by y before drawing.
var _props: Array = []
## [kind, outline]: overlapping features of the same kind merged into one shape.
var _shapes: Array = []
## Each trail as a list of points, graveyard first.
var _trails: Array[PackedVector2Array] = []


func show_layout(layout: BattleLayout, nav: BattleNav, gate: Vector2) -> void:
	_layout = layout
	_nav = nav
	_gate = gate
	_props.clear()
	_shapes.clear()
	_trails.clear()
	if layout:
		for feature in layout.features:
			_scatter_props(feature)
		_merge_shapes()
		_plan_trails()
	_props.sort_custom(func(a: Array, b: Array) -> bool: return a[1].y < b[1].y)
	queue_redraw()


func _draw() -> void:
	if _layout == null:
		return
	for zone in _layout.get_spawn_zones():
		_draw_graveyard(zone)
	for trail in _trails:
		_draw_trail(trail)
	# Water and lava first, then bridges over them, then the high ground.
	_draw_shapes([LayoutFeature.Kind.WATER, LayoutFeature.Kind.LAVA])
	for feature in _layout.bridges():
		_draw_bridge(feature, feature.outline(_layout.feature_seed(feature)), TILES[LayoutFeature.Kind.BRIDGE])
	_draw_shapes([LayoutFeature.Kind.FOREST, LayoutFeature.Kind.MOUNTAIN, LayoutFeature.Kind.WALL])
	for prop in _props:
		var texture: Texture2D = prop[0]
		var at: Vector2 = prop[1]
		var size := texture.get_size()
		var rect := Rect2(at - Vector2(size.x * 0.5, size.y), size)
		if prop[2]:
			rect.size.x = -rect.size.x
			rect.position.x += size.x
		draw_texture_rect(texture, rect, false)
	if show_debug:
		_draw_debug()


# --- Terrain ----------------------------------------------------------------

## Draws every merged shape of these kinds: all borders first, then the fills,
## so a shape's border never covers its neighbour.
func _draw_shapes(kinds: Array) -> void:
	for entry in _shapes:
		if entry[0] not in kinds:
			continue
		var shape: PackedVector2Array = entry[1]
		if entry[0] == LayoutFeature.Kind.WALL:
			# A wall has height: draw its shadowed south face first.
			var face := PackedVector2Array()
			for point in shape:
				face.append(point + Vector2(0, 6))
			_fill(face, WALL_FACE, null)
			_outline(face, OUTLINE, 1.0)
		var border: Array = BORDERS[entry[0]]
		_fill(_largest(Geometry2D.offset_polygon(shape, border[1], Geometry2D.JOIN_ROUND)), border[0], null)
	for entry in _shapes:
		if entry[0] not in kinds:
			continue
		_fill(entry[1], Color.WHITE, TILES[entry[0]])
		if entry[0] == LayoutFeature.Kind.WATER or entry[0] == LayoutFeature.Kind.LAVA:
			_outline(entry[1], Color(1, 1, 1, 0.18), 1.0)


## Unions overlapping outlines of the same kind (a chain of pools becomes one bog).
func _merge_shapes() -> void:
	for kind: int in LayoutFeature.Kind.values():
		if kind == LayoutFeature.Kind.BRIDGE:
			continue
		var shapes: Array[PackedVector2Array] = []
		for feature in _layout.features:
			if feature.kind == kind:
				var outline := feature.outline(_layout.feature_seed(feature))
				if outline.size() >= 3:
					shapes.append(outline)
		var merged := true
		while merged:
			merged = false
			for i in shapes.size():
				for j in range(i + 1, shapes.size()):
					if Geometry2D.intersect_polygons(shapes[i], shapes[j]).is_empty():
						continue
					shapes[i] = _largest(Geometry2D.merge_polygons(shapes[i], shapes[j]))
					shapes.remove_at(j)
					merged = true
					break
				if merged:
					break
		for shape in shapes:
			_shapes.append([kind, shape])


func _draw_bridge(feature: LayoutFeature, shape: PackedVector2Array, texture: Texture2D) -> void:
	var line := feature.points
	if line.size() < 2:
		return
	var along := (line[line.size() - 1] - line[0]).normalized()
	var side := Vector2(-along.y, along.x)
	# Planks run across the bridge: UVs follow its direction.
	var uvs := PackedVector2Array()
	for point in shape:
		var local := point - line[0]
		uvs.append(Vector2(local.dot(side), local.dot(along)) / texture.get_size())
	draw_colored_polygon(shape, Color.WHITE, uvs, texture)
	var half := feature.width * 0.5
	for side_sign in [-1.0, 1.0]:
		var a: Vector2 = line[0] + side * half * side_sign
		var b: Vector2 = line[line.size() - 1] + side * half * side_sign
		draw_line(a, b, RAIL, 2.0)
		for t in [0.0, 0.33, 0.66, 1.0]:
			draw_rect(Rect2(a.lerp(b, t) - Vector2(1.5, 1.5), Vector2(3, 3)), OUTLINE)


## The biggest polygon of an offset/clip result (drops holes and slivers).
static func _largest(polygons: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := 0.0
	for polygon in polygons:
		var rect := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			rect = rect.expand(point)
		if rect.get_area() > best_area:
			best = polygon
			best_area = rect.get_area()
	return best


func _fill(shape: PackedVector2Array, color: Color, texture: Texture2D) -> void:
	if shape.size() < 3 or Geometry2D.triangulate_polygon(shape).is_empty():
		return
	if texture == null:
		draw_colored_polygon(shape, color)
		return
	var uvs := PackedVector2Array()
	for point in shape:
		uvs.append(point / texture.get_size())
	draw_colored_polygon(shape, color, uvs, texture)


func _outline(shape: PackedVector2Array, color: Color, width: float) -> void:
	var closed_shape := shape.duplicate()
	closed_shape.append(shape[0])
	draw_polyline(closed_shape, color, width)


## Peaks on mountains, trees along groves, reeds by water, rocks by lava.
## Seeded per feature so the field looks the same every run.
func _scatter_props(feature: LayoutFeature) -> void:
	var seed_value := _layout.feature_seed(feature)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var area := feature.bounds(seed_value)
	match feature.kind:
		LayoutFeature.Kind.MOUNTAIN:
			_scatter_inside(feature, area, 16.0, rng, func(r: RandomNumberGenerator) -> Texture2D:
				return PEAKS[0] if r.randf() < 0.55 else (PEAKS[1] if r.randf() < 0.8 else BOULDER))
		LayoutFeature.Kind.FOREST:
			_scatter_inside(feature, area, 11.0, rng, func(_r: RandomNumberGenerator) -> Texture2D: return TREE)
		LayoutFeature.Kind.WATER:
			_scatter_edge(feature, 14.0, 0.45, rng, [REEDS, REEDS, BOULDER])
		LayoutFeature.Kind.LAVA:
			_scatter_edge(feature, 18.0, 0.4, rng, [EMBER_ROCK, EMBER_ROCK, DEAD_TREE])


## Fills a feature with props on a jittered grid; a prop is kept only if its
## whole footprint is inside the feature (so props never cover walkable ground).
func _scatter_inside(feature: LayoutFeature, area: Rect2, spacing: float, rng: RandomNumberGenerator, pick: Callable) -> void:
	var seed_value := _layout.feature_seed(feature)
	var row := 0
	var y := area.position.y + spacing * 0.6
	while y < area.end.y + spacing:
		var x := area.position.x + (spacing * 0.5 if row % 2 else 0.0)
		while x < area.end.x + spacing:
			var at := Vector2(x, y) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
			var texture: Texture2D = pick.call(rng)
			var w := texture.get_width()
			var h := texture.get_height()
			var footprint := [Vector2(0, -1), Vector2(-w * 0.45, -1), Vector2(w * 0.45, -1),
					Vector2(-w * 0.25, -h * 0.5), Vector2(w * 0.25, -h * 0.5), Vector2(0, -h * 0.85)]
			if footprint.all(func(offset: Vector2) -> bool: return feature.contains(at + offset, seed_value)):
				_props.append([texture, at, rng.randf() < 0.5])
			x += spacing
		y += spacing * 0.75
		row += 1


## Props dotted along the outside of a feature's edge (reeds on a shore...).
func _scatter_edge(feature: LayoutFeature, spacing: float, chance: float, rng: RandomNumberGenerator, textures: Array) -> void:
	var shape := feature.outline(_layout.feature_seed(feature))
	var travelled := 0.0
	for i in shape.size():
		var a := shape[i]
		var b := shape[(i + 1) % shape.size()]
		travelled += a.distance_to(b)
		if travelled < spacing:
			continue
		travelled = 0.0
		if rng.randf() > chance:
			continue
		var edge := (b - a).normalized()
		var outward := Vector2(edge.y, -edge.x)
		if feature.contains(a + outward * 3.0, _layout.feature_seed(feature)):
			outward = -outward
		var at := a + outward * 4.0
		if _nav and (_nav.is_blocked(at) or _layout.is_blocked(at)):
			continue
		_props.append([textures[rng.randi() % textures.size()], at, rng.randf() < 0.5])


# --- Graveyards and trails --------------------------------------------------

## Dark ground, a broken fence on the side facing the castle, tombstones.
func _draw_graveyard(zone: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(zone)
	var ground := zone.grow(10)
	var shape := LayoutFeature._wobble(PackedVector2Array([ground.position, Vector2(ground.end.x, ground.position.y),
			ground.end, Vector2(ground.position.x, ground.end.y)]), 4.0, rng.randi())
	_fill(shape, GRAVE_EDGE, null)
	_fill(_largest(Geometry2D.offset_polygon(shape, -3.0)), GRAVE_GROUND, null)
	# Fence along the edge nearest the gate, with a gap where the trail leaves.
	var center := zone.get_center()
	var exits: Array[Vector2] = []
	for trail in _trails:
		if zone.grow(12).has_point(trail[0]):
			exits.append(trail[0])
	var horizontal := absf(center.y - _gate.y) * 1.6 > absf(center.x - _gate.x)
	if horizontal:
		var y := ground.position.y + 2 if center.y > _gate.y else ground.end.y - 2
		var x := ground.position.x + 4
		while x < ground.end.x - 4:
			if exits.all(func(exit: Vector2) -> bool: return absf(x - exit.x) > 12) and rng.randf() < 0.8:
				_fence_post(Vector2(x, y), rng.randf() < 0.7, Vector2(7, 0))
			x += 9
	else:
		var x := ground.end.x - 2 if center.x < _gate.x else ground.position.x + 2
		var y := ground.position.y + 6
		while y < ground.end.y - 2:
			if exits.all(func(exit: Vector2) -> bool: return absf(y - exit.y) > 12) and rng.randf() < 0.8:
				_fence_post(Vector2(x, y), rng.randf() < 0.7, Vector2(0, 6))
			y += 8
	var count := int(zone.get_area() / 340.0) + 2
	for i in count:
		var at := Vector2(rng.randf_range(zone.position.x + 2, zone.end.x - 8), rng.randf_range(zone.position.y + 2, zone.end.y - 9))
		if _nav and _nav.is_blocked(at):
			continue
		_tombstone(at, rng.randf() < 0.7)


func _fence_post(at: Vector2, rail: bool, rail_offset: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(-1, -6), Vector2(2, 6)), FENCE)
	draw_rect(Rect2(at + Vector2(-1, -6), Vector2(2, 6)), OUTLINE, false, 1.0)
	if rail:
		draw_line(at + Vector2(0, -4), at + Vector2(0, -4) + rail_offset, FENCE, 1.0)


func _tombstone(at: Vector2, slab: bool) -> void:
	if slab:
		draw_rect(Rect2(at, Vector2(6, 8)), STONE)
		draw_rect(Rect2(at, Vector2(6, 8)), OUTLINE, false, 1.0)
		draw_line(at + Vector2(3, 3), at + Vector2(3, 6), STONE_DARK)
		draw_line(at + Vector2(2, 4), at + Vector2(4, 4), STONE_DARK)
	else:
		draw_rect(Rect2(at + Vector2(2, 0), Vector2(2, 9)), STONE)
		draw_rect(Rect2(at + Vector2(0, 2), Vector2(6, 2)), STONE)
	draw_line(at + Vector2(-1, 9), at + Vector2(7, 9), Color("#2a3a30"))


## Where the trail out of a graveyard starts: its edge nearest the gate.
func _trail_start(zone: Rect2) -> Vector2:
	var start := Vector2(clampf(_gate.x, zone.position.x + 8, zone.end.x - 8), clampf(_gate.y, zone.position.y, zone.end.y))
	return _nav.nearest_free(start)


## One trail per graveyard along the route its spirits take to the gate. A wide
## graveyard gets extra trails from its ends when they take another way in
## (e.g. over the other bridge).
func _plan_trails() -> void:
	var goal := _gate + Vector2(0, 6)
	for zone in _layout.get_spawn_zones():
		var starts: Array[Vector2] = [_trail_start(zone)]
		if zone.size.x > 300.0 and _nav.has_obstacles:
			for fraction in [0.2, 0.8]:
				starts.append(_nav.nearest_free(Vector2(zone.position.x + zone.size.x * fraction, zone.position.y)))
		for start in starts:
			var route := PackedVector2Array([start])
			route.append_array(_nav.find_path(start, goal))
			if route.size() < 2 or _joins_existing_trail(route):
				continue
			_trails.append(route)


## True if `route` reaches the gate the same way as a trail already planned
## (compared at a point 120 px before the gate).
func _joins_existing_trail(route: PackedVector2Array) -> bool:
	var probe := _point_before_end(route, 120.0)
	for trail in _trails:
		if _point_before_end(trail, 120.0).distance_to(probe) < 28.0:
			return true
	return false


static func _point_before_end(route: PackedVector2Array, distance: float) -> Vector2:
	var left := distance
	for i in range(route.size() - 1, 0, -1):
		var length := route[i].distance_to(route[i - 1])
		if length >= left:
			return route[i].move_toward(route[i - 1], left)
		left -= length
	return route[0]


## A worn dirt trail along a route.
func _draw_trail(route: PackedVector2Array) -> void:
	var points := _wiggle(route)
	for pass_index in 2:
		var width := TRAIL_WIDTH + 3.0 if pass_index == 0 else TRAIL_WIDTH
		var color := DIRT_EDGE if pass_index == 0 else DIRT
		draw_polyline(points, color, width)
		for point in points:
			draw_circle(point, width * 0.5, color)


## Subdivides a route and bends it gently so trails don't look ruler-straight.
func _wiggle(route: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var travelled := 0.0
	var total := 0.0
	for i in range(1, route.size()):
		total += route[i - 1].distance_to(route[i])
	for i in range(1, route.size()):
		var a := route[i - 1]
		var b := route[i]
		var length := a.distance_to(b)
		var normal := (b - a).orthogonal().normalized()
		var steps := maxi(1, ceili(length / 8.0))
		for s in steps:
			var along := travelled + length * s / steps
			var fade := clampf(minf(along, total - along) / 40.0, 0.0, 1.0)
			var point := a.lerp(b, float(s) / steps) + normal * sin(along * 0.035) * 7.0 * fade
			if _nav and _nav.is_blocked(point):
				point = a.lerp(b, float(s) / steps)
			result.append(point)
		travelled += length
	result.append(route[route.size() - 1])
	return result


# --- Debug ------------------------------------------------------------------

func _draw_debug() -> void:
	if _nav and _nav.has_obstacles:
		for y in BattleNav.SIZE.y:
			for x in BattleNav.SIZE.x:
				if _nav.is_cell_blocked(Vector2i(x, y)):
					draw_rect(Rect2(Vector2(x, y) * BattleNav.CELL, Vector2.ONE * BattleNav.CELL), Color(1, 0, 0, 0.18))
	var font := ThemeDB.fallback_font
	for point in _layout.rally_points:
		draw_arc(point.position, point.radius, 0, TAU, 24, Color(1, 0.9, 0.2, 0.8), 1.0)
		draw_line(point.position, point.position + Vector2(0, -12), OUTLINE, 1.0)
		draw_rect(Rect2(point.position + Vector2(0, -12), Vector2(7, 4)), Color("#f8d038"))
		draw_string(font, point.position + Vector2(-30, 10), point.display_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 6, Color.WHITE)
