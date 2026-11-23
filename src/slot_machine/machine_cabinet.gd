class_name MachineCabinet
extends Control
## The body of the slot machine around the reels, dressed by its MachineSkin:
## frame, marquee (the machine's name, or the status text while a feature
## runs), crest, side panels with the feature's counters, ornaments with small
## idle animations (bulbs, lever, candles, runes, dragon...) and win flashes.
##
## The SlotMachine adds the cabinet behind its reels and `front`, a second
## layer, above them (reel separators, expanded reels, nudge arrows).
## Features drive the side panels through the methods under "Feature panels".

## Pressed a nudge arrow over a reel.
signal reel_chosen(reel: int)

## The frame reaches this far outside the machine's panel.
const FRAME_GROW := 3
const WING_GAP := 3
const MARQUEE_HEIGHT := 20
const LIT_COLOR := Color("#fff4c0")
const DIM := Color(0.45, 0.45, 0.5)

var skin: MachineSkin
var style: MachineStyle
## Drawn above the reels.
var front: Control

var _reel_rect := Rect2()
var _cell_size := 40
var _time := 0.0
var _spin_boost := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
## Feature "mode" (free spins, hoard round): the cabinet glows.
var _mode_glow := 0.0
var _status := ""

var _deco: Control
var _frame: NinePatchRect
var _marquee: NinePatchRect
var _title: Label
var _crest: TextureRect
var _crest_rest := Vector2.ZERO
var _lever_arm: TextureRect
var _dragon_wings: Array[TextureRect] = []
var _smoke: Array[Dictionary] = []
var _next_smoke := 2.0
var _candles: Array[TextureRect] = []
var _runes: Array[Dictionary] = []
var _rune_flash := 0.0
var _left: NinePatchRect
var _right: NinePatchRect
## Feature panel widgets, by name.
var _ui: Dictionary = {}
## Overlays above the reels: expanded reels and reel flashes.
var _expanded: Array[Rect2] = []
var _reel_flashes: Array[Dictionary] = []
var _arrows: Array[Button] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	front = Control.new()
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.draw.connect(_draw_front)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_spin_boost = maxf(0.0, _spin_boost - delta)
	_flash = maxf(0.0, _flash - delta * 1.6)
	_rune_flash = maxf(0.0, _rune_flash - delta * 1.5)
	_animate(delta)
	if _deco:
		_deco.queue_redraw()
	front.queue_redraw()


## Rebuilds the cabinet for `p_style` around a machine panel of `machine_size`
## whose reels fill `reel_rect`.
func build(p_style: MachineStyle, machine_size: Vector2, reel_rect: Rect2, cell_size: int) -> void:
	style = p_style
	skin = MachineSkin.for_style(style)
	size = machine_size
	front.size = machine_size
	_reel_rect = reel_rect
	_cell_size = cell_size
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_ui.clear()
	_dragon_wings.clear()
	_candles.clear()
	_runes.clear()
	_smoke.clear()
	_expanded.clear()
	_reel_flashes.clear()
	_clear_arrows()
	_lever_arm = null
	_left = null
	_right = null
	_mode_glow = 0.0
	if skin.has(MachineSkin.Ornament.DRAGON):
		_build_dragon_wings()
	_build_frame()
	_build_marquee()
	if skin.has(MachineSkin.Ornament.COBWEB):
		var web := _sprite(MachineSkin.part("cobweb"), Vector2(-FRAME_GROW + 1, -FRAME_GROW + 1))
		web.modulate.a = 0.8
	if skin.has(MachineSkin.Ornament.CANDLES):
		for x: float in [-FRAME_GROW + 1.0, size.x + FRAME_GROW - 7.0]:
			_candles.append(_sprite(MachineSkin.part("candle"), Vector2(x, -FRAME_GROW - 13)))
	if skin.has(MachineSkin.Ornament.LEVER):
		_build_lever()
	if skin.has(MachineSkin.Ornament.RUNES):
		_place_runes()
	_build_feature_panels()
	# Ornaments drawn over the frame (bulbs, flames, eyes, glints).
	_deco = Control.new()
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.size = size
	_deco.draw.connect(_draw_deco)
	add_child(_deco)
	set_status(_status)
	queue_redraw()


# --- Machine events -------------------------------------------------------------

func on_spin() -> void:
	_spin_boost = 1.2
	_expanded.clear()
	_reel_flashes.clear()
	set_chain(0)
	if _lever_arm:
		var tween := _lever_arm.create_tween()
		tween.tween_property(_lever_arm, "scale:y", -0.7, 0.12).set_ease(Tween.EASE_IN)
		tween.tween_property(_lever_arm, "scale:y", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func on_win(color: Color) -> void:
	_flash = 1.0
	_flash_color = color
	if _crest:
		_crest.pivot_offset = _crest.size * Vector2(0.5, 1.0)
		Fx.pop(_crest, 1.25, 0.25)


## Marquee text; empty shows the machine's name.
func set_status(text: String) -> void:
	_status = text
	if _title == null:
		return
	_title.text = (text if text != "" else style.display_name).to_upper()
	_title.add_theme_color_override("font_color", skin.text_color if text == "" else skin.status_color)
	if text != "":
		_title.pivot_offset = _title.size * 0.5
		Fx.pop(_title, 1.12, 0.15)


## Ways counted on this spin (0 = a lines spin).
func set_ways(ways: int) -> void:
	if _ui.has("ways_lamp"):
		_set_lamp(_ui["ways_lamp"], ways > 0)
	if _ui.has("ways_count"):
		(_ui["ways_count"] as Label).text = str(ways) if ways > 0 else "-"
		if ways > 0:
			_pop(_ui["ways_count"])


## Removes expanded-reel lights and flashes (a new spin starts).
func clear_overlays() -> void:
	_expanded.clear()
	_reel_flashes.clear()


## Gold light over a reel that just filled with an expanding symbol.
func mark_expanded(rect: Rect2) -> void:
	_expanded.append(rect)


func flash_reel(rect: Rect2, color: Color) -> void:
	_reel_flashes.append({"rect": rect, "color": color, "t": 1.0})


## Cascades: the frame's runes flare up.
func flare() -> void:
	_rune_flash = 1.0


## Shows a down arrow over each reel; pressing one emits reel_chosen.
func offer_reels(count: int) -> void:
	_clear_arrows()
	for i in count:
		var arrow := Button.new()
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.tooltip_text = "Nudge reel %d down" % (i + 1)
		arrow.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		arrow.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		arrow.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		arrow.size = Vector2(_cell_size, _cell_size)
		arrow.position = _reel_rect.position + Vector2(i * _cell_size, 0)
		arrow.pressed.connect(func() -> void: reel_chosen.emit(i))
		front.add_child(arrow)
		_arrows.append(arrow)
	if _ui.has("nudge_lamp"):
		_set_lamp(_ui["nudge_lamp"], true)


func clear_reel_offer() -> void:
	_clear_arrows()
	if _ui.has("nudge_lamp"):
		_set_lamp(_ui["nudge_lamp"], false)


# --- Feature panels -----------------------------------------------------------

## Dragon's Hoard: respins left (eggs) during the round; max <= 0 = idle hint.
func set_respins(left: int, max_respins: int) -> void:
	if not _ui.has("eggs"):
		return
	var eggs: GridContainer = _ui["eggs"]
	(_ui["respin_title"] as Label).text = "RESPINS" if max_respins > 0 else "HOARD"
	(_ui["respin_hint"] as Label).visible = max_respins <= 0
	eggs.visible = max_respins > 0
	if max_respins <= 0:
		return
	if eggs.get_child_count() != max_respins:
		for child in eggs.get_children():
			child.queue_free()
		for i in max_respins:
			var egg := TextureRect.new()
			egg.custom_minimum_size = Vector2(9, 11)
			eggs.add_child(egg)
	var refill := left == max_respins
	for i in eggs.get_child_count():
		var egg := eggs.get_child(i) as TextureRect
		egg.texture = MachineSkin.part("egg_lit" if i < left else "egg_dark")
		if refill:
			egg.pivot_offset = Vector2(4.5, 5.5)
			Fx.pop(egg, 1.4, 0.25)


## Dragon's Hoard: the round is on (wings flap, the cabinet glows).
func set_hoard_mode(on: bool) -> void:
	_mode_glow = 1.0 if on else 0.0
	if not on:
		set_respins(0, 0)


## Dragon's Hoard: a jackpot chest landed.
func flash_jackpot(jackpot_name: String) -> void:
	if _ui.has("jackpot_" + jackpot_name):
		var row: Label = _ui["jackpot_" + jackpot_name]
		_pop(row)
		row.modulate = Color(2, 2, 2)
		row.create_tween().tween_property(row, "modulate", Color.WHITE, 0.8)


## Tome of Ages: free spins running (left = spins to go). `symbol` expands.
func set_free_spins(left: int, played: int, symbol: SymbolData) -> void:
	if not _ui.has("spins"):
		return
	_mode_glow = 1.0
	(_ui["spins_title"] as Label).text = "FREE SPINS"
	var count: Label = _ui["spins"]
	count.text = str(left)
	count.visible = true
	(_ui["spins_hint"] as Label).text = "spin %d" % played if played > 0 else "to play"
	var icon: TextureRect = _ui["expand_icon"]
	if icon.texture != (symbol.texture if symbol else null):
		icon.texture = symbol.texture if symbol else null
		_pop(icon)
	icon.modulate = Color.WHITE
	(_ui["expand_hint"] as Label).text = symbol.display_name if symbol else "nothing"


## Tome of Ages: back to the idle panels.
func end_free_spins() -> void:
	if not _ui.has("spins"):
		return
	_mode_glow = 0.0
	_idle_tome_panels()


## Shifting Halls: chain length (0 = none yet).
func set_chain(chain: int) -> void:
	if not _ui.has("chain_lamps"):
		return
	var lamps: Array = _ui["chain_lamps"]
	for i in lamps.size():
		_set_lamp(lamps[i], i < chain)
		if i == chain - 1:
			_pop(lamps[i])
	if chain > 0:
		flare()


## Jester's 81: a gamble starts or goes on with `stake` gold at risk.
func gamble_offer(stake: int) -> void:
	if not _ui.has("card"):
		return
	var card: TextureRect = _ui["card"]
	card.texture = MachineSkin.part("card_back")
	(_ui["card_title"] as Label).text = "DOUBLE?"
	(_ui["card_hint"] as Label).text = "%d gold" % stake
	_set_lamp(_ui["card_title"], true)
	_pop(card)


## Turns the card over (red or black).
func gamble_reveal(red: bool, won_it: bool) -> void:
	if not _ui.has("card"):
		return
	var card: TextureRect = _ui["card"]
	card.pivot_offset = card.size * 0.5
	var tween := card.create_tween()
	tween.tween_property(card, "scale:x", 0.0, 0.1)
	tween.tween_callback(func() -> void: card.texture = MachineSkin.part("card_red" if red else "card_black"))
	tween.tween_property(card, "scale:x", 1.0, 0.1)
	(_ui["card_title"] as Label).text = "WIN x2!" if won_it else "LOST"
	await tween.finished


func gamble_end() -> void:
	if not _ui.has("card"):
		return
	(_ui["card"] as TextureRect).texture = MachineSkin.part("card_back")
	(_ui["card_title"] as Label).text = "GAMBLE"
	(_ui["card_hint"] as Label).text = "after gold"
	_set_lamp(_ui["card_title"], false)


# --- Building -------------------------------------------------------------------

func _build_frame() -> void:
	_frame = NinePatchRect.new()
	_frame.texture = skin.frame
	_frame.draw_center = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_frame.set_patch_margin(side, MachineSkin.FRAME_MARGIN)
	_frame.position = -Vector2.ONE * FRAME_GROW
	_frame.size = size + Vector2.ONE * FRAME_GROW * 2
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)


func _build_marquee() -> void:
	var width := clampf(size.x - 36.0, 104.0, 172.0)
	_marquee = NinePatchRect.new()
	_marquee.texture = skin.marquee
	_marquee.patch_margin_left = MachineSkin.MARQUEE_CAP
	_marquee.patch_margin_right = MachineSkin.MARQUEE_CAP
	_marquee.size = Vector2(width, MARQUEE_HEIGHT)
	_marquee.position = Vector2(roundf((size.x - width) * 0.5), -FRAME_GROW - MARQUEE_HEIGHT + 6)
	_marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marquee)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.clip_text = true
	_title.position = Vector2(MachineSkin.MARQUEE_CAP - 4, 2)
	_title.size = Vector2(width - (MachineSkin.MARQUEE_CAP - 4) * 2, MARQUEE_HEIGHT - 4)
	if skin.id != &"tome_of_ages":
		_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_title.add_theme_constant_override("outline_size", 3)
	_marquee.add_child(_title)
	var crest_size := skin.crest.get_size()
	_crest_rest = Vector2(roundf((size.x - crest_size.x) * 0.5), _marquee.position.y - crest_size.y + 5)
	_crest = _sprite(skin.crest, _crest_rest)


func _build_lever() -> void:
	var base := _sprite(MachineSkin.part("lever_base"), Vector2(size.x + FRAME_GROW, roundf(size.y * 0.5) - 2))
	_lever_arm = TextureRect.new()
	_lever_arm.texture = MachineSkin.part("lever_arm")
	_lever_arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lever_arm.size = _lever_arm.texture.get_size()
	_lever_arm.position = base.position + Vector2(1, 6 - _lever_arm.size.y)
	_lever_arm.pivot_offset = Vector2(_lever_arm.size.x * 0.5, _lever_arm.size.y)
	add_child(_lever_arm)
	move_child(_lever_arm, base.get_index())


func _build_dragon_wings() -> void:
	var texture := MachineSkin.part("dragon_wing")
	for right in [false, true]:
		var wing := TextureRect.new()
		wing.texture = texture
		wing.flip_h = right
		wing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wing.size = texture.get_size()
		# The wing's root (bottom inner corner) hides behind the frame's top corner.
		var root := Vector2(3.0 if right else wing.size.x - 4.0, wing.size.y - 4.0)
		var anchor := Vector2(size.x - 8.0 if right else 8.0, 10.0)
		wing.position = anchor - root
		wing.pivot_offset = root
		add_child(wing)
		_dragon_wings.append(wing)


func _place_runes() -> void:
	var index := 0
	var y := 14.0
	while y < size.y - 14.0:
		for x: float in [-FRAME_GROW + 1.0, size.x + FRAME_GROW - 8.0]:
			_runes.append({"pos": Vector2(x, y), "tex": MachineSkin.part("rune_%d" % (index % 4)), "phase": index * 0.9})
			index += 1
		y += 22.0
	var x := 22.0
	while x < size.x - 22.0:
		_runes.append({"pos": Vector2(x, size.y + FRAME_GROW - 8.0), "tex": MachineSkin.part("rune_%d" % (index % 4)), "phase": index * 0.9})
		index += 1
		x += 26.0


func _build_feature_panels() -> void:
	match style.feature:
		MachineStyle.Feature.NUDGE:
			_left = _make_wing()
			_ui["nudge_lamp"] = _add_label(_left, "NUDGE", 8, DIM)
			_add_label(_left, "after a loss", 6, skin.panel_text)
		MachineStyle.Feature.GAMBLE:
			_left = _make_wing()
			_ui["ways_lamp"] = _add_label(_left, "81 WAYS", 8, DIM)
			_add_label(_left, "Jester = ways", 6, skin.panel_text)
			_right = _make_wing()
			_ui["card_title"] = _add_label(_right, "GAMBLE", 7, DIM)
			var card := TextureRect.new()
			card.texture = MachineSkin.part("card_back")
			card.custom_minimum_size = Vector2(18, 26) * 1.5
			card.stretch_mode = TextureRect.STRETCH_SCALE
			card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_box(_right).add_child(card)
			_ui["card"] = card
			_ui["card_hint"] = _add_label(_right, "after gold", 6, skin.panel_text)
		MachineStyle.Feature.HOLD_AND_WIN:
			_left = _make_wing()
			_add_label(_left, "JACKPOTS", 7, skin.text_color)
			for kind: HoardPrize.Kind in [HoardPrize.Kind.GRAND, HoardPrize.Kind.MAJOR, HoardPrize.Kind.MINOR, HoardPrize.Kind.MINI]:
				var jackpot_name: String = HoardPrize.JACKPOT_NAMES[kind]
				var gold: int = HoardPrize.JACKPOTS[kind][0]
				_ui["jackpot_" + jackpot_name] = _add_label(_left, "%s %d" % [jackpot_name, gold], 7, LineOverlay.JACKPOT_COLORS[jackpot_name])
			_right = _make_wing()
			_ui["respin_title"] = _add_label(_right, "HOARD", 7, skin.text_color)
			var eggs := GridContainer.new()
			eggs.columns = 3
			eggs.add_theme_constant_override("h_separation", 2)
			eggs.add_theme_constant_override("v_separation", 2)
			eggs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			eggs.visible = false
			_box(_right).add_child(eggs)
			_ui["eggs"] = eggs
			_ui["respin_hint"] = _add_label(_right, "%d+ chests\nanywhere" % GameState.feature_trigger(), 6, skin.panel_text)
		MachineStyle.Feature.FREE_SPINS:
			_left = _make_wing()
			_add_label(_left, "EXPANDS", 7, skin.panel_text)
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(24, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_box(_left).add_child(icon)
			_ui["expand_icon"] = icon
			_ui["expand_hint"] = _add_label(_left, "", 6, skin.panel_text)
			_right = _make_wing()
			_ui["spins_title"] = _add_label(_right, "", 7, skin.panel_text)
			_ui["spins"] = _add_label(_right, "", 14, Color("#a02818"))
			_ui["spins_hint"] = _add_label(_right, "", 6, skin.panel_text)
			_idle_tome_panels()
		MachineStyle.Feature.CASCADE:
			_left = _make_wing()
			_add_label(_left, "WAYS", 7, skin.panel_text)
			_ui["ways_count"] = _add_label(_left, "-", 9, skin.text_color)
			_right = _make_wing()
			_add_label(_right, "CHAIN", 7, skin.panel_text)
			var lamps: Array[Label] = []
			for chain in range(CascadeFeature.MAX_CASCADES, 0, -1):
				lamps.push_front(_add_label(_right, "x%d" % CascadeFeature.chain_multiplier(chain), 8, DIM))
			_ui["chain_lamps"] = lamps
	_fit_wing(_left, false)
	_fit_wing(_right, true)


func _idle_tome_panels() -> void:
	(_ui["spins_title"] as Label).text = "FREE SPINS"
	(_ui["spins"] as Label).text = str(GameState.feature_length())
	(_ui["spins_hint"] as Label).text = "%d Tomes" % GameState.feature_trigger()
	var icon: TextureRect = _ui["expand_icon"]
	icon.texture = style.feature_symbol.texture if style.feature_symbol else null
	icon.modulate = Color(1, 1, 1, 0.35)
	(_ui["expand_hint"] as Label).text = "picked at start"


func _make_wing() -> NinePatchRect:
	var wing := NinePatchRect.new()
	wing.texture = skin.wing
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		wing.set_patch_margin(side, MachineSkin.WING_MARGIN)
	wing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wing.add_child(box)
	add_child(wing)
	return wing


func _box(wing: NinePatchRect) -> VBoxContainer:
	return wing.get_node("Box") as VBoxContainer


func _fit_wing(wing: NinePatchRect, right: bool) -> void:
	if wing == null:
		return
	var box := _box(wing)
	var height := maxf(box.get_combined_minimum_size().y + 10.0, 30.0)
	wing.size = Vector2(skin.wing_width, height)
	box.position = Vector2(3, 5)
	box.size = Vector2(skin.wing_width - 6, height - 10)
	var x: float = size.x + FRAME_GROW + WING_GAP if right else -FRAME_GROW - WING_GAP - skin.wing_width
	if right and _lever_arm:
		x += 10.0
	wing.position = Vector2(x, roundf((size.y - height) * 0.5))


func _add_label(wing: NinePatchRect, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", -3)
	if skin.id != &"tome_of_ages":
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("color", color)
	_box(wing).add_child(label)
	return label


## Lamps are labels that light up (accent colour) or go dim.
func _set_lamp(label: Label, on: bool) -> void:
	var base: Color = label.get_meta("color", DIM)
	var lit := skin.accent.lerp(LIT_COLOR, 0.25) if base == DIM else base.lightened(0.4)
	label.add_theme_color_override("font_color", lit if on else base)


func _sprite(texture: Texture2D, at: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = texture.get_size()
	rect.position = at
	add_child(rect)
	return rect


func _pop(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	Fx.pop(node, 1.3, 0.2)


func _clear_arrows() -> void:
	for arrow in _arrows:
		arrow.queue_free()
	_arrows.clear()


# --- Animation and drawing ------------------------------------------------------

func _animate(delta: float) -> void:
	if _crest and skin.has(MachineSkin.Ornament.BELLS):
		_crest.position.y = _crest_rest.y + roundf(sin(_time * 2.2) * 1.0)
	var flap_speed := 9.0 if _mode_glow > 0.0 else 1.6
	var flap_depth := 0.25 if _mode_glow > 0.0 else 0.07
	for wing in _dragon_wings:
		var fold := flap_depth * (0.5 + 0.5 * sin(_time * flap_speed))
		wing.scale = Vector2(1.0 - fold, 1.0 - fold * 0.5)
	if skin.has(MachineSkin.Ornament.DRAGON):
		_next_smoke -= delta
		if _next_smoke <= 0.0:
			_next_smoke = randf_range(2.5, 4.5) if _mode_glow == 0.0 else 0.6
			for nostril: Vector2 in [Vector2(13, 15), Vector2(18, 15)]:
				_smoke.append({"pos": _crest.position + nostril, "age": 0.0, "drift": (nostril.x - 15.5) * 4.0})
		for puff in _smoke:
			puff["age"] += delta
			puff["pos"] += Vector2(puff["drift"], -10.0) * delta
		_smoke = _smoke.filter(func(puff: Dictionary) -> bool: return puff["age"] < 1.4)
	for flash in _reel_flashes:
		flash["t"] -= delta * 2.0
	_reel_flashes = _reel_flashes.filter(func(flash: Dictionary) -> bool: return flash["t"] > 0.0)


## Behind the frame: the window behind the reels.
func _draw() -> void:
	if skin == null:
		return
	var window := Rect2(Vector2.ONE * 4, size - Vector2.ONE * 8)
	draw_rect(window, skin.bg_color)
	if skin.has(MachineSkin.Ornament.STONE):
		var mortar := skin.bg_color.darkened(0.35)
		var brick := skin.bg_color.lightened(0.08)
		var y := window.position.y
		var row := 0
		while y < window.end.y:
			var x := window.position.x - (8.0 if row % 2 else 0.0)
			while x < window.end.x:
				var block := Rect2(x + 1, y + 1, 15, 7).intersection(window)
				if block.has_area():
					draw_rect(block, brick)
				x += 16.0
			draw_line(Vector2(window.position.x, y), Vector2(window.end.x, y), mortar)
			y += 8.0
			row += 1


## Over the frame: bulbs, glints, flames, eyes, runes, smoke, glows.
func _draw_deco() -> void:
	var outer := Rect2(-Vector2.ONE * FRAME_GROW, size + Vector2.ONE * FRAME_GROW * 2)
	if _mode_glow > 0.0:
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		_deco.draw_rect(outer.grow(1), Color(skin.accent, 0.35 + 0.4 * pulse), false, 2.0)
	if _flash > 0.0:
		_deco.draw_rect(outer.grow(1), Color(_flash_color.lerp(Color.WHITE, 0.3), _flash), false, 2.0)
	if skin.has(MachineSkin.Ornament.BULBS):
		_draw_bulbs(outer)
	if skin.has(MachineSkin.Ornament.GLINT):
		_draw_glint()
	if skin.has(MachineSkin.Ornament.RUNES):
		for rune in _runes:
			var glow := 0.35 + 0.35 * sin(_time * 2.0 + rune["phase"]) + _rune_flash
			_deco.draw_texture(rune["tex"], rune["pos"], Color(skin.accent.lerp(Color.WHITE, _rune_flash * 0.5), clampf(glow, 0.15, 1.0)))
	for candle in _candles:
		_draw_flame(candle.position + Vector2(3, 2))
	if skin.has(MachineSkin.Ornament.DRAGON) and _crest:
		_draw_dragon_eyes()
		for puff in _smoke:
			var age: float = puff["age"]
			_deco.draw_circle(puff["pos"], 1.5 + age * 2.0, Color(0.75, 0.8, 0.75, 0.5 * (1.0 - age / 1.4)))
	if skin.id == &"old_cellar" and _crest:
		# The siren lamp lights up on wins.
		var lamp := _crest.position + Vector2(8, 5)
		var on := _flash > 0.0 or _spin_boost > 0.0 and int(_time * 10.0) % 2 == 0
		if on:
			_deco.draw_circle(lamp, 6.0, Color(1, 0.3, 0.2, 0.3))
			_deco.draw_circle(lamp, 2.5, Color(1, 0.7, 0.6, 0.9))


func _draw_bulbs(outer: Rect2) -> void:
	var speed := 14.0 if _spin_boost > 0.0 else 4.0
	var points: Array[Vector2] = []
	var y := outer.position.y + 8.0
	while y < outer.end.y - 6.0:
		points.append(Vector2(outer.position.x + 4.0, y))
		y += 10.0
	var right_side: Array[Vector2] = []
	for p in points:
		right_side.append(Vector2(outer.end.x - 4.0, p.y))
	right_side.reverse()
	points.append_array(right_side)
	for i in points.size():
		var lit := (int(i + _time * speed) % 3 == 0) or _flash > 0.3 and int(_time * 12.0) % 2 == 0
		var color := skin.accent.lerp(LIT_COLOR, 0.4) if lit else skin.accent.darkened(0.6)
		if lit:
			_deco.draw_circle(points[i], 3.0, Color(color, 0.25))
		_deco.draw_circle(points[i], 1.5, color)


func _draw_glint() -> void:
	var period := 4.0
	var t := fmod(_time, period)
	if t > 0.6:
		return
	var rect := Rect2(_marquee.position + Vector2(3, 4), _marquee.size - Vector2(6, 8))
	var sweep := rect.position.x - 10.0 + (rect.size.x + 20.0) * t / 0.6
	for row in int(rect.size.y):
		var x := sweep - row
		var bar := Rect2(x, rect.position.y + row, 3, 1).intersection(rect)
		if bar.has_area():
			_deco.draw_rect(bar, Color(1, 1, 0.9, 0.55))


func _draw_flame(base: Vector2) -> void:
	var flicker := sin(_time * 17.0) * 0.5 + sin(_time * 7.3) * 0.5
	var tall := 3.0 + roundf(flicker + 1.0) + (1.0 if _mode_glow > 0.0 else 0.0)
	_deco.draw_circle(base + Vector2(0, -2), 6.0 + flicker, Color(1, 0.8, 0.3, 0.12 + 0.1 * _mode_glow))
	_deco.draw_rect(Rect2(base + Vector2(-1, -tall), Vector2(2, tall)), Color("#f89830"))
	_deco.draw_rect(Rect2(base + Vector2(-0.5, -tall + 1), Vector2(1, tall - 1)), Color("#fff0a0"))


func _draw_dragon_eyes() -> void:
	var blink := fmod(_time, 4.3) < 0.14
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	var color := Color("#145030") if blink else Color("#f8d038").lerp(Color("#ff5020"), pulse * (0.4 + 0.6 * _mode_glow))
	for eye: Vector2 in [Vector2(12, 9), Vector2(19, 9)]:
		var at := _crest.position + eye
		if not blink:
			_deco.draw_circle(at + Vector2.ONE, 3.0, Color(color, 0.25 + 0.25 * _mode_glow))
		_deco.draw_rect(Rect2(at, Vector2(2, 2)), color)


## Above the reels: separators, glass shine, expanded reels, flashes, arrows.
func _draw_front() -> void:
	if skin == null:
		return
	if not style.variable_rows:
		var reels := roundi(_reel_rect.size.x / _cell_size)
		for i in range(1, reels):
			var x := _reel_rect.position.x + i * _cell_size
			front.draw_line(Vector2(x, _reel_rect.position.y), Vector2(x, _reel_rect.end.y), Color(0, 0, 0, 0.3))
	front.draw_line(_reel_rect.position + Vector2(1, 1), Vector2(_reel_rect.end.x - 1, _reel_rect.position.y + 1), Color(1, 1, 1, 0.25))
	var pulse := 0.6 + 0.4 * sin(_time * 6.0)
	for rect in _expanded:
		front.draw_rect(rect, Color(skin.accent, 0.12 * pulse))
		front.draw_rect(rect.grow(-1), Color(skin.accent, pulse), false, 2.0)
		# Twinkles climbing the page.
		for i in 4:
			var t := fmod(_time * 0.8 + i * 0.25, 1.0)
			var p := Vector2(rect.position.x + rect.size.x * (0.2 + 0.6 * fmod(i * 0.37, 1.0)), rect.end.y - rect.size.y * t)
			front.draw_rect(Rect2(p - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 0.8, 1.0 - t))
	for flash in _reel_flashes:
		front.draw_rect(flash["rect"], Color(flash["color"], 0.45 * flash["t"]))
	for arrow in _arrows:
		var bob := roundf(sin(_time * 8.0) * 1.5)
		var c := arrow.position + Vector2(arrow.size.x * 0.5, 7 + bob)
		var color := Color("#80f060") if not arrow.is_hovered() else Color("#d0ffb0")
		var shape := PackedVector2Array([c + Vector2(-6, -4), c + Vector2(6, -4), c + Vector2(0, 4)])
		front.draw_colored_polygon(shape, Color(0, 0, 0, 0.6))
		var inner := PackedVector2Array([c + Vector2(-4, -3), c + Vector2(4, -3), c + Vector2(0, 2)])
		front.draw_colored_polygon(inner, color)
