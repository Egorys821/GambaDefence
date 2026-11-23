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
## With no spins left, the first Space press highlights "Face the Night",
## the second one starts the night.
var _night_armed := false
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
	_slot_machine.won.connect(_on_won)
	_slot_machine.announced.connect(_on_announced)
	_slot_machine.spin_finished.connect(_on_spin_finished)
	GameState.machine_changed.connect(_on_machine_changed)
	GameState.upgrades_changed.connect(_on_upgrades_changed)


func begin_day() -> void:
	_slot_machine.configure()
	_slot_machine.skin.style_button(_spin_button)
	_spins_today = GameState.spins_per_day()
	_spins_left = _spins_today
	_disarm_night_button()
	_shop.restock()
	_refresh_buttons()
	show()
	for panel: Control in _panels:
		var rest: Vector2 = _rest_positions[panel]
		panel.position = rest + _panels[panel] * _slide_distance(panel)
		create_tween().tween_property(panel, "position", rest, SLIDE_TIME) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Screen rectangles of the day UI, for the tutorial highlights.
func tutorial_rects() -> Dictionary:
	return {
		"machine": (%MachinePanel as Control).get_global_rect(),
		"paytable": _paytable.get_global_rect(),
		"merchant": (%ShopPanel as Control).get_global_rect(),
		"night": _start_night_button.get_global_rect(),
	}


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


## Space spins; once the spins are used up it first highlights "Face the
## Night" and a second press starts the night.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo() or (event as InputEventKey).keycode != KEY_SPACE:
		return
	get_viewport().set_input_as_handled()
	if _slot_machine.is_awaiting_choice():
		_slot_machine.decline_choice()  # Space = the safe answer (Collect, Skip)
		return
	if is_busy():
		return
	if _spins_left > 0:
		_on_spin_pressed()
	elif not _night_armed:
		_arm_night_button()
	else:
		_on_start_night_pressed()


func _arm_night_button() -> void:
	_night_armed = true
	Audio.play(&"click", 1.3)
	_start_night_button.text = "Press Space again: Face the Night"
	_start_night_button.pivot_offset = _start_night_button.size * 0.5
	Fx.pop(_start_night_button, 1.1, 0.25)
	_start_night_button.modulate = Color(1.4, 1.25, 0.8)


func _on_spin_pressed() -> void:
	if _spins_left <= 0 or is_busy():
		return
	_spins_left -= 1
	Fx.pop(_spin_button, 0.92, 0.15)
	_slot_machine.spin()
	_refresh_buttons()


## True while the machine is spinning or presenting wins.
func is_busy() -> bool:
	return _slot_machine.is_spinning


func _on_start_night_pressed() -> void:
	if is_busy():
		return
	Audio.play(&"click")
	night_requested.emit()


func _on_machine_changed() -> void:
	_slot_machine.configure()
	_slot_machine.skin.style_button(_spin_button)
	_refresh_buttons()


# --- Rewards ------------------------------------------------------------------

## Symbols like coins pay a little just for landing anywhere.
func _on_symbols_landed(grid: Array, cells: Array[Vector2i]) -> void:
	var total := 0
	var delay := 0.0
	var threat := 0
	for cell in cells:
		var symbol: SymbolData = grid[cell.x][cell.y]
		var at := _slot_machine.cell_center(cell.x, cell.y)
		if symbol.passive_threat > 0:
			threat += symbol.passive_threat
			_popup("+%d spirit" % symbol.passive_threat, at, CURSE_COLOR, 7)
		if symbol.passive_gold <= 0:
			continue
		total += symbol.passive_gold
		_fly_coins(1, at, delay, 0.95 + total * 0.03)
		delay += 0.04
	GameState.add_gold(total)
	if threat > 0:
		GameState.add_curse_threat(threat)
		Audio.play(&"spirit_death", 0.7, -6.0)


func _on_won(win: SlotWin, _index: int) -> void:
	var symbol := win.symbol
	var cell := win.last_cell()
	var last_cell := _slot_machine.cell_center(cell.x, cell.y)
	var amount := win.amount()
	var popup_size := 9 + clampi(win.count - 3, 0, 3) * 3
	_paytable.flash(symbol.id)
	# Says exactly what won: which line, how many, and the reward.
	_popup(win.headline(), last_cell + Vector2(0, -26), win.color, 7)
	match win.effect():
		SymbolData.Effect.GOLD, SymbolData.Effect.WILD:
			GameState.add_gold(amount)
			if amount < 0:
				_popup("%d gold" % amount, last_cell + Vector2(0, -14), CURSE_COLOR, popup_size)
				Audio.play(&"denied")
				return
			_popup("+%d gold!" % amount, last_cell + Vector2(0, -14), GOLD_COLOR, popup_size)
			_fly_coins(mini(amount, MAX_FLYING_COINS), last_cell, 0.1, 1.0)
		SymbolData.Effect.SPAWN_UNIT:
			_popup("+%d %s!" % [amount, symbol.unit.display_name], last_cell + Vector2(0, -14), TROOP_COLOR, popup_size)
			var tween := Fx.fly_icon(self, symbol.texture, last_cell, battlefield.gate_screen_position(), 0.55, 18.0)
			tween.finished.connect(troops_requested.emit.bind(symbol.unit, amount, GameState.power_for(symbol.id)))
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


func _on_spin_finished(wins: Array[SlotWin]) -> void:
	_refresh_buttons()
	var best := 0
	for win in wins:
		best = maxi(best, win.count)
	if best >= 5:
		_celebrate("MEGA WIN!", 3)
	elif best >= 4 or wins.size() >= 3:
		_celebrate("BIG WIN!", 2)


## Banner, coin fountain and shake for big spins.
func _celebrate(title: String, strength: int) -> void:
	Audio.play(&"big_win")
	var machine_center := _slot_machine.global_position + _slot_machine.size * 0.5
	Fx.burst(self, machine_center - global_position, Color.WHITE, 16 * strength, 160.0, COIN_TEXTURE, 1.3, 380.0)
	Fx.shake_control(_slot_machine, 3.0 * strength, 0.4)
	if battlefield:
		battlefield.shake(1.5 * strength, 0.4)
	_show_banner(title, 22 + strength * 6, GOLD_COLOR)


## The machine calls out a feature ("FREE SPINS!", "81 WAYS!").
func _on_announced(text: String, color: Color) -> void:
	_show_banner(text, 20, color)


func _show_banner(title: String, font_size: int, color: Color) -> void:
	var banner := Label.new()
	banner.text = title
	banner.add_theme_font_size_override("font_size", font_size)
	banner.add_theme_color_override("font_color", color)
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

func _disarm_night_button() -> void:
	_night_armed = false
	_start_night_button.modulate = Color.WHITE


func _refresh_buttons() -> void:
	_spin_button.disabled = _spins_left <= 0 or is_busy()
	_spin_button.text = "SPIN  %d / %d" % [_spins_left, _spins_today]
	_start_night_button.disabled = is_busy()
	if _spins_left > 0:
		_disarm_night_button()
	if not _night_armed:
		_start_night_button.text = "Face the Night" if _spins_left == 0 else "Face the Night (%d left)" % _spins_left
