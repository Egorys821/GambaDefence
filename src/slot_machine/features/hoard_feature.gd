class_name HoardFeature
extends MachineFeature
## Dragon's Hoard: enough chests anywhere start a hold-and-win round. Chests
## lock with a prize, the other cells empty out and respin on their own (see
## HoardRound). Filling every cell adds the Grand prize.
##
## Presentation: the chests flare up, the reels clear, the starting chests open
## one by one (each shows its prize with a burst), every new chest resets the
## respins ("RESET!"), the last respin is called out, and at the end every
## chest is counted into a growing gold total before the payout.

const COIN_ID := &"coin"
const COIN_TEXTURE := preload("res://assets/sprites/symbols/coin.png")
const HOARD_GREEN := Color("#30c070")
const GOLD := Color("#f8d038")
const TROOP_COLOR := Color("#70b8ff")
const REPAIR_COLOR := Color("#70e070")
## Pause between chests opening (start of the round, after a respin) and while counting.
const REVEAL_STEP := 0.13
const TALLY_STEP := 0.08
## Most coins flying to the total at once (keeps big hoards readable).
const MAX_TALLY_COINS := 14

var _empty: SymbolData


func _init() -> void:
	_empty = SymbolData.new()
	_empty.id = &"empty"


func after_spin(machine: SlotMachine, _wins: Array[SlotWin]) -> void:
	var chest := machine.style.feature_symbol
	var start := GridOps.cells_of(machine.grid, chest)
	if start.size() < GameState.feature_trigger():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var units := _unit_symbols()
	var coin_power := _coin_power()
	var roll_prize := func() -> HoardPrize: return HoardPrize.roll(rng, coin_power, units)
	var hoard := HoardRound.new(machine.grid.size(), machine.rows, GameState.feature_length())
	start.sort_custom(_reading_order)

	# The chests flare up before the rest of the reels clear.
	machine.announce("DRAGON'S HOARD!", HOARD_GREEN)
	Audio.play(&"big_win", 0.8, -2.0)
	Fx.shake_control(machine, 5.0, 0.45)
	machine.cabinet.set_hoard_mode(true)
	for cell in start:
		_burst(machine, cell, GOLD, 8, 50.0)
	await machine.wait(0.45)
	await machine.enter_cell_mode(chest)  # the other symbols stay; they respin around the chests

	# The starting chests open one by one (one round in three hides the Dragon's Treasure).
	for cell in start:
		hoard.lock(cell, roll_prize.call())
	var treasure := hoard.roll_big_prize(rng, units)
	for i in start.size():
		_reveal(machine, start[i], hoard.prizes[start[i]], i)
		await machine.wait(REVEAL_STEP)
	if treasure != Vector2i(-1, -1):
		machine.announce("DRAGON'S TREASURE!", LineOverlay.JACKPOT_COLORS["MAJOR"])
		Fx.shake_control(machine, 6.0, 0.5)
		_burst(machine, treasure, GOLD, 30, 100.0, COIN_TEXTURE)
		await machine.wait(0.5)

	var opened := start.size()
	while not hoard.is_over():
		var last := hoard.respins_left == 1
		machine.set_status("LAST RESPIN!" if last else "Respins: %d" % hoard.respins_left)
		machine.cabinet.set_respins(hoard.respins_left, hoard.max_respins)
		if last:
			Audio.play(&"tease", 1.0, -6.0)
		var empty := hoard.empty_cells()
		var landed := hoard.respin(hoard.chest_chance(), rng, roll_prize)
		landed.sort_custom(_reading_order)
		var targets := {}
		for cell in empty:
			targets[cell] = chest if cell in landed else _filler(chest)
		await machine.spin_cells(targets)
		for cell in landed:
			_reveal(machine, cell, hoard.prizes[cell], opened)
			opened += 1
			await machine.wait(REVEAL_STEP)
		if not landed.is_empty() and not hoard.is_full():
			_float(machine, _above_reels(machine), "RESPINS RESET!", HOARD_GREEN, 10)
		machine.cabinet.set_respins(hoard.respins_left, hoard.max_respins)
	machine.set_status("")

	var grand: HoardPrize = null
	if hoard.is_full():
		grand = HoardPrize.grand(units, rng)
		machine.announce("GRAND HOARD!", GOLD)
		Audio.play(&"victory", 1.1, -4.0)
		Fx.shake_control(machine, 7.0, 0.6)
		for cell: Vector2i in hoard.prizes:
			_burst(machine, cell, GOLD, 6, 80.0, COIN_TEXTURE)
		await machine.wait(0.6)
	await _tally(machine, hoard, grand)
	await machine.present(hoard.payout(chest, GameState.castle_max_hp, grand, GameState.stat(Stats.HOARD_GOLD_BONUS)))
	await machine.wait(0.6)
	machine.cabinet.set_hoard_mode(false)
	machine.exit_cell_mode()


## The Hoard starts this spin: skip the line animation and go straight to it.
func skips_win_show(grid: Array) -> bool:
	return GridOps.cells_of(grid, GameState.machine.feature_symbol).size() >= GameState.feature_trigger()


## A normal symbol for a cell that didn't land a chest (it pays nothing in the Hoard).
func _filler(chest: SymbolData) -> SymbolData:
	for i in 12:
		var symbol := GameState.roll_symbol()
		if symbol != chest:
			return symbol
	return _empty


func wants_tease(grid: Array, reels: int) -> bool:
	return MachineFeature.one_short(grid, GameState.machine.feature_symbol, GameState.feature_trigger(), reels)


# --- Presentation ---------------------------------------------------------------

## A chest opens: its label, a burst in its colour, the prize floating up and a
## coin sound that rises with every chest in the round. Jackpots shake the machine.
func _reveal(machine: SlotMachine, cell: Vector2i, prize: HoardPrize, index: int) -> void:
	machine.lock_cell(cell, prize.short_text())
	var color := _prize_color(prize)
	var jackpot := prize.is_jackpot()
	_burst(machine, cell, color, 18 if jackpot else 9, 75.0 if jackpot else 55.0,
		COIN_TEXTURE if prize.gold > 0 and not jackpot else null)
	if prize.gold <= 0 or jackpot:
		_float(machine, cell, _prize_text(prize), color, 11 if jackpot else 8)  # gold shows on the chest
	Audio.play(&"coin", minf(1.0 + index * 0.05, 1.9), -4.0)
	if jackpot:
		Audio.play(&"big_win", 1.0, -4.0)
		Fx.shake_control(machine, 4.0, 0.3)


## Every chest is counted into a growing total in the middle of the reels:
## coins fly from the gold chests to it, then it pops.
func _tally(machine: SlotMachine, hoard: HoardRound, grand: HoardPrize) -> void:
	var cells: Array[Vector2i] = []
	cells.assign(hoard.prizes.keys())
	cells.sort_custom(_reading_order)
	var total := Label.new()
	total.add_theme_font_size_override("font_size", 16)
	total.add_theme_color_override("font_color", GOLD)
	total.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.0))
	total.add_theme_constant_override("outline_size", 6)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total.mouse_filter = Control.MOUSE_FILTER_IGNORE
	total.z_index = 30
	total.text = "0 gold"
	machine.add_child(total)
	var middle := _center_of(machine, cells)
	total.size = Vector2(140, 22)
	total.position = middle - total.size * 0.5
	total.pivot_offset = total.size * 0.5
	total.scale = Vector2.ZERO
	total.create_tween().tween_property(total, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await machine.wait(0.25)
	var gold := 0
	var flyers := 0
	for i in cells.size():
		var prize: HoardPrize = hoard.prizes[cells[i]]
		if prize.gold <= 0:
			continue
		gold += prize.gold
		if flyers < MAX_TALLY_COINS:
			flyers += 1
			Fx.fly_icon(machine, COIN_TEXTURE, machine.cell_center(cells[i].x, cells[i].y),
				machine.global_position + middle, 0.35, 10.0)
		total.text = "%d gold" % gold
		Fx.pop(total, 1.15, 0.1)
		Audio.play(&"coin", minf(0.9 + i * 0.04, 1.9), -8.0)
		await machine.wait(TALLY_STEP)
	if grand:
		gold += grand.gold
		total.text = "%d gold" % gold
	var bonus := GameState.stat(Stats.HOARD_GOLD_BONUS)
	if bonus > 0.0:
		await machine.wait(0.2)
		gold = roundi(gold * (1.0 + bonus))
		total.text = "%d gold (+%d%%)" % [gold, roundi(bonus * 100.0)]
	Fx.pop(total, 1.5, 0.3)
	Fx.burst(machine, middle, GOLD, 24, 90.0, COIN_TEXTURE, 0.8, 200.0)
	Audio.play(&"win", 1.0, -4.0)
	await machine.wait(0.7)
	var fade := total.create_tween()
	fade.tween_property(total, "modulate:a", 0.0, 0.3)
	fade.tween_callback(total.queue_free)


## `at`: a cell (Vector2i) or a point in the machine's own space (Vector2).
func _burst(machine: SlotMachine, cell: Vector2i, color: Color, amount: int, speed: float, texture: Texture2D = null) -> void:
	Fx.burst(machine, _local(machine, cell), color, amount, speed, texture, 0.6, 160.0)


func _float(machine: SlotMachine, at: Variant, text: String, color: Color, font_size: int) -> void:
	var point: Vector2 = _local(machine, at) if at is Vector2i else at
	FloatingText.spawn(machine, text, point + Vector2(0, -12), color, font_size)


func _local(machine: SlotMachine, cell: Vector2i) -> Vector2:
	return machine.cell_center(cell.x, cell.y) - machine.global_position


## Middle of some cells, in the machine's own space.
func _center_of(machine: SlotMachine, cells: Array) -> Vector2:
	if cells.is_empty():
		return machine.size * 0.5
	var sum := Vector2.ZERO
	for cell: Vector2i in cells:
		sum += _local(machine, cell)
	var count := cells.size()
	# Centre of the whole reel area reads better than the centre of the chests.
	var first := _local(machine, Vector2i(0, 0))
	var last := _local(machine, Vector2i(machine.grid.size() - 1, machine.rows - 1))
	return ((first + last) * 0.5).lerp(sum / count, 0.25)


## Just above the middle of the top row, in the machine's own space.
func _above_reels(machine: SlotMachine) -> Vector2:
	var left := _local(machine, Vector2i(0, 0))
	var right := _local(machine, Vector2i(machine.grid.size() - 1, 0))
	return (left + right) * 0.5 + Vector2(0, -6)


func _prize_color(prize: HoardPrize) -> Color:
	if prize.is_jackpot():
		return LineOverlay.JACKPOT_COLORS.get(prize.short_text(), GOLD)
	if prize.troops > 0:
		return TROOP_COLOR
	if prize.repair != 0:
		return REPAIR_COLOR
	return GOLD


func _prize_text(prize: HoardPrize) -> String:
	if prize.is_jackpot():
		return "%s!" % prize.short_text()
	if prize.troops > 0:
		return "+%d %s" % [prize.troops, prize.unit_symbol.unit.display_name if prize.unit_symbol and prize.unit_symbol.unit else "troops"]
	if prize.repair != 0:
		return "+%d HP" % prize.repair
	return "+%d gold" % prize.gold


## Left to right, then top to bottom.
static func _reading_order(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


## Troop symbols on the player's reels (hoard troop chests summon these).
static func _unit_symbols() -> Array:
	var result := []
	for id: StringName in GameState.pool:
		var symbol := GameState.get_symbol(id)
		if symbol.effect == SymbolData.Effect.SPAWN_UNIT and symbol.unit:
			result.append(symbol)
	return result


## Gold of a 3-coin line at the coin's current level: chests scale with it.
static func _coin_power() -> int:
	var coin := GameState.get_symbol(COIN_ID)
	return coin.reward_amount(3, GameState.level_of(COIN_ID)) if coin else 5
