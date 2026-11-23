class_name MachineRules
extends RefCounted
## Picks the right evaluator for a machine style. Pure: everything it needs is
## passed in, so the rules can be tested and simulated without the scene.


## Reel heights for one spin. Variable-height machines roll each reel.
static func roll_heights(style: MachineStyle, rows: int, min_rows_bonus: int = 0) -> Array[int]:
	var heights: Array[int] = []
	for reel in style.reel_count:
		if style.variable_rows:
			heights.append(randi_range(mini(style.min_rows + min_rows_bonus, style.max_rows), style.max_rows))
		else:
			heights.append(rows)
	return heights


## True if this spin pays by ways (Jester's 81 switches when a Jester shows).
static func uses_ways(grid: Array, style: MachineStyle) -> bool:
	match style.eval_mode:
		MachineStyle.Eval.WAYS:
			return true
		MachineStyle.Eval.LINES_OR_WAYS:
			return GridOps.count(grid, style.ways_trigger) > 0
	return false


## Every win on the grid, smallest first.
static func evaluate(grid: Array, style: MachineStyle, lines: Array[Payline]) -> Array[SlotWin]:
	if uses_ways(grid, style):
		return WaysEvaluator.evaluate(grid, style.ways_match())
	return LineEvaluator.evaluate(grid, lines, style)


## Should the reel after the first `reels` ones be teased (a big win is building)?
static func is_building_big_win(grid: Array, style: MachineStyle, lines: Array[Payline], reels: int) -> bool:
	if uses_ways(grid, style):
		return WaysEvaluator.is_building_big_win(grid, reels, style.ways_match())
	return LineEvaluator.is_building_big_win(grid, lines, reels, style.min_match)
