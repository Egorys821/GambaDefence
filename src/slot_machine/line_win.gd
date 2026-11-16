class_name LineWin
extends RefCounted
## A winning payline produced by a spin.

var payline: int
var symbol: SymbolData
## How many reels matched, counted from the left (3..5).
var count: int


func _init(p_payline: int, p_symbol: SymbolData, p_count: int) -> void:
	payline = p_payline
	symbol = p_symbol
	count = p_count


func multiplier() -> int:
	return Paylines.MATCH_MULTIPLIER.get(count, 1)
