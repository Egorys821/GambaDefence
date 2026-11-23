class_name WaysEvaluator
extends RefCounted
## Pure slot rules for ways machines (Jester's 81, Shifting Halls): a symbol
## wins when it shows on adjacent reels from the left, on any row. The number
## of ways is the product of its copies on each of those reels, so 2 Swords on
## each of 3 reels is 2 x 2 x 2 = 8 ways. Reels may have different heights.
## Wilds help every symbol they cover, but never curses.


## Every winning symbol, smallest win first.
static func evaluate(grid: Array, min_match: int) -> Array[SlotWin]:
	var wins: Array[SlotWin] = []
	var wild_wins: Array[SlotWin] = []
	for candidate in _candidates(grid):
		var win := _win_for(grid, candidate, min_match)
		if win:
			(wild_wins if candidate.is_wild() else wins).append(win)
	# A run of wilds alone pays only if nothing else won.
	if wins.is_empty():
		wins = wild_wins
	wins.sort_custom(func(a: SlotWin, b: SlotWin) -> bool: return a.count < b.count)
	return wins


## True if some symbol already wins on all of the first `reels` reels.
static func is_building_big_win(grid: Array, reels: int, min_match: int) -> bool:
	if reels < min_match:
		return false
	var partial := grid.slice(0, reels)
	for candidate in _candidates(partial):
		if _hits_per_reel(partial, candidate).size() >= reels:
			return true
	return false


static func _win_for(grid: Array, candidate: SymbolData, min_match: int) -> SlotWin:
	if candidate.effect == SymbolData.Effect.NONE:
		return null
	var hits := _hits_per_reel(grid, candidate)
	if hits.size() < min_match:
		return null
	var ways := 1
	var cells: Array[Vector2i] = []
	for reel_hits: Array[Vector2i] in hits:
		ways *= reel_hits.size()
		cells.append_array(reel_hits)
	return SlotWin.combo(candidate, hits.size(), ways, cells)


## Cells showing `candidate` (or a wild for it) on each reel, from the left,
## stopping at the first reel without one.
static func _hits_per_reel(grid: Array, candidate: SymbolData) -> Array:
	var hits := []
	for reel in grid.size():
		var reel_hits: Array[Vector2i] = []
		for row in grid[reel].size():
			var symbol: SymbolData = grid[reel][row]
			if symbol.id == candidate.id or (not candidate.is_wild() and symbol.is_wild_for(candidate)):
				reel_hits.append(Vector2i(reel, row))
		if reel_hits.is_empty():
			break
		hits.append(reel_hits)
	return hits


## Symbols that could win: the ones on the first reel, what its wilds cover
## (for a universal wild: every symbol on the first reel that has non-wilds),
## and the wilds themselves.
static func _candidates(grid: Array) -> Array[SymbolData]:
	var candidates: Array[SymbolData] = []
	if grid.is_empty():
		return candidates
	var universal := false
	for symbol: SymbolData in grid[0]:
		_add(candidates, symbol)
		if symbol.is_wild():
			if symbol.wild_for.is_empty():
				universal = true
			for target in symbol.wild_for:
				_add(candidates, target)
	if universal:
		for reel in range(1, grid.size()):
			var found := false
			for symbol: SymbolData in grid[reel]:
				if not symbol.is_wild():
					_add(candidates, symbol)
					found = true
			if found:
				break
	return candidates


static func _add(candidates: Array[SymbolData], symbol: SymbolData) -> void:
	for existing in candidates:
		if existing.id == symbol.id:
			return
	candidates.append(symbol)
