class_name BookExpansion
extends RefCounted
## Tome of Ages rules (pure). Free spins pick one expanding symbol. Whenever
## it shows on enough reels (anywhere, not necessarily adjacent), it fills
## those reels and pays on every active line at once.

## Reels the expanding symbol must show on, before upgrades.
const MIN_REELS := 4


## Symbols that may be picked: real paying symbols, never wilds, junk,
## curses or the scatter.
static func is_eligible(symbol: SymbolData) -> bool:
	return symbol.effect in [SymbolData.Effect.GOLD, SymbolData.Effect.SPAWN_UNIT, SymbolData.Effect.REPAIR] \
		and not symbol.is_scatter


## A random eligible symbol, each kind equally likely (not weighted by copies).
static func pick_symbol(candidates: Array) -> SymbolData:
	var eligible := candidates.filter(is_eligible)
	return eligible.pick_random() if not eligible.is_empty() else null


## Reels showing the symbol at least once (wilds don't count here).
static func reels_with(grid: Array, symbol: SymbolData) -> Array[int]:
	var reels: Array[int] = []
	for reel in grid.size():
		for cell: SymbolData in grid[reel]:
			if cell.id == symbol.id:
				reels.append(reel)
				break
	return reels


## The expansion win, or null: the symbol fills its reels and pays as a
## `reels`-long match on each of `line_count` lines.
static func evaluate(grid: Array, symbol: SymbolData, line_count: int, min_reels: int) -> SlotWin:
	var reels := reels_with(grid, symbol)
	if reels.size() < min_reels or line_count <= 0:
		return null
	var cells: Array[Vector2i] = []
	for reel in reels:
		for row in grid[reel].size():
			cells.append(Vector2i(reel, row))
	var win := SlotWin.combo(symbol, reels.size(), line_count, cells)
	win.label = "Expanding %s on %d line%s" % [symbol.display_name, line_count, "" if line_count == 1 else "s"]
	win.color = Color("#f8d038")
	return win


## The grid as shown after the expansion: the symbol fills each of its reels.
static func expanded_grid(grid: Array, symbol: SymbolData) -> Array:
	var result := grid.duplicate()
	for reel in reels_with(grid, symbol):
		var column := []
		column.resize(grid[reel].size())
		column.fill(symbol)
		result[reel] = column
	return result
