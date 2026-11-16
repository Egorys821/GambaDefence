extends Node
## Plays sound effects and music. Registered as the `Audio` autoload.
##
##   Audio.play(&"coin")                  # any file name from assets/audio/sfx/
##   Audio.play(&"win", 1.2)              # with pitch
##   Audio.play_music(&"night")           # crossfades to assets/audio/music/night.wav
##   Audio.set_volume(Audio.MUSIC_BUS, 0.5)  # 0..1, saved to user://settings.cfg

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 24
## The same sound never restarts more often than this (keeps big battles readable).
const MIN_REPEAT_INTERVAL := 0.05
const MUSIC_VOLUME_DB := -9.0
const SFX_VOLUME_DB := -3.0
const MUSIC_FADE_TIME := 1.2
const SETTINGS_PATH := "user://settings.cfg"
const MASTER_BUS := &"Master"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const DEFAULT_VOLUMES := {MASTER_BUS: 0.8, MUSIC_BUS: 0.7, SFX_BUS: 0.8}

## Bus name -> linear volume 0..1.
var volumes: Dictionary = DEFAULT_VOLUMES.duplicate()

var _sfx: Dictionary = {}
var _music: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_played: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var _current_music := &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_buses()
	_load_settings()
	_sfx = _load_streams(SFX_DIR)
	_music = _load_streams(MUSIC_DIR)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = SFX_VOLUME_DB
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = -80.0
		player.bus = MUSIC_BUS
		player.finished.connect(player.play)  # loop
		add_child(player)
		_music_players.append(player)


func play(sound: StringName, pitch: float = 1.0, volume_db: float = 0.0, pitch_jitter: float = 0.0) -> void:
	var stream: AudioStream = _sfx.get(sound)
	if stream == null:
		push_warning("Audio: unknown sound '%s'" % sound)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -1.0)) < MIN_REPEAT_INTERVAL:
		return
	_last_played[sound] = now
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = stream
	player.pitch_scale = maxf(0.05, pitch + randf_range(-pitch_jitter, pitch_jitter))
	player.volume_db = SFX_VOLUME_DB + volume_db
	player.play()


func play_music(track: StringName) -> void:
	if track == _current_music or not _music.has(track):
		return
	_current_music = track
	var old := _music_players[_active_music]
	_active_music = 1 - _active_music
	var new := _music_players[_active_music]
	new.stream = _music[track]
	new.volume_db = -40.0
	new.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(new, "volume_db", MUSIC_VOLUME_DB, MUSIC_FADE_TIME)
	tween.tween_property(old, "volume_db", -60.0, MUSIC_FADE_TIME)
	tween.chain().tween_callback(old.stop)


func get_volume(bus: StringName) -> float:
	return volumes.get(bus, 1.0)


func set_volume(bus: StringName, linear: float, save: bool = true) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)))
	AudioServer.set_bus_mute(index, volumes[bus] <= 0.0)
	if save:
		_save_settings()


func _create_buses() -> void:
	for bus: StringName in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, MASTER_BUS)


func _load_settings() -> void:
	var file := ConfigFile.new()
	file.load(SETTINGS_PATH)
	for bus: StringName in DEFAULT_VOLUMES:
		set_volume(bus, file.get_value("audio", String(bus), DEFAULT_VOLUMES[bus]), false)


func _save_settings() -> void:
	var file := ConfigFile.new()
	file.load(SETTINGS_PATH)
	for bus: StringName in volumes:
		file.set_value("audio", String(bus), volumes[bus])
	file.save(SETTINGS_PATH)


func _load_streams(dir: String) -> Dictionary:
	var streams := {}
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with(".wav") or file.ends_with(".ogg"):
			streams[StringName(file.get_basename())] = load(dir + file)
	return streams
