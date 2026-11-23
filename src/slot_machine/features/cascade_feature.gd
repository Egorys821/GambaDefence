class_name CascadeFeature
extends MachineFeature
## Shifting Halls: winning symbols vanish, the rest fall down and new ones
## drop in. New wins pay with a growing chain multiplier, until nothing wins.

## Hard cap on chain length so a spin always ends quickly. Also a balance
## knob: long chains with Echo Chain carry most of the maxed-upgrade value.
const MAX_CASCADES := 4


## The first cascade pays x1, then each one adds Stats.CASCADE_STEP.
static func chain_multiplier(chain: int) -> int:
	return 1 + (chain - 1) * GameState.stat_int(Stats.CASCADE_STEP)


## Every cell that took part in any of the wins.
static func winning_cells(wins: Array[SlotWin]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for win in wins:
		for cell in win.cells:
			if cell not in cells:
				cells.append(cell)
	return cells


func after_spin(machine: SlotMachine, wins: Array[SlotWin]) -> void:
	var current := wins
	var chain := 0
	while not current.is_empty() and chain < MAX_CASCADES:
		chain += 1
		var cells := winning_cells(current)
		await machine.explode(cells)
		await machine.cascade_to(GridOps.collapse(machine.grid, cells, GameState.roll_symbol))
		current = machine.evaluate(machine.grid)
		if current.is_empty():
			break
		var multiplier := chain_multiplier(chain)
		machine.set_status("Chain %d: x%d" % [chain, multiplier])
		machine.cabinet.set_chain(chain)
		for win in current:
			win.extra_mult *= multiplier
		await machine.present(current)
	if chain >= 2:
		machine.announce("%d CASCADES!" % chain, Color("#40d8f0"))
