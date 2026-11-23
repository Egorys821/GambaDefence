class_name BattleLayout
extends Resource
## The battlefield in front of one castle: terrain that blocks and routes
## spirits and troops, where the graveyards are, where watchtowers stand, and
## named rally points for future troop orders. Layouts live in
## res://data/layouts/ and are picked by CastleData.layout.
##
## Coordinates are battlefield pixels: the field is 640x360, the castle wall
## stands at y 40-104 around x 320 and the gate is at (320, 108). Keep the
## courtyard in front of the castle (BattleLayout.KEEP_CLEAR) free: the army
## forms up there. The rules test checks every layout.

## Open ground the army forms up on. Obstacles must stay out of it.
const KEEP_CLEAR := Rect2(200, 100, 240, 70)
const DEFAULT_SPAWN_ZONES: Array[Rect2] = [Rect2(16, 326, 608, 26)]
const DEFAULT_TOWER_SLOTS: Array[Vector2] = [Vector2(234, 106), Vector2(406, 106), Vector2(190, 150), Vector2(450, 150)]

@export var id: StringName
@export var display_name: String
## One line for the kingdom map ("A river crossed by two bridges.").
@export var description: String
## Terrain. Order matters only for drawing (later features draw on top).
@export var features: Array[LayoutFeature] = []
## Spirits rise in these areas (a graveyard is drawn in each). Picked at
## random per spirit, weighted by area.
@export var spawn_zones: Array[Rect2] = []
## Where watchtowers are built, in order (first two are visible by day).
## Empty = the default four slots beside the castle.
@export var tower_slots: Array[Vector2] = []
## Named positions for future troop orders (see RallyPoint).
@export var rally_points: Array[RallyPoint] = []


func get_spawn_zones() -> Array[Rect2]:
	return spawn_zones if not spawn_zones.is_empty() else DEFAULT_SPAWN_ZONES


func get_tower_slots() -> Array[Vector2]:
	return tower_slots if not tower_slots.is_empty() else DEFAULT_TOWER_SLOTS


func blocking_features() -> Array[LayoutFeature]:
	return features.filter(func(feature: LayoutFeature) -> bool: return feature.blocks_walking())


func bridges() -> Array[LayoutFeature]:
	return features.filter(func(feature: LayoutFeature) -> bool: return not feature.blocks_walking())


## Seed for a feature's edge wobble (stable per layout and feature index).
func feature_seed(feature: LayoutFeature) -> int:
	return hash(id) + features.find(feature) * 101


## True if a walking unit can't stand here (inside terrain and not on a bridge).
func is_blocked(point: Vector2) -> bool:
	var blocked := false
	for feature in features:
		if feature.blocks_walking() and feature.contains(point, feature_seed(feature)):
			blocked = true
			break
	if not blocked:
		return false
	for feature in features:
		if not feature.blocks_walking() and feature.contains(point, feature_seed(feature)):
			return false
	return true


func rally_point(point_id: StringName) -> RallyPoint:
	for point in rally_points:
		if point.id == point_id:
			return point
	return null
