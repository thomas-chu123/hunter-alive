extends Node

const TITLE := 4
const FINALE := "res://assets/audio/music/the_hunter_finale.ogg"
const TRACKS := [
	"res://assets/audio/music/the_hunter_temple.ogg",
	"res://assets/audio/music/the_hunter_corridor.ogg",
	FINALE,
	FINALE,
	"res://assets/audio/music/the_hunter_title.ogg",
]
const FIRST_BOSS := 5
const BOSS_TRACKS := [
	"res://assets/audio/music/boss_temple.mp3",
	"res://assets/audio/music/boss_corridor.mp3",
	"res://assets/audio/music/boss_court.mp3",
	"res://assets/audio/music/boss_caldera.mp3",
	"res://assets/audio/music/boss_caldera_final.mp3",
]
const TRACK_VOLUME := -5.0
const FADE_TIME := 0.95
const SILENT_DB := -60.0

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
	if final_phase and ResourceLoader.exists(BOSS_TRACKS[-1]):
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
