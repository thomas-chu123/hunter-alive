extends Node

const Campaign := preload("res://scripts/game/campaign.gd")
static var settings := Campaign.Config.read("music")
static var TRACKS: Array = Campaign.IDS.map(func(id: String) -> String: return settings.regions[id].theme) + [settings.title]
static var TITLE := TRACKS.size() - 1
static var FIRST_BOSS := TRACKS.size()
static var BOSS_TRACKS: Array = Campaign.IDS.map(func(id: String) -> String: return settings.regions[id].boss) + ([] if settings.final_boss.is_empty() else [settings.final_boss])
static var TRACK_VOLUME: float = settings.volume_db
static var FADE_TIME: float = settings.fade_seconds
static var SILENT_DB: float = settings.silent_db

var current_region := -1
var voices: Array[AudioStreamPlayer] = []
var active := 0
var fade: Tween


func _ready() -> void:
	for _index in range(2):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)


func play_region(region: int) -> void:
	_play_track(region)


func play_boss(region: int, final_phase: bool = false) -> void:
	var track := FIRST_BOSS + region
	if final_phase and not settings.final_boss.is_empty() and ResourceLoader.exists(settings.final_boss):
		track = FIRST_BOSS + BOSS_TRACKS.size() - 1
	_play_track(track)


func _track_path(index: int) -> String:
	if index < 0:
		return ""
	return BOSS_TRACKS[index - FIRST_BOSS] if index >= FIRST_BOSS else TRACKS[index]


func _play_track(region: int) -> void:
	if region == current_region:
		return
	var previous_region := current_region
	current_region = region
	if _track_path(region) == _track_path(previous_region):
		return
	if DisplayServer.get_name() == "headless" and not OS.has_feature("movie"):
		return
	if fade != null:
		fade.kill()
	fade = create_tween().set_parallel(true)
	var retiring: Array[AudioStreamPlayer] = []
	if region < 0:
		for voice in voices:
			if voice.playing:
				retiring.append(voice)
	else:
		var previous := voices[active]
		if previous.playing:
			retiring.append(previous)
		active = 1 - active
		var incoming := voices[active]
		incoming.stop()
		var track := load(_track_path(region)) as AudioStream
		track.loop = true
		incoming.stream = track
		incoming.volume_db = SILENT_DB
		incoming.play()
		fade.tween_method(_set_gain.bind(incoming), db_to_linear(SILENT_DB), db_to_linear(TRACK_VOLUME), FADE_TIME)
	if retiring.is_empty() and region < 0:
		fade.kill()
		return
	for voice in retiring:
		fade.tween_method(_set_gain.bind(voice), db_to_linear(voice.volume_db), db_to_linear(SILENT_DB), FADE_TIME)
	fade.chain().tween_callback(_stop_voices.bind(retiring))


func _set_gain(gain: float, voice: AudioStreamPlayer) -> void:
	voice.volume_db = linear_to_db(gain)


func _stop_voices(retiring: Array[AudioStreamPlayer]) -> void:
	for voice in retiring:
		voice.stop()


func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
