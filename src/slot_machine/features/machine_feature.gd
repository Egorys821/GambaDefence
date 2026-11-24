class_name MachineFeature
extends RefCounted
## A machine style's bonus feature. After the base spin is evaluated and
## presented, the SlotMachine hands control to its feature, which may spin
## again, ask the player something or add more wins through the machine's
## feature API (spin_to, present, ask, announce...). The base class does nothing.


static func create(style: MachineStyle) -> MachineFeature:
	match style.feature:
		MachineStyle.Feature.GAMBLE:
			return GambleFeature.new()
		MachineStyle.Feature.NUDGE:
			return NudgeFeature.new()
		MachineStyle.Feature.FREE_SPINS:
			return FreeSpinsFeature.new()
		MachineStyle.Feature.HOLD_AND_WIN:
			return HoardFeature.new()
		MachineStyle.Feature.CASCADE:
			return CascadeFeature.new()
	return MachineFeature.new()


## Runs after the base spin's wins were presented. May await.
func after_spin(_machine: SlotMachine, _wins: Array[SlotWin]) -> void:
	pass


## Extra suspense before reel `reels` (e.g. one scatter short of the feature).
## True when this spin starts the feature right away: its line wins are paid
## without the line-by-line animation (Dragon's Hoard goes straight to the round).
func skips_win_show(_grid: Array) -> bool:
	return false


func wants_tease(_grid: Array, _reels: int) -> bool:
	return false


## True if the first `reels` reels show `symbol` at least `needed - 1` times
## and a later reel could bring the last one.
static func one_short(grid: Array, symbol: SymbolData, needed: int, reels: int) -> bool:
	if symbol == null or reels >= grid.size():
		return false
	return GridOps.count(grid.slice(0, reels), symbol) >= needed - 1
