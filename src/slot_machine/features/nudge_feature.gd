class_name NudgeFeature
extends MachineFeature
## Old Cellar's classic nudge: sometimes after a losing spin the player may
## shift one reel down a row to try for a win.


func after_spin(machine: SlotMachine, wins: Array[SlotWin]) -> void:
	if not wins.is_empty() or randf() >= GameState.stat(Stats.NUDGE_CHANCE):
		return
	machine.announce("NUDGE!", Color("#80f060"))
	var options: Array[String] = []
	for reel in machine.grid.size():
		options.append("Reel %d" % (reel + 1))
	options.append("Skip")
	var choice := await machine.ask("Nudge a reel down one row?", options)
	if choice >= machine.grid.size():
		return
	await machine.nudge_reel(choice, GameState.roll_symbol())
	await machine.present(machine.evaluate(machine.grid))
