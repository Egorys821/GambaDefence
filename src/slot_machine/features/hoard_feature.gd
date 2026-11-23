class_name HoardFeature
extends MachineFeature
## Dragon's Hoard: enough chests anywhere start a hold-and-win round. Chests
## lock with a prize, the other cells empty out and respin on their own (see
## HoardRound). Filling every cell adds the Grand prize.

const COIN_ID := &"coin"

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

	machine.announce("DRAGON'S HOARD!", Color("#30c070"))
	machine.cabinet.set_hoard_mode(true)
	await machine.enter_cell_mode(chest, _empty)
	for cell in start:
		hoard.lock(cell, roll_prize.call())
		machine.lock_cell(cell, hoard.prizes[cell].short_text())
	while not hoard.is_over():
		machine.set_status("Respins: %d" % hoard.respins_left)
		machine.cabinet.set_respins(hoard.respins_left, hoard.max_respins)
		var empty := hoard.empty_cells()
		var landed := hoard.respin(hoard.chest_chance(), rng, roll_prize)
		var targets := {}
		for cell in empty:
			targets[cell] = chest if cell in landed else _empty
		await machine.spin_cells(targets)
		for cell in landed:
			machine.lock_cell(cell, hoard.prizes[cell].short_text())
			Audio.play(&"coin", 1.2)
		machine.cabinet.set_respins(hoard.respins_left, hoard.max_respins)
	machine.set_status("")
	var grand: HoardPrize = null
	if hoard.is_full():
		grand = HoardPrize.grand(units, rng)
		machine.announce("GRAND HOARD!", Color("#f8d038"))
	await machine.wait(0.4)
	await machine.present(hoard.payout(chest, GameState.castle_max_hp, grand, GameState.stat(Stats.HOARD_GOLD_BONUS)))
	await machine.wait(0.6)
	machine.cabinet.set_hoard_mode(false)
	machine.exit_cell_mode()


func wants_tease(grid: Array, reels: int) -> bool:
	return MachineFeature.one_short(grid, GameState.machine.feature_symbol, GameState.feature_trigger(), reels)


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
