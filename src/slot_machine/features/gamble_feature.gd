class_name GambleFeature
extends MachineFeature
## Jester's 81 "Fool's Gamble": after a spin that paid gold, guess the colour
## of a face-down card. Right doubles the spin's gold, wrong loses all of it.
## Only gold is ever at risk. Collect (Space) is always the safe answer.

const MAX_STEPS := 5
const BASE_CHANCE := 0.5
const RED := Color("#ff5050")
const BLACK := Color("#c0c0d0")


static func win_chance() -> float:
	return BASE_CHANCE + GameState.stat(Stats.GAMBLE_EDGE)


## The colour shown for a guess (0 = red, 1 = black) and its outcome.
static func card_is_red(guess: int, guessed_right: bool) -> bool:
	return (guess == 0) == guessed_right


func after_spin(machine: SlotMachine, wins: Array[SlotWin]) -> void:
	var stake := 0
	for win in wins:
		stake += win.gold()
	if stake <= 0:
		return
	var cells := wins[-1].cells
	for _step in MAX_STEPS:
		var guess := await machine.ask("Gamble %d gold? Guess the card." % stake, ["Red", "Black", "Collect"])
		if guess == 2:
			return
		var right := randf() < win_chance()
		var red := card_is_red(guess, right)
		machine.announce("RED!" if red else "BLACK!", RED if red else BLACK)
		await machine.wait(0.5)
		if right:
			await machine.present([SlotWin.prize(SymbolData.Effect.GOLD, stake, wins[-1].symbol, cells, "Gamble won: x2")])
			stake *= 2
		else:
			await machine.present([SlotWin.prize(SymbolData.Effect.GOLD, -stake, wins[-1].symbol, cells, "Gamble lost")])
			return
