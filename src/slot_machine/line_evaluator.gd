class_name LineEvaluator
extends RefCounted
## Pure slot rules for payline machines: which lines win on a grid
## (grid[reel][row] -> SymbolData). Symbols must match from the leftmost reel;
## wilds stand in for the symbols they are wild for (SymbolData.wild_for,
## empty = any symbol). Style options add mixed group wins, multiplier wilds
## and consolation coins (Old Cellar).

const CONSOLATION_SYMBOL := &"coin"
const MIXED_REWARD_SCALE := 0.5


## Every winning line, smallest win first (the order they are presented).
static func evaluate(grid: Array, lines: Array[Payline], style: MachineStyle) -> Array[SlotWin]:
	var wins: Array[SlotWin] = []
	for line in lines:
		var win := _line_win(grid, line, style)
		if win:
			wins.append(win)
	# The lucky coin is a consolation: once, and only for a spin that lost.
	if wins.is_empty() and style.consolation_coin:
		var lucky := _consolation_win(grid, lines)
		if lucky:
			wins.append(lucky)
	wins.sort_custom(func(a: SlotWin, b: SlotWin) -> bool: return a.count < b.count)
	return wins


## True if some line already matches on all of the first `reels` reels and a
## win is guaranteed, so the next reel decides between a normal and a big win.
static func is_building_big_win(grid: Array, lines: Array[Payline], reels: int, min_match: int) -> bool:
	if reels < min_match:
		return false
	for line in lines:
		if best_match(grid, line.rows, reels)[0] >= reels:
			return true
	return false


## Longest match from the left along `rows` within the first `reels` reels.
## Returns [count, symbol the line pays as]. Each candidate symbol is tried so
## group wilds pick the symbol they help most.
static func best_match(grid: Array, rows: Array, reels: int) -> Array:
	var best_count := 0
	var best_symbol: SymbolData = null
	for candidate in _candidates(grid, rows, reels):
		var count := _run_length(grid, rows, reels, candidate)
		if count > best_count:
			best_count = count
			best_symbol = candidate
	return [best_count, best_symbol]


static func _line_win(grid: Array, line: Payline, style: MachineStyle) -> SlotWin:
	var reels := grid.size()
	var best := best_match(grid, line.rows, reels)
	var count: int = best[0]
	var symbol: SymbolData = best[1]
	if count >= style.min_match and symbol and symbol.effect != SymbolData.Effect.NONE:
		var win := SlotWin.line(line, symbol, count)
		win.extra_mult = _wild_multiplier(grid, win.cells, symbol)
		return win
	if style.group_pays:
		var mixed := _group_win(grid, line, style.min_match)
		if mixed:
			return mixed
	return null


## A Gold Coin in the middle of the first reel pays a little gold.
static func _consolation_win(grid: Array, _lines: Array[Payline]) -> SlotWin:
	var middle: int = grid[0].size() / 2
	var first: SymbolData = grid[0][middle]
	if first.id != CONSOLATION_SYMBOL:
		return null
	var cells: Array[Vector2i] = [Vector2i(0, middle)]
	return SlotWin.prize(SymbolData.Effect.GOLD, GameState.stat_int(Stats.CONSOLATION_GOLD), first, cells, "Lucky coin")


## Mixed win (the classic "any BAR"): the first `min_match` reels of the line
## show different symbols of one group, no wilds. Pays half of the weakest.
static func _group_win(grid: Array, line: Payline, min_match: int) -> SlotWin:
	var seen: Array[StringName] = []
	var weakest: SymbolData = null
	for reel in min_match:
		var symbol: SymbolData = grid[reel][line.rows[reel]]
		if symbol.is_wild() or symbol.group == &"" or symbol.id in seen:
			return null
		if weakest and symbol.group != weakest.group:
			return null
		seen.append(symbol.id)
		if weakest == null or symbol.power < weakest.power:
			weakest = symbol
	var win := SlotWin.line(line, weakest, min_match)
	win.label = "%s: mixed %s" % [line.display_name(), weakest.group]
	win.reward_scale = MIXED_REWARD_SCALE
	return win


## Product of the multipliers of the wilds that helped this win.
static func _wild_multiplier(grid: Array, cells: Array[Vector2i], paid_as: SymbolData) -> int:
	if paid_as.is_wild():
		return 1
	var multiplier := 1
	for cell in cells:
		var symbol: SymbolData = grid[cell.x][cell.y]
		if symbol.is_wild():
			multiplier *= symbol.wild_multiplier
	return multiplier


## Symbols a line could pay as: every non-wild on it, plus what its wilds cover.
static func _candidates(grid: Array, rows: Array, reels: int) -> Array[SymbolData]:
	var candidates: Array[SymbolData] = []
	for reel in reels:
		var symbol: SymbolData = grid[reel][rows[reel]]
		var options: Array[SymbolData] = []
		if symbol.is_wild():
			options.assign(symbol.wild_for)
		else:
			options.append(symbol)
		for option in options:
			if option not in candidates:
				candidates.append(option)
	if candidates.is_empty():
		# Only universal wilds: the line pays as the wild itself.
		candidates.append(grid[0][rows[0]])
	return candidates


## How many reels from the left show `candidate` or a wild that covers it.
static func _run_length(grid: Array, rows: Array, reels: int, candidate: SymbolData) -> int:
	var count := 0
	for reel in reels:
		var symbol: SymbolData = grid[reel][rows[reel]]
		if symbol.id != candidate.id and not symbol.is_wild_for(candidate):
			break
		count += 1
	return count
