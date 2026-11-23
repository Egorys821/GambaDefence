class_name FreeSpinsFeature
extends MachineFeature
## Tome of Ages: enough Tomes (wild + scatter) anywhere pay a scatter prize and
## start free spins. One random symbol is picked to expand: whenever it shows
## on enough reels it fills them and pays on every line (see BookExpansion).
## More Tomes during free spins add more spins. Free spins don't use up the
## day's spins, but curses that land still count.

## Retriggers stop adding spins past this many in one feature.
const MAX_FREE_SPINS := 20


## Gold for `count` scatters starting (or adding) free spins.
static func scatter_gold(scatter: SymbolData, count: int) -> int:
	return scatter.power * (count - 2) + GameState.stat_int(Stats.TOME_SCATTER_BONUS) * count


## Free spins left after a retrigger, never past MAX_FREE_SPINS in total.
static func retrigger(spins_left: int, played: int) -> int:
	return mini(spins_left + GameState.feature_length(), MAX_FREE_SPINS - played)


func after_spin(machine: SlotMachine, _wins: Array[SlotWin]) -> void:
	var scatter := machine.style.feature_symbol
	if not await _pay_scatter(machine, scatter):
		return
	var symbol := BookExpansion.pick_symbol(_pool_symbols())
	var min_reels := BookExpansion.MIN_REELS - GameState.stat_int(Stats.EXPAND_EASE)
	var spins_left := GameState.feature_length()
	var played := 0
	machine.announce("FREE SPINS! %s expands" % (symbol.display_name if symbol else "Nothing"))
	machine.cabinet.set_free_spins(spins_left, played, symbol)
	await machine.wait(1.0)
	while spins_left > 0:
		spins_left -= 1
		played += 1
		machine.set_status("Free spin %d" % played)
		machine.cabinet.set_free_spins(spins_left, played, symbol)
		await machine.spin_to(machine.roll_grid())
		await machine.present(machine.evaluate(machine.grid))
		if symbol:
			var expansion := BookExpansion.evaluate(machine.grid, symbol, GameState.active_paylines().size(), min_reels)
			if expansion:
				await machine.show_grid(BookExpansion.expanded_grid(machine.grid, symbol))
				await machine.present([expansion])
		if await _pay_scatter(machine, scatter) and played + spins_left < MAX_FREE_SPINS:
			var before := spins_left
			spins_left = retrigger(spins_left, played)
			machine.announce("+%d FREE SPINS!" % (spins_left - before))
			machine.cabinet.set_free_spins(spins_left, played, symbol)
	machine.set_status("")
	machine.cabinet.end_free_spins()


func wants_tease(grid: Array, reels: int) -> bool:
	return MachineFeature.one_short(grid, GameState.machine.feature_symbol, GameState.feature_trigger(), reels)


## Pays the scatter prize if enough Tomes landed. Returns true if it did.
func _pay_scatter(machine: SlotMachine, scatter: SymbolData) -> bool:
	var count := machine.style.feature_symbols_on(machine.grid)
	if count < GameState.feature_trigger():
		return false
	var gold := scatter_gold(scatter, count)
	var cells := GridOps.cells_of(machine.grid, scatter)
	await machine.present([SlotWin.prize(SymbolData.Effect.GOLD, gold, scatter, cells, "%d %ss" % [count, scatter.display_name])])
	return true


static func _pool_symbols() -> Array:
	var result := []
	for id: StringName in GameState.pool:
		result.append(GameState.get_symbol(id))
	return result
