class_name DayPhase
extends Control
## Day: spin the slot machine, turn winning lines into rewards, visit the shop.
## Rewards are applied with effects as the slot machine presents each line.

signal troops_requested(unit: UnitData, count: int, power: float)
signal night_requested

const GOLD_COLOR := Color("#f8d038")
const TROOP_COLOR := Color("#80d0ff")
const REPAIR_COLOR := Color("#80f060")
const CURSE_COLOR := Color("#ff4050")
const COIN_TEXTURE := preload("res://assets/sprites/symbols/coin.png")
const SLIDE_TIME := 0.45
## At most this many coins fly per line (bigger rewards still pay in full).
const MAX_FLYING_COINS := 10

## Set by Main: used to aim flying coins and troop icons.
var hud: Hud
var battlefield: Battlefield

var _spins_left := 0
## Spins granted today (grows if an Extra Spin is bought mid-day).
var _spins_today := 0
## Free spins won from Lucky Clover lines, played automatically.
var _free_spins := 0
var _auto_spinning := false
## Panel -> resting position (they slide off screen at night).
var _rest_positions: Dictionary = {}

@onready var _slot_machine: SlotMachine = %SlotMachine
@onready var _spin_button: Button = %SpinButton
@onready var _paytable: Paytable = %Paytable
@onready var _shop: Shop = %Shop
@onready var _start_night_button: Button = %StartNightButton
## Each panel and the direction it slides away in.
@onready var _panels := {
	%Paytable: Vector2.LEFT,
	%MachinePanel: Vector2.DOWN,
	%ShopPanel: Vector2.RIGHT,
}


func _ready() -> void:
	for panel: Control in _panels:
		_rest_positions[panel] = panel.position
	_spin_button.pressed.connect(_on_spin_pressed)
	_start_night_button.pressed.connect(_on_start_night_pressed)
	_slot_machine.symbols_landed.connect(_on_symbols_landed)
	_slot_machine.line_won.connect(_on_line_won)
	_slot_machine.spin_finished.connect(_on_spin_finished)
	GameState.machine_changed.connect(_on_machine_changed)
	GameState.upgrades_changed.connect(_on_upgrades_changed)


func begin_day() -> void:
	_slot_machine.configure(GameState.machine_rows)
	_spins_today = GameState.spins_per_day()
	_spins_left = _spins_today
	_shop.restock()
	_refresh_buttons()
	show()
	for panel: Control in _panels:
		var rest: Vector2 = _rest_positions[panel]
		panel.position = rest + _panels[panel] * _slide_distance(panel)
		create_tween().tween_property(panel, "position", rest, SLIDE_TIME) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func slide_out() -> void:
	var tween := create_tween().set_parallel()
	for panel: Control in _panels:
		var target: Vector2 = _rest_positions[panel] + _panels[panel] * _slide_distance(panel)
		tween.tween_property(panel, "position", target, SLIDE_TIME) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	hide()


func _on_upgrades_changed() -> void:
	var total := GameState.spins_per_day()
	_spins_left = maxi(0, _spins_left + total - _spins_today)
	_spins_today = total
	_refresh_buttons()


func _slide_distance(panel: Control) -> float:
	return (panel.size.x if _panels[panel].x != 0.0 else panel.size.y) + 8.0


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_SPACE:
		_on_spin_pressed()
		get_viewport().set_input_as_handled()


func _on_spin_pressed() -> void:
	if _spins_left <= 0 or is_busy():
		return
	_spins_left -= 1
	Fx.pop(_spin_button, 0.92, 0.15)
	_slot_machine.spin()
	_refresh_buttons()


## True while the machine spins or free spins are still queued.
func is_busy() -> bool:
	return _slot_machine.is_spinning or _free_spins > 0 or _auto_spinning


func _on_start_night_pressed() -> void:
	if is_busy():
		return
	Audio.play(&"click")
	night_requested.emit()


func _on_machine_changed() -> void:
	_slot_machine.configure(GameState.machine_rows)
	_refresh_buttons()


# --- Rewards ------------------------------------------------------------------

## Symbols like coins pay a little just for landing anywhere.
func _on_symbols_landed(grid: Array) -> void:
	var total := 0
	var delay := 0.0
	var threat := 0
	for reel in grid.size():
		for row in grid[reel].size():
			var symbol: SymbolData = grid[reel][row]
			if symbol.passive_threat > 0:
				threat += symbol.passive_threat
				_popup("+%d spirit" % symbol.passive_threat, _slot_machine.cell_center(reel, row), CURSE_COLOR, 7)
			if symbol.passive_gold <= 0:
				continue
			total += symbol.passive_gold
			_fly_coins(1, _slot_machine.cell_center(reel, row), delay, 0.95 + total * 0.03)
			delay += 0.04
	GameState.add_gold(total)
	if threat > 0:
		GameState.add_curse_threat(threat)
		Audio.play(&"spirit_death", 0.7, -6.0)


func _on_line_won(win: LineWin, _index: int) -> void:
	var symbol := win.symbol
	var level := GameState.level_of(symbol.id)
	var line_rows := Paylines.rows_of(win.payline)
	var last_cell := _slot_machine.cell_center(win.count - 1, line_rows[win.count - 1])
	var amount := symbol.reward_amount(win.count, level)
	var popup_size := 9 + (win.count - 3) * 3
	_paytable.flash(symbol.id)
	# Says exactly what won: which line, how many, and the reward.
	var headline := "%s: %dx %s" % [Paylines.name_of(win.payline), win.count, symbol.display_name]
	_popup(headline, last_cell + Vector2(0, -26), Paylines.color_of(win.payline), 7)
	match symbol.effect:
		SymbolData.Effect.GOLD, SymbolData.Effect.WILD:
			GameState.add_gold(amount)
			_popup("+%d gold!" % amount, last_cell + Vector2(0, -14), GOLD_COLOR, popup_size)
			_fly_coins(mini(amount, MAX_FLYING_COINS), last_cell, 0.1, 1.0)
		SymbolData.Effect.SPAWN_UNIT:
			_popup("+%d %s!" % [amount, symbol.unit.display_name], last_cell + Vector2(0, -14), TROOP_COLOR, popup_size)
			var tween := Fx.fly_icon(self, symbol.texture, last_cell, battlefield.gate_screen_position(), 0.55, 18.0)
			tween.finished.connect(troops_requested.emit.bind(symbol.unit, amount, GameState.power_for(symbol.id)))
		SymbolData.Effect.RESPIN:
			_free_spins += amount
			_popup("FREE SPIN x%d!" % amount, last_cell + Vector2(0, -14), Color("#80ff80"), popup_size)
		SymbolData.Effect.CURSE:
			GameState.add_curse_threat(amount)
			_popup("CURSED! +%d spirits tonight" % amount, last_cell + Vector2(0, -14), CURSE_COLOR, popup_size)
			Fx.shake_control(_slot_machine, 4.0, 0.35)
		SymbolData.Effect.REPAIR:
			_popup("+%d castle HP" % amount, last_cell + Vector2(0, -14), REPAIR_COLOR, popup_size)
			var tween := Fx.fly_icon(self, symbol.texture, last_cell, battlefield.castle_screen_position(), 0.55, 18.0)
			tween.finished.connect(_on_repair_arrived.bind(amount))


func _on_repair_arrived(amount: int) -> void:
	GameState.repair_castle(amount)
	Audio.play(&"buy", 0.8)


func _on_spin_finished(wins: Array[LineWin], _grid: Array) -> void:
	_refresh_buttons()
	if _free_spins > 0:
		_play_free_spin()
	var best := 0
	for win in wins:
		best = maxi(best, win.count)
	if best >= 5:
		_celebrate("MEGA WIN!", 3)
	elif best >= 4 or wins.size() >= 3:
		_celebrate("BIG WIN!", 2)


## Plays one queued free spin after a short pause (does not use a spin).
func _play_free_spin() -> void:
	_auto_spinning = true
	_free_spins -= 1
	_refresh_buttons()
	await get_tree().create_timer(0.7).timeout
	_popup("FREE SPIN", _slot_machine.global_position + Vector2(_slot_machine.size.x * 0.5, -6), Color("#80ff80"), 12)
	Audio.play(&"spin", 1.3)
	_auto_spinning = false
	_slot_machine.spin()
	_refresh_buttons()


## Banner, coin fountain and shake for big spins.
func _celebrate(title: String, strength: int) -> void:
	Audio.play(&"big_win")
	var machine_center := _slot_machine.global_position + _slot_machine.size * 0.5
	Fx.burst(self, machine_center - global_position, Color.WHITE, 16 * strength, 160.0, COIN_TEXTURE, 1.3, 380.0)
	Fx.shake_control(_slot_machine, 3.0 * strength, 0.4)
	if battlefield:
		battlefield.shake(1.5 * strength, 0.4)

	var banner := Label.new()
	banner.text = title
	banner.add_theme_font_size_override("font_size", 22 + strength * 6)
	banner.add_theme_color_override("font_color", GOLD_COLOR)
	banner.add_theme_color_override("font_outline_color", Color("#5a2a08"))
	banner.add_theme_constant_override("outline_size", 8)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.z_index = 50
	add_child(banner)
	banner.reset_size()
	banner.pivot_offset = banner.size * 0.5
	# Centred over the castle view, above the machine.
	banner.position = Vector2(size.x * 0.5, 100.0) - banner.size * 0.5
	banner.scale = Vector2.ZERO
	var tween := banner.create_tween()
	tween.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "rotation", deg_to_rad(-4), 0.12)
	tween.tween_property(banner, "rotation", deg_to_rad(4), 0.24)
	tween.tween_property(banner, "rotation", 0.0, 0.12)
	tween.tween_interval(0.5)
	tween.tween_property(banner, "modulate:a", 0.0, 0.4)
	tween.tween_callback(banner.queue_free)


func _fly_coins(count: int, from_global: Vector2, delay: float, pitch: float) -> void:
	if hud == null:
		return
	var target := hud.gold_icon_center()
	for i in count:
		var start := from_global + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		var tween := Fx.fly_icon(self, COIN_TEXTURE, start, target, 0.5 + randf() * 0.15, 12.0, delay + i * 0.05)
		tween.finished.connect(_on_coin_arrived.bind(pitch + i * 0.02))


func _on_coin_arrived(pitch: float) -> void:
	Audio.play(&"coin", pitch, -4.0)
	hud.bump_gold()


func _popup(message: String, global_at: Vector2, color: Color, font_size: int) -> void:
	FloatingText.spawn(self, message, global_at - global_position, color, font_size)


# --- UI -------------------------------------------------------------------------

func _refresh_buttons() -> void:
	_spin_button.disabled = _spins_left <= 0 or is_busy()
	_spin_button.text = "SPIN  %d / %d" % [_spins_left, _spins_today]
	_start_night_button.disabled = is_busy()
	_start_night_button.text = "Face the Night" if _spins_left == 0 else "Face the Night (%d left)" % _spins_left
