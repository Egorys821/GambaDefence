class_name GridOps
extends RefCounted
## Pure helpers on a reel grid (grid[reel][row] -> SymbolData). Symbols are
## produced by a `roll` Callable (GameState.roll_symbol in the game, a fixed
## sequence in tests).


## A new grid with `heights[reel]` rolled symbols on each reel.
static func roll(heights: Array[int], roll_symbol: Callable) -> Array:
	var grid := []
	for height in heights:
		var column := []
		for row in height:
			column.append(roll_symbol.call())
		grid.append(column)
	return grid


static func count(grid: Array, symbol: SymbolData) -> int:
	return cells_of(grid, symbol).size()


static func cells_of(grid: Array, symbol: SymbolData) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if symbol == null:
		return cells
	for reel in grid.size():
		for row in grid[reel].size():
			if (grid[reel][row] as SymbolData).id == symbol.id:
				cells.append(Vector2i(reel, row))
	return cells


static func all_cells(grid: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for reel in grid.size():
		for row in grid[reel].size():
			cells.append(Vector2i(reel, row))
	return cells


## Cascade: removes `cells`, lets the rest of each reel fall down and fills the
## top with new symbols. Returns {"grid": new grid, "falls": falls[reel][row] =
## rows that cell fell (0 = didn't move), "new_cells": cells that were rolled}.
static func collapse(grid: Array, cells: Array[Vector2i], roll_symbol: Callable) -> Dictionary:
	var new_grid := []
	var falls := []
	var new_cells: Array[Vector2i] = []
	for reel in grid.size():
		var height: int = grid[reel].size()
		var kept := []
		var kept_rows: Array[int] = []
		for row in height:
			if Vector2i(reel, row) not in cells:
				kept.append(grid[reel][row])
				kept_rows.append(row)
		var removed := height - kept.size()
		var column := []
		var reel_falls: Array[int] = []
		for row in removed:
			column.append(roll_symbol.call())
			reel_falls.append(removed)
			new_cells.append(Vector2i(reel, row))
		for i in kept.size():
			column.append(kept[i])
			reel_falls.append(removed + i - kept_rows[i])
		new_grid.append(column)
		falls.append(reel_falls)
	return {"grid": new_grid, "falls": falls, "new_cells": new_cells}


## Nudge: the reel moves one row down; `new_top` scrolls in at the top.
static func nudge(grid: Array, reel: int, new_top: SymbolData) -> Array:
	var new_grid := grid.duplicate()
	var column: Array = grid[reel].duplicate()
	column.pop_back()
	column.push_front(new_top)
	new_grid[reel] = column
	return new_grid
