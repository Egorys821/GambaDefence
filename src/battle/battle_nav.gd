class_name BattleNav
extends RefCounted
## Walking grid for a BattleLayout: which cells are blocked by terrain, plus
## A* paths around it. Flying spirits ignore it. On a layout without terrain
## every query is a straight line, so the open field costs nothing.

const CELL := 8
## Covers Battlefield.FIELD (spirits start a little below the bottom edge).
const SIZE := Vector2i(80, 50)
## Half-width of the corridor a straight walk needs (keeps units off edges).
const CLEARANCE := 3.0

var layout: BattleLayout
var has_obstacles := false
var _blocked := PackedByteArray()
var _astar := AStarGrid2D.new()


func _init(battle_layout: BattleLayout) -> void:
	layout = battle_layout
	_blocked.resize(SIZE.x * SIZE.y)
	_astar.region = Rect2i(Vector2i.ZERO, SIZE)
	_astar.cell_size = Vector2(CELL, CELL)
	_astar.offset = Vector2(CELL, CELL) * 0.5
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	if layout == null or layout.blocking_features().is_empty():
		return
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			if layout.is_blocked(cell_center(cell)):
				_blocked[y * SIZE.x + x] = 1
				_astar.set_point_solid(cell)
				has_obstacles = true


static func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(point.x / CELL), 0, SIZE.x - 1), clampi(floori(point.y / CELL), 0, SIZE.y - 1))


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2(CELL, CELL) * 0.5


func is_blocked(point: Vector2) -> bool:
	if not has_obstacles:
		return false
	var cell := cell_of(point)
	return _blocked[cell.y * SIZE.x + cell.x] == 1


func is_cell_blocked(cell: Vector2i) -> bool:
	return _blocked[cell.y * SIZE.x + cell.x] == 1


## Can a walker go straight from `a` to `b` without touching terrain?
## `clearance` = how far from terrain the line must stay on both sides.
func is_clear_line(a: Vector2, b: Vector2, clearance: float = CLEARANCE) -> bool:
	if not has_obstacles:
		return true
	var offset := b - a
	var length := offset.length()
	if length < 0.5:
		return not is_blocked(b)
	var side := Vector2(-offset.y, offset.x) / length * clearance
	var steps := ceili(length / 4.0)
	for i in steps + 1:
		var point := a + offset * (float(i) / steps)
		if is_blocked(point) or is_blocked(point + side) or is_blocked(point - side):
			return false
	return true


## Nearest open spot to `point` (itself if already open).
func nearest_free(point: Vector2) -> Vector2:
	if not is_blocked(point):
		return point
	var start := cell_of(point)
	for radius in range(1, maxi(SIZE.x, SIZE.y)):
		var best := Vector2.INF
		for y in range(start.y - radius, start.y + radius + 1):
			for x in range(start.x - radius, start.x + radius + 1):
				if maxi(absi(x - start.x), absi(y - start.y)) != radius:
					continue
				if x < 0 or y < 0 or x >= SIZE.x or y >= SIZE.y or is_cell_blocked(Vector2i(x, y)):
					continue
				var center := cell_center(Vector2i(x, y))
				if center.distance_squared_to(point) < best.distance_squared_to(point):
					best = center
		if best != Vector2.INF:
			return best
	return point


## Waypoints from `from` to `to` around terrain, ending exactly at `to` (or
## the nearest open spot to it). Empty if there is no way through.
## Straight stretches are merged, so the list is short.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var goal := nearest_free(to)
	if is_clear_line(from, goal):
		return PackedVector2Array([goal])
	var cells := _astar.get_id_path(cell_of(nearest_free(from)), cell_of(goal))
	if cells.is_empty():
		return PackedVector2Array()
	var raw := PackedVector2Array()
	for cell in cells:
		raw.append(cell_center(cell))
	raw[raw.size() - 1] = goal
	return _smooth(from, raw)


## True if a walker at `from` can reach `to` at all.
func can_reach(from: Vector2, to: Vector2) -> bool:
	return not find_path(from, to).is_empty()


## Walking distance along find_path (INF if unreachable).
func path_length(from: Vector2, to: Vector2) -> float:
	var path := find_path(from, to)
	if path.is_empty():
		return INF
	var total := from.distance_to(path[0])
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


## Greedy string pulling: walks the cell path and keeps only the waypoints
## where the straight line from the last kept one gets blocked.
func _smooth(from: Vector2, raw: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var anchor := from
	var i := 0
	while i < raw.size():
		var j := i
		while j + 1 < raw.size() and is_clear_line(anchor, raw[j + 1]):
			j += 1
		result.append(raw[j])
		anchor = raw[j]
		i = j + 1
	return result
