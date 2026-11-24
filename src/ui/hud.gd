class_name Hud
extends PanelContainer
## Top bar: night counter, phase, gold, army size, castle health, settings button.

signal settings_pressed

const COUNT_UP_TIME := 0.5

var _shown_gold := 0
var _gold_tween: Tween

@onready var _night_label: Label = %NightLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _gold_icon: TextureRect = %GoldIcon
@onready var _gold_label: Label = %GoldLabel
@onready var _army_label: Label = %ArmyLabel
@onready var _castle_bar: ProgressBar = %CastleBar
@onready var _castle_label: Label = %CastleLabel
@onready var _settings_button: Button = %SettingsButton
@onready var _curse_label: Label = %CurseLabel


func _ready() -> void:
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.castle_hp_changed.connect(_on_castle_hp_changed)
	GameState.curse_changed.connect(_on_curse_changed)
	_settings_button.pressed.connect(settings_pressed.emit)
	_shown_gold = GameState.gold
	_set_shown_gold(GameState.gold)
	_on_castle_hp_changed(GameState.castle_hp, GameState.castle_max_hp)
	set_phase(false)
	set_army(0)


func set_phase(is_night: bool) -> void:
	_night_label.text = "Night %d/%d  %s" % [GameState.night, GameState.max_nights(), GameState.castle.display_name]
	_night_label.tooltip_text = _night_label.text
	_phase_label.text = "Night" if is_night else "Day"
	_phase_label.add_theme_color_override("font_color", Color("#a0a0ff") if is_night else Color("#f8d038"))


## Army size, the gold it will cost at the next dawn, and morale if low.
func set_army(defenders: int, upkeep: int = 0, morale: float = 1.0) -> void:
	var text := "%d" % defenders
	if upkeep > 0:
		text += " (-%dg)" % upkeep
	if morale < 0.99:
		text += " %d%%" % roundi(morale * 100.0)
	_army_label.text = text
	_army_label.add_theme_color_override("font_color", Color("#ff9060") if morale < 0.99 else Color.WHITE)
	_army_label.tooltip_text = "Troops: %d
Upkeep at dawn: %d gold (first %d troops are free)
Morale: %d%% - unpaid upkeep makes troops weaker" % [
		defenders, upkeep, GameState.stat_int(Stats.FREE_TROOPS), roundi(morale * 100.0)]


## Screen position flying coins aim for.
func gold_icon_center() -> Vector2:
	return _gold_icon.global_position + _gold_icon.size * 0.5


## Small bounce of the gold icon when a coin lands.
func bump_gold() -> void:
	_gold_icon.pivot_offset = _gold_icon.size * 0.5
	Fx.pop(_gold_icon, 1.35, 0.15)


func _on_curse_changed(threat: int) -> void:
	var greed := GameState.greed_spirits
	_curse_label.visible = threat > 0 or greed > 0
	var parts: Array[String] = []
	if threat > 0:
		parts.append("Curse +%d" % threat)
	if greed > 0:
		parts.append("Greed +%d" % greed)
	_curse_label.text = "  ".join(parts)
	_curse_label.tooltip_text = "Cursed symbols add %d ghosts and Cursed Coins add %d Greed Monsters to tonight's wave." % [threat, greed]
	if _curse_label.visible:
		_curse_label.pivot_offset = _curse_label.size * 0.5
		Fx.pop(_curse_label, 1.2, 0.2)


func _on_gold_changed(gold: int) -> void:
	if _gold_tween:
		_gold_tween.kill()
	_gold_tween = create_tween()
	_gold_tween.tween_method(_set_shown_gold, _shown_gold, gold, COUNT_UP_TIME)


func _set_shown_gold(value: int) -> void:
	_shown_gold = value
	_gold_label.text = "%d" % value


func _on_castle_hp_changed(hp: int, max_hp: int) -> void:
	var lost := hp < _castle_bar.value
	_castle_bar.max_value = max_hp
	_castle_bar.value = hp
	_castle_label.text = "%d/%d" % [hp, max_hp]
	if lost:
		_castle_bar.modulate = Color(2, 1, 1)
		create_tween().tween_property(_castle_bar, "modulate", Color.WHITE, 0.25)
