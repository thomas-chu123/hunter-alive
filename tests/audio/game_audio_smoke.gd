extends SceneTree

const Ruins := preload("res://scripts/scene/ruins.gd")
const Monster := preload("res://scripts/character/ruin_monster.gd")
const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const EnemyAudio := preload("res://scripts/sound/ruin_enemy_audio.gd")
const Music := preload("res://scripts/music/game_music.gd")
const ScenePaths := ["res://scenes/ruins/ruins.tscn", "res://scenes/flooded_corridor/flooded_corridor.tscn", "res://scenes/buried_court/buried_court.tscn"]
const MusicLabels := ["崩塌神殿｜背景音樂", "淹沒的迴廊｜背景音樂淡入", "埋碑內庭｜背景音樂換曲"]

var level: Ruins
var caption: Label
var music: Music
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check_sound_catalog()
	if DisplayServer.get_name() == "headless" and not OS.has_feature("movie"):
		print("SKIP audio playback checks: use a Godot window or --write-movie.")
		quit(1 if failures else 0)
		return
	music = root.get_node("GameMusic")
	await enter(0)
	await enter(1)
	await encounter("spider", 900.0, 1130.0, "石縫巨蛛｜爪步與毒牙攻擊", "step_claw", "strike_fang")
	await encounter("tide_salamander", 900.0, 1190.0, "潮汐蠑螈｜移動與水彈施放", "step_claw", "cast_water")
	await enter(2)
	await encounter("seal_keeper", 430.0, 670.0, "古門封印者｜重甲腳步與兩段揮擊", "step_metal", "strike_metal")
	await volume_menu()
	change_scene_to_file("res://scenes/title/title.tscn")
	await scene_changed
	await frames(82)
	var title_voice := music.voices[music.active]
	check(music.current_region == Music.TITLE and title_voice.playing
		and title_voice.stream.resource_path == Music.TRACKS[Music.TITLE] and not music.voices[1 - music.active].playing,
		"returning to the title crossfades to its own track")
	quit(1 if failures else 0)


func check_sound_catalog() -> void:
	var configured := 0
	for design in Bestiary.creatures.values():
		var profile: Dictionary = design.sound
		var has_cadence := float(profile.get("flap_period", profile.spacing)) > 0.0
		var has_attack := EnemyAudio.ATTACKS.has(profile.attack)
		var has_alternate := EnemyAudio.ATTACKS.has(profile.get("unarmed_attack", profile.attack))
		if EnemyAudio.STEPS.has(profile.step) and has_cadence and has_attack and has_alternate:
			configured += 1
	check(configured == 21, "all 21 monsters have valid movement and attack sound settings")
	for track in Music.TRACKS:
		var stream := load(track) as AudioStreamOggVorbis
		check(stream != null and stream.get_length() > 18.0, "loop source is available for " + track.get_file())


func enter(region: int) -> void:
	var previous := music.voices[music.active]
	change_scene_to_file(ScenePaths[region])
	await scene_changed
	level = current_scene
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	level.camera.zoom = Vector2.ONE * 1.72
	level.camera.position.y = -119
	level.camera.position_smoothing_enabled = false
	var layer := CanvasLayer.new()
	layer.layer = 7
	level.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(30, 91)
	caption.add_theme_font_override("font", level.font)
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(caption)
	caption.text = MusicLabels[region]
	await frames(22)
	var voice := music.voices[music.active]
	check(music.current_region == region and voice.playing and voice.stream.resource_path == Music.TRACKS[region]
		and voice.stream.loop, "region %d starts its own BGM with looping enabled" % region)
	if region > 0:
		check(previous.playing and previous != voice and previous.volume_db < Music.TRACK_VOLUME,
			"previous and next BGM overlap during fade")
	await frames(125)
	check(is_equal_approx(voice.volume_db, Music.TRACK_VOLUME) and not music.voices[1 - music.active].playing,
		"crossfade settles with one audible track")


func encounter(id: String, x: float, enemy_x: float, heading: String, step: String, attack: String) -> void:
	caption.text = heading
	level.hunter.position = Vector2(x, 539)
	level.hunter.rest()
	level.hunter.invincible_left = 0.0
	level.hunter.hurt_left = 0.0
	level._add_monster(id, enemy_x)
	var monster: Monster = level.enemies.back()
	var heard_step := false
	var recorded_attack := false
	var strikes := 0
	for frame in range(250):
		await physics_frame
		if monster.step_voice.playing and not heard_step:
			heard_step = true
			stamp(id + " footsteps")
		if monster.impact_index > strikes:
			strikes = monster.impact_index
			if monster.attack_voice.playing:
				stamp(id + " release " + str(strikes))
				recorded_attack = true
			if strikes >= int(monster.attack.get("hits", 1)):
				break
	check(heard_step and monster.step_voice.stream.resource_path.ends_with(step + ".wav"), id + " uses its movement clip")
	check(recorded_attack and strikes == int(monster.attack.get("hits", 1))
		and monster.attack_voice.stream.resource_path.ends_with(attack + ".wav"), id + " uses its attack clip during release")
	await frames(53)
	level.enemies.erase(monster)
	monster.queue_free()
	level.arrows.clear()
	level.hit_effects.clear()


func volume_menu() -> void:
	caption.text = "暫停選單｜主音量靜音與恢復"
	await key(KEY_ESCAPE)
	check(level.pause_menu.visible, "Escape opens the actual pause menu")
	await key(KEY_HOME)
	check(AudioServer.is_bus_mute(0), "pause settings mute the master bus")
	stamp("MUTE_START")
	await frames(100)
	await key(KEY_END)
	check(not AudioServer.is_bus_mute(0) and is_zero_approx(AudioServer.get_bus_volume_db(0)),
		"pause settings restore the master bus")
	stamp("MUTE_END")
	await key(KEY_ESCAPE)
	await frames(100)


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	var up := event.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up, true)


func frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func check(passed: bool, message: String) -> void:
	if not passed:
		failures += 1
	stamp("%s %s" % ["PASS" if passed else "FAIL", message])


func stamp(message: String) -> void:
	print("%5.2fs %s" % [Engine.get_process_frames() / 60.0, message])
