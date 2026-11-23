class_name LayoutFeature
extends Resource
## One piece of terrain on a battlefield layout (see BattleLayout): a mountain,
## a lake, a river, a grove, a ruined wall, lava, or a bridge across them.
##
## The shape is either a closed polygon (`closed = true`) or a polyline drawn
## `width` pixels wide (rivers, walls, bridges). Points are in battlefield
## pixels (the field is 640x360, castle gate at (320, 108)); they may run past
## the edges. Edges get a little seeded wobble so shapes look hand-drawn; the
## pathing grid uses the same wobbled outline.

enum Kind {
	MOUNTAIN,  ## Rocky cliffs and peaks. Blocks walking.
	WATER,  ## River, lake or bog. Blocks walking.
	FOREST,  ## Dense trees. Blocks walking.
	WALL,  ## Ruined stone wall or crypt. Blocks walking.
	LAVA,  ## Molten rock. Blocks walking.
	BRIDGE,  ## Walkable: carves a crossing through any blocking feature.
}

@export var kind: Kind = Kind.MOUNTAIN
@export var points: PackedVector2Array = PackedVector2Array()
## true: `points` outline a polygon. false: a polyline `width` pixels wide.
@export var closed: bool = true
@export var width: float = 24.0
## Edge wobble in pixels (0 = straight edges, e.g. for bridges and walls).
@export var roughness: float = 3.0

var _outline_cache: PackedVector2Array


## True for every kind except BRIDGE.
func blocks_walking() -> bool:
	return kind != Kind.BRIDGE


## The final outline (closed polygon) used for both pathing and drawing.
## `seed_value` keeps the wobble stable per feature.
func outline(seed_value: int = 0) -> PackedVector2Array:
	if not _outline_cache.is_empty():
		return _outline_cache
	var base := points
	if not closed:
		base = _thicken(points, width)
	if roughness > 0.0 and base.size() >= 3:
		var rough := _wobble(base, roughness, seed_value)
		if not Geometry2D.triangulate_polygon(rough).is_empty():
			base = rough
	_outline_cache = base
	return _outline_cache


func bounds(seed_value: int = 0) -> Rect2:
	var shape := outline(seed_value)
	if shape.is_empty():
		return Rect2()
	var rect := Rect2(shape[0], Vector2.ZERO)
	for point in shape:
		rect = rect.expand(point)
	return rect


func contains(point: Vector2, seed_value: int = 0) -> bool:
	if not bounds(seed_value).grow(0.5).has_point(point):
		return false
	return Geometry2D.is_point_in_polygon(point, outline(seed_value))


## A polyline turned into a polygon `thickness` wide. Bridges and walls get
## flat ends, rivers round ones.
func _thicken(line: PackedVector2Array, thickness: float) -> PackedVector2Array:
	if line.size() < 2:
		return PackedVector2Array()
	var square := kind == Kind.BRIDGE or kind == Kind.WALL
	var ends := Geometry2D.END_BUTT if square else Geometry2D.END_ROUND
	var joins := Geometry2D.JOIN_MITER if square else Geometry2D.JOIN_ROUND
	var polygons := Geometry2D.offset_polyline(line, thickness * 0.5, joins, ends)
	return polygons[0] if not polygons.is_empty() else PackedVector2Array()


## Subdivides edges every few pixels and pushes points in or out by smooth noise.
static func _wobble(shape: PackedVector2Array, amount: float, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17
	var phase_a := rng.randf() * TAU
	var phase_b := rng.randf() * TAU
	var result := PackedVector2Array()
	var travelled := 0.0
	for i in shape.size():
		var a := shape[i]
		var b := shape[(i + 1) % shape.size()]
		var edge := b - a
		var length := edge.length()
		if length < 0.01:
			continue
		var normal := Vector2(-edge.y, edge.x) / length
		var steps := maxi(1, ceili(length / 9.0))
		for s in steps:
			var t := float(s) / steps
			var along := travelled + t * length
			var push := (sin(along * 0.11 + phase_a) * 0.6 + sin(along * 0.29 + phase_b) * 0.4) * amount
			# Corners stay put so neighbouring shapes still meet where they were placed.
			result.append(a + edge * t + (normal * push if s > 0 else Vector2.ZERO))
		travelled += length
	return result
