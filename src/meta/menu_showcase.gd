class_name MenuShowcase
extends Control
## Animated "action scenes" in the middle of the main menu. A framed little
## stage cycles through short vignettes made from the game's own sprites:
## the slot machine by day, the battle at the gate by night, the merchant's
## rarity bag and conquering castles for Crowns. Click it to skip ahead.
## Built entirely in code; every scene is a _build_* function plus a _tick_*
## function called each frame while it runs.

const SCENE_TIME := 7.5
const FADE_TIME := 0.35
const GOLD := Color("#f8d038")
const INK := Color(1, 0.93, 0.78)
const FORGE_CYAN := Color("#60d8f8")
const FRAME_BG := Color(0.05, 0.035, 0.06, 0.82)
const FRAME_BORDER := Color("#b07a28")
const STAGE_MARGIN := Vector2(8, 30)
const SCENES := [
	{"id": "spin", "title": "By day: spin the magic machine", "text": "Three swords on a line call soldiers to the gate."},
	{"id": "battle", "title": "By night: hold the gate", "text": "Troops and towers fight the spirits until dawn."},
	{"id": "merchant", "title": "The merchant draws from his bag", "text": "Common, Rare, Mythic... and once in a while, Legendary."},
	{"id": "crowns", "title": "Conquer castles, win Crowns", "text": "Forge permanent upgrades and unlock new machines."},
]

const SYMBOLS := {
	"sword": preload("res://assets/sprites/symbols/sword.png"),
	"coin": preload("res://assets/sprites/symbols/coin.png"),
	"bow": preload("res://assets/sprites/symbols/bow.png"),
	"crossbow": preload("res://assets/sprites/symbols/crossbow.png"),
	"banner": preload("res://assets/sprites/symbols/banner.png"),
	"rune": preload("res://assets/sprites/symbols/rune.png"),
	"skull": preload("res://assets/sprites/symbols/skull.png"),
	"helm": preload("res://assets/sprites/symbols/helm.png"),
	"crown": preload("res://assets/sprites/symbols/crown.png"),
}
const SWORDSMAN := preload("res://assets/sprites/units/swordsman.png")
const PIKEMAN := preload("res://assets/sprites/units/pikeman.png")
const ARCHER := preload("res://assets/sprites/units/archer.png")
const SPIRITS: Array[Texture2D] = [
	preload("res://assets/sprites/enemies/ghost.png"),
	preload("res://assets/sprites/enemies/wraith.png"),
	preload("res://assets/sprites/enemies/ghoul.png"),
	preload("res://assets/sprites/enemies/banshee.png"),
]
const ARROW := preload("res://assets/sprites/projectiles/arrow.png")
const CASTLE := preload("res://assets/sprites/environment/castle.png")
const TOWER := preload("res://assets/sprites/environment/tower.png")
const BAG := preload("res://assets/sprites/ui/bag.png")
const SHARD := preload("res://assets/sprites/ui/shard.png")
const WALL := preload("res://assets/sprites/ui/wall.png")

var _index := -1
## Seconds into the current scene.
var _t := 0.0
var _switching := false
## Per-scene state (nodes and timers), cleared on every scene change.
var _s := {}
var _stage: Control
var _caption: Label
var _sub: Label
var _dots: Array[ColorRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Click for the next scene"
	_caption = _make_label(11, GOLD)
	_caption.position = Vector2(10, 4)
	add_child(_caption)
	_sub = _make_label(7, INK)
	_sub.position = Vector2(10, 18)
	add_child(_sub)
	_stage = Control.new()
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 4)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dots)
	for i in SCENES.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 3)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
		_dots.append(dot)
	resized.connect(_layout.bind(dots))
	_layout(dots)


func _layout(dots: HBoxContainer) -> void:
	_stage.position = STAGE_MARGIN
	_stage.size = size - Vector2(STAGE_MARGIN.x * 2, STAGE_MARGIN.y + 14)
	_caption.size.x = size.x - 20
	_sub.size.x = size.x - 20
	dots.position = Vector2(size.x * 0.5 - SCENES.size() * 7, size.y - 9)


## Starts (or restarts) the show from the first scene.
func start() -> void:
	_index = -1
	_next_scene(false)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		Audio.play(&"click", 1.3, -8.0)
		_next_scene()
		accept_event()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _index < 0:
		return
	_t += delta
	var id: String = SCENES[_index]["id"]
	call("_tick_" + id, delta)
	if _t >= SCENE_TIME and not _switching:
		_next_scene()


func _next_scene(fade := true) -> void:
	if _switching:
		return
	if fade and _index >= 0:
		_switching = true
		var out := create_tween()
		out.tween_property(_stage, "modulate:a", 0.0, FADE_TIME)
		await out.finished
		_switching = false
	_index = (_index + 1) % SCENES.size()
	_t = 0.0
	_s.clear()
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()
	var scene: Dictionary = SCENES[_index]
	_caption.text = scene["title"]
	_sub.text = scene["text"]
	for i in _dots.size():
		_dots[i].color = GOLD if i == _index else Color(0.4, 0.32, 0.22)
	call("_build_" + String(scene["id"]))
	_stage.modulate.a = 0.0
	create_tween().tween_property(_stage, "modulate:a", 1.0, FADE_TIME)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, FRAME_BG)
	draw_rect(rect.grow(-1), FRAME_BORDER, false, 2.0)
	draw_rect(rect.grow(-4), Color(FRAME_BORDER, 0.35), false, 1.0)
	# Gold studs in the corners.
	for corner in [Vector2(4, 4), Vector2(size.x - 4, 4), Vector2(4, size.y - 4), size - Vector2(4, 4)]:
		draw_rect(Rect2(corner - Vector2(2, 2), Vector2(4, 4)), GOLD)
	draw_line(Vector2(10, 28), Vector2(size.x - 10, 28), Color(FRAME_BORDER, 0.5), 1.0)


# --- Scene 1: the slot machine -----------------------------------------------

func _build_spin() -> void:
	var w := _stage.size.x
	var cabinet := Panel.new()
	cabinet.position = Vector2(30, 34)
	cabinet.size = Vector2(150, 120)
	cabinet.add_theme_stylebox_override("panel", _box(Color(0.33, 0.15, 0.08), GOLD, 2, 6))
	_stage.add_child(cabinet)
	var header := _make_label(9, GOLD)
	header.text = "GAMBA"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.position = Vector2(0, 4)
	header.size = Vector2(150, 12)
	cabinet.add_child(header)
	var reels: Array[TextureRect] = []
	for i in 3:
		var window := Panel.new()
		window.position = Vector2(14 + i * 42, 24)
		window.size = Vector2(38, 56)
		window.add_theme_stylebox_override("panel", _box(Color(0.95, 0.9, 0.78), Color(0.2, 0.1, 0.05), 2, 3))
		cabinet.add_child(window)
		var symbol := TextureRect.new()
		symbol.texture = SYMBOLS["coin"]
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.position = Vector2(3, 12)
		symbol.size = Vector2(32, 32)
		window.add_child(symbol)
		reels.append(symbol)
	var line := ColorRect.new()
	line.color = Color(GOLD, 0.0)
	line.position = Vector2(10, 50)
	line.size = Vector2(130, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cabinet.add_child(line)
	var button := Panel.new()
	button.position = Vector2(55, 90)
	button.size = Vector2(40, 18)
	button.add_theme_stylebox_override("panel", _box(Color("#c83a2a"), Color(0.3, 0.05, 0.02), 1, 4))
	cabinet.add_child(button)
	var spin_label := _make_label(7, Color.WHITE)
	spin_label.text = "SPIN"
	spin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spin_label.size = Vector2(40, 18)
	spin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(spin_label)
	# Lever on the side.
	var lever := ColorRect.new()
	lever.color = Color(0.7, 0.7, 0.75)
	lever.size = Vector2(3, 36)
	lever.position = Vector2(184, 54)
	lever.pivot_offset = Vector2(1.5, 36)
	_stage.add_child(lever)
	var knob := ColorRect.new()
	knob.color = Color("#e03030")
	knob.size = Vector2(8, 8)
	knob.position = Vector2(-2.5, -6)
	lever.add_child(knob)
	# Gate on the right where the soldiers march to.
	_sprite(TOWER, Vector2(w - 24, 92), 2.0)
	var ground := ColorRect.new()
	ground.color = Color(0.16, 0.24, 0.12, 0.8)
	ground.position = Vector2(0, 160)
	ground.size = Vector2(w, 50)
	_stage.add_child(ground)
	_s = {"reels": reels, "line": line, "lever": lever, "cabinet": cabinet, "button": button,
		"stops": [1.2, 1.65, 2.1], "flip": 0.0, "won": false, "troops": [], "spawned": 0, "coins": false}


func _tick_spin(delta: float) -> void:
	var reels: Array = _s["reels"]
	var lever: ColorRect = _s["lever"]
	if _t < 0.6:
		lever.rotation = lerpf(0.0, 0.9, _t / 0.6) if _t < 0.3 else lerpf(0.9, 0.0, (_t - 0.3) / 0.3)
		if _t < 0.05:
			Audio.play(&"spin", 1.0, -14.0)
	_s["flip"] -= delta
	if _s["flip"] <= 0.0:
		_s["flip"] = 0.06
		for i in reels.size():
			if _t > 0.3 and _t < _s["stops"][i]:
				(reels[i] as TextureRect).texture = SYMBOLS.values().pick_random()
	for i in reels.size():
		var stop: float = _s["stops"][i]
		if _t >= stop and _t - delta < stop:
			(reels[i] as TextureRect).texture = SYMBOLS["sword"]
			Fx.pop(reels[i], 1.25, 0.15)
			Audio.play(&"reel_stop", 1.0, -14.0)
	if _t >= 2.3 and not _s["won"]:
		_s["won"] = true
		var line: ColorRect = _s["line"]
		var flash := line.create_tween().set_loops(3)
		flash.tween_property(line, "color:a", 0.9, 0.12)
		flash.tween_property(line, "color:a", 0.2, 0.12)
		_popup("3x Swords!  +3 Swordsmen", Vector2(30, 14), GOLD)
	# Soldiers walk out of the cabinet to the gate, one by one.
	if _t >= 2.8 and _s["spawned"] < 3 and _t >= 2.8 + _s["spawned"] * 0.45:
		var troop := _sprite(SWORDSMAN, Vector2(190, 168 - _s["spawned"] * 4), 2.0)
		_s["troops"].append(troop)
		_s["spawned"] += 1
	for i in _s["troops"].size():
		var troop: Sprite2D = _s["troops"][i]
		var stop_x: float = _stage.size.x - 60 - i * 26
		if troop.position.x < stop_x:
			troop.position.x += 38.0 * delta
			troop.position.y = 168 - i * 4 - absf(sin(_t * 9.0 + i)) * 2.0
	if _t >= 5.2 and not _s["coins"]:
		_s["coins"] = true
		var cabinet: Panel = _s["cabinet"]
		Fx.burst(_stage, cabinet.position + Vector2(75, 20), Color.WHITE, 10, 90.0, SYMBOLS["coin"], 1.2, 220.0)
		_popup("+12 gold", Vector2(70, 2), GOLD)


# --- Scene 2: the battle at the gate -----------------------------------------

func _build_battle() -> void:
	var w := _stage.size.x
	var sky := ColorRect.new()
	sky.color = Color(0.06, 0.07, 0.16, 0.7)
	sky.size = Vector2(w, 120)
	_stage.add_child(sky)
	var ground := ColorRect.new()
	ground.color = Color(0.1, 0.16, 0.09, 0.9)
	ground.position = Vector2(0, 110)
	ground.size = Vector2(w, 110)
	_stage.add_child(ground)
	var moon := _sprite(SYMBOLS["coin"], Vector2(w - 40, 26), 1.5)
	moon.modulate = Color(0.85, 0.9, 1.0, 0.8)
	var castle := _sprite(CASTLE, Vector2(46, 100), 0.9)
	castle.modulate = Color(0.75, 0.75, 0.9)
	var archer := _sprite(ARCHER, Vector2(78, 62), 2.0)
	var line_x := 150.0
	var troops: Array[Sprite2D] = [
		_sprite(SWORDSMAN, Vector2(line_x, 132), 2.0),
		_sprite(PIKEMAN, Vector2(line_x - 22, 152), 2.0),
		_sprite(SWORDSMAN, Vector2(line_x - 4, 172), 2.0),
	]
	_s = {"archer": archer, "troops": troops, "spirits": [], "spawn": 0.2, "shot": 0.6, "swing": 0.5,
		"front": line_x + 24, "kills": 0, "kill_label": _make_label(8, GOLD)}
	var kills: Label = _s["kill_label"]
	kills.position = Vector2(w - 110, 4)
	kills.size.x = 100
	kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(kills)
	_update_kills()


func _tick_battle(delta: float) -> void:
	var w := _stage.size.x
	_s["spawn"] -= delta
	if _s["spawn"] <= 0.0 and _t < SCENE_TIME - 1.5:
		_s["spawn"] = randf_range(0.7, 1.2)
		var spirit := _sprite(SPIRITS.pick_random(), Vector2(w + 10, randf_range(128, 176)), 2.0)
		spirit.flip_h = true
		spirit.set_meta("hp", 3)
		spirit.set_meta("phase", randf() * TAU)
		_s["spirits"].append(spirit)
	var spirits: Array = _s["spirits"]
	for spirit: Sprite2D in spirits:
		var phase: float = spirit.get_meta("phase")
		if spirit.position.x > _s["front"]:
			spirit.position.x -= 34.0 * delta
		spirit.offset.y = sin(_t * 3.0 + phase) * 1.5
	# The archer on the wall shoots the spirit closest to the gate.
	_s["shot"] -= delta
	var target := _front_spirit()
	if _s["shot"] <= 0.0 and target:
		_s["shot"] = 0.75
		_shoot(target)
	# The front line swings at spirits in reach.
	_s["swing"] -= delta
	if _s["swing"] <= 0.0 and target and target.position.x <= _s["front"] + 4:
		_s["swing"] = 0.6
		var troop: Sprite2D = (_s["troops"] as Array).pick_random()
		var home := troop.position
		var lunge := troop.create_tween()
		lunge.tween_property(troop, "position:x", home.x + 6, 0.08)
		lunge.tween_property(troop, "position:x", home.x, 0.12)
		_hit(target)


func _front_spirit() -> Sprite2D:
	var best: Sprite2D = null
	for spirit: Sprite2D in _s["spirits"]:
		if best == null or spirit.position.x < best.position.x:
			best = spirit
	return best


func _shoot(target: Sprite2D) -> void:
	var archer: Sprite2D = _s["archer"]
	var arrow := _sprite(ARROW, archer.position + Vector2(10, -2), 1.5)
	var to := target.position
	arrow.rotation = (to - arrow.position).angle()
	var flight := arrow.create_tween()
	flight.tween_property(arrow, "position", to, arrow.position.distance_to(to) / 260.0)
	var target_ref: WeakRef = weakref(target)  # the spirit may be gone when the arrow lands
	flight.tween_callback(func() -> void:
		arrow.queue_free()
		var hit_spirit: Sprite2D = target_ref.get_ref()
		if hit_spirit and hit_spirit in _s.get("spirits", []):
			_hit(hit_spirit))


func _hit(spirit: Sprite2D) -> void:
	var hp: int = spirit.get_meta("hp") - 1
	spirit.set_meta("hp", hp)
	spirit.modulate = Color(2, 0.6, 0.6)
	spirit.create_tween().tween_property(spirit, "modulate", Color.WHITE, 0.15)
	if hp > 0:
		return
	(_s["spirits"] as Array).erase(spirit)
	Fx.burst(_stage, spirit.position, Color(0.75, 0.85, 1.0), 10, 50.0)
	_s["kills"] += 1
	_update_kills()
	var fade := spirit.create_tween()
	fade.tween_property(spirit, "modulate:a", 0.0, 0.2)
	fade.tween_callback(spirit.queue_free)


func _update_kills() -> void:
	(_s["kill_label"] as Label).text = "Spirits banished: %d" % _s["kills"]


# --- Scene 3: the merchant's bag ---------------------------------------------

func _build_merchant() -> void:
	var bag := _sprite(BAG, Vector2(46, 96), 3.0)
	var label := _make_label(7, INK)
	label.text = "the hidden bag"
	label.position = Vector2(12, 128)
	label.size.x = 70
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(label)
	var wares := [
		["bow", MerchantRarity.Tier.COMMON, "4g"],
		["crossbow", MerchantRarity.Tier.RARE, "9g"],
		["banner", MerchantRarity.Tier.MYTHIC, "16g"],
		["rune", MerchantRarity.Tier.LEGENDARY, "30g"],
	]
	_s = {"bag": bag, "wares": wares, "dealt": 0, "cards": []}


func _tick_merchant(_delta: float) -> void:
	var bag: Sprite2D = _s["bag"]
	bag.rotation = sin(_t * 14.0) * 0.12 if fmod(_t, 1.0) < 0.35 else 0.0
	var dealt: int = _s["dealt"]
	if dealt < 4 and _t >= 0.5 + dealt * 1.0:
		_deal_card(dealt)
		_s["dealt"] = dealt + 1
	# The legendary card glows.
	if _s["cards"].size() == 4:
		var legend: Panel = _s["cards"][3]
		legend.modulate = Color.WHITE.lerp(Color(1.4, 1.25, 0.8), 0.5 + 0.5 * sin(_t * 5.0))


func _deal_card(i: int) -> void:
	var ware: Array = _s["wares"][i]
	var tier: int = ware[1]
	var card := Panel.new()
	card.size = Vector2(56, 78)
	card.add_theme_stylebox_override("panel", MerchantRarity.card_style(tier))
	card.position = Vector2(40, 70)
	card.scale = Vector2(0.2, 0.2)
	card.pivot_offset = card.size * 0.5
	_stage.add_child(card)
	var icon := TextureRect.new()
	icon.texture = SYMBOLS[ware[0]]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(12, 8)
	icon.size = Vector2(32, 32)
	card.add_child(icon)
	var tier_label := _make_label(7, MerchantRarity.text_color(tier))
	tier_label.text = MerchantRarity.tier_name(tier)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.position = Vector2(0, 44)
	tier_label.size.x = 56
	card.add_child(tier_label)
	var price := _make_label(9, GOLD)
	price.text = ware[2]
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.position = Vector2(0, 58)
	price.size.x = 56
	card.add_child(price)
	var target := Vector2(110 + i * 66, 64)
	var deal := card.create_tween().set_parallel()
	deal.tween_property(card, "position", target, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	deal.tween_property(card, "scale", Vector2.ONE, 0.35)
	_s["cards"].append(card)
	if tier == MerchantRarity.Tier.LEGENDARY:
		Audio.play(&"tease", 1.0, -12.0)
		card.create_tween().tween_callback(func() -> void:
			Fx.burst(_stage, target + card.size * 0.5, GOLD, 18, 80.0)
			_popup("LEGENDARY!", target + Vector2(-4, -22), MerchantRarity.text_color(tier))).set_delay(0.35)
	else:
		Audio.play(&"click", 1.2, -14.0)


# --- Scene 4: crowns and the Time Forge --------------------------------------

func _build_crowns() -> void:
	var w := _stage.size.x
	var castle := _sprite(CASTLE, Vector2(80, 110), 1.1)
	var conquered := _make_label(9, Color("#70e070"))
	conquered.text = "Conquered!"
	conquered.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	conquered.position = Vector2(20, 160)
	conquered.size.x = 120
	_stage.add_child(conquered)
	var counter := _make_label(10, GOLD)
	counter.position = Vector2(w - 150, 4)
	counter.size.x = 140
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage.add_child(counter)
	# A little Time Forge branch that lights up as crowns arrive.
	var nodes: Array[Panel] = []
	var spots := [Vector2(w - 120, 60), Vector2(w - 160, 120), Vector2(w - 80, 120)]
	var icons := [TOWER, WALL, SHARD]
	for i in 3:
		if i > 0:
			var link := Line2D.new()
			link.points = PackedVector2Array([spots[0] + Vector2(18, 18), spots[i] + Vector2(18, 18)])
			link.width = 2.0
			link.default_color = Color(0.4, 0.35, 0.3, 0.6)
			_stage.add_child(link)
			_s["link_%d" % i] = link
	for i in 3:
		var node := Panel.new()
		node.position = spots[i]
		node.size = Vector2(36, 36)
		node.pivot_offset = node.size * 0.5
		node.add_theme_stylebox_override("panel", _box(Color(0.2, 0.13, 0.08), Color(0.45, 0.32, 0.18), 2, 2))
		node.modulate = Color(0.5, 0.5, 0.55)
		var icon := TextureRect.new()
		icon.texture = icons[i]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(4, 4)
		icon.size = Vector2(28, 28)
		node.add_child(icon)
		_stage.add_child(node)
		nodes.append(node)
	var forge := _make_label(8, FORGE_CYAN)
	forge.text = "Time Forge"
	forge.position = Vector2(w - 180, 168)
	forge.size.x = 160
	forge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(forge)
	_s.merge({"castle": castle, "counter": counter, "nodes": nodes, "crowns": 0, "arrived": 0, "lit": 0})
	_update_crowns()


func _tick_crowns(_delta: float) -> void:
	var castle: Sprite2D = _s["castle"]
	castle.modulate = Color.WHITE.lerp(Color(1.25, 1.2, 0.9), 0.5 + 0.5 * sin(_t * 3.0))
	var crowns: int = _s["crowns"]
	if crowns < 3 and _t >= 0.8 + crowns * 0.7:
		_s["crowns"] = crowns + 1
		var counter: Label = _s["counter"]
		var crown := _sprite(SYMBOLS["crown"], Vector2(80, 70), 2.0)
		var fly := crown.create_tween()
		fly.tween_property(crown, "position", counter.position + Vector2(counter.size.x - 20, 8), 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_callback(func() -> void:
			crown.queue_free()
			_s["arrived"] += 1
			_update_crowns()
			Audio.play(&"coin", 1.2, -12.0))
	var lit: int = _s["lit"]
	if lit < 3 and _t >= 3.4 + lit * 0.8:
		_s["lit"] = lit + 1
		var node: Panel = _s["nodes"][lit]
		node.modulate = Color.WHITE
		node.add_theme_stylebox_override("panel", _box(Color(0.25, 0.17, 0.08), GOLD, 2, 2))
		Fx.pop(node, 1.3, 0.25)
		Fx.burst(_stage, node.position + node.size * 0.5, FORGE_CYAN, 14, 70.0)
		Audio.play(&"buy", 1.1, -12.0)
		if lit > 0:
			(_s["link_%d" % lit] as Line2D).default_color = Color("#c08820")


func _update_crowns() -> void:
	(_s["counter"] as Label).text = "Crowns: %d" % _s["arrived"]


# --- Helpers -------------------------------------------------------------------

func _sprite(texture: Texture2D, at: Vector2, scale_by: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.scale = Vector2.ONE * scale_by
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage.add_child(sprite)
	return sprite


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Text that pops up, drifts upwards and fades.
func _popup(text: String, at: Vector2, color: Color) -> void:
	var label := _make_label(10, color)
	label.text = text
	label.position = at
	_stage.add_child(label)
	label.pivot_offset = Vector2(40, 6)
	Fx.pop(label, 1.3, 0.2)
	var tween := label.create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(label, "position:y", at.y - 10, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _box(bg: Color, border: Color, border_width: int, corner: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner)
	return style
