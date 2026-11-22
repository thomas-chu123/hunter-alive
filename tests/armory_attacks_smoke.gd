extends SceneTree

const Ruins := preload("res://scripts/ruins.gd")
const Equipment := preload("res://scripts/ruin_equipment.gd")
const Armory := preload("res://scripts/ruin_armory.gd")
const Monster := preload("res://scripts/ruin_monster.gd")
const HunterAnimation := preload("res://scripts/hunter_animation.gd")
const ORDER := ["sluice_spear", "tide_hammer", "gate_halberd", "root_blade", "fang_dagger",
	"thorn_bow", "scribe_staff", "ember_staff", "hunter_bow", "hunter_knife"]

var level: Ruins
var failed := false
var releases := 0
var audio_signatures := {}


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/ruins.tscn")
	await scene_changed
	level = current_scene
	var hunter := level.hunter
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	level.notice_left = 0.0
	level.camera.zoom = Vector2.ONE * 2.35
	level.camera.position.y = -81.0
	level.camera.position_smoothing_enabled = false
	hunter.position = Vector2(1255.0, 539.0)
	root.get_node("GameMusic").play_region(-1)
	AudioServer.set_bus_volume_db(0, 0.0)
	hunter.attacked.connect(_on_attack)
	hunter.cast.connect(_on_cast)
	for weapon in Armory.WEAPONS:
		level._grant_equipment(weapon)
	level._grant_equipment("ember_staff")
	await frames(62)

	for weapon in ORDER:
		await key(KEY_I)
		await frames(3)
		if hunter.selected_weapon() != weapon:
			var index := level.gear_ids.find(weapon)
			level.gear_list.select(index)
			level.gear_list.item_selected.emit(index)
			await key(KEY_E)
		check(hunter.selected_weapon() == weapon, "equipped through inventory: " + weapon)
		check(level.gear_portrait_pose.is_visible_in_tree() == (weapon != "hunter_knife"), "portrait matches weapon: " + weapon)
		var base_size := level.gear_portrait_base.get_size()
		var portrait_size := level.gear_portrait.size
		var base_height := minf(portrait_size.y, base_size.y * portrait_size.x / base_size.x)
		var pose_height := base_size.y * HunterAnimation.SCALE * level.gear_portrait_pose.scale.y
		check(is_equal_approx(pose_height, base_height)
			and is_equal_approx(level.gear_portrait_pose.position.y, (portrait_size.y + base_height) * 0.5),
			"portrait keeps the original body size and foot position: " + weapon)
		await frames(22 if weapon == "sluice_spear" else 8)
		await key(KEY_I)
		await frames(9)
		var before := releases
		await key(KEY_J)
		await frames(ceili(hunter.weapon_period(weapon) * 60.0) + 11)
		check(releases == before + 1, "one release: " + weapon)
		if weapon == "scribe_staff":
			await frames(24)
		check(hunter.attack_left == 0.0, "returns to held pose: " + weapon)
	check(audio_signatures.size() == ORDER.size(), "all ten weapons have distinct release samples")

	hunter.select_weapon("sluice_spear")
	level._add_monster("lizard", hunter.position.x + 108.0)
	var target := level.enemies.back() as Monster
	target.set_physics_process(false)
	target.health = 12
	await key(KEY_J)
	await frames(36)
	check(target.health == 12 - hunter.weapon_damage("sluice_spear"), "spear damages an enemy beyond short-knife reach")
	await frames(12)
	quit(1 if failed else 0)


func _on_attack(_origin: Vector2, _facing: float, ranged: bool, _damage: int, weapon: String) -> void:
	check(ranged == (weapon in ["hunter_bow", "thorn_bow"]), "ranged routing: " + weapon)
	if ranged:
		check(level.arrows.back().weapon == weapon and level.arrows.back().pierce == int(weapon == "thorn_bow"),
			"arrow keeps its projectile behavior: " + weapon)
	_observe_release(weapon)


func _on_cast(_origin: Vector2, _facing: float, weapon: String) -> void:
	var spawned: bool = not level.glyphs.is_empty() if weapon == "scribe_staff" else not level.arrows.is_empty() and level.arrows.back().spell
	check(spawned, "staff creates its own spell: " + weapon)
	_observe_release(weapon)


func _observe_release(weapon: String) -> void:
	releases += 1
	var effects := level.hit_effects
	var voice: AudioStreamPlayer
	match weapon:
		"hunter_bow": voice = effects.bow_voice
		"hunter_knife": voice = effects.swing_voice
		_: voice = effects.weapon_voices.get(weapon)
	check(is_instance_valid(voice) and voice.stream is AudioStreamWAV, "weapon sample selected: " + weapon)
	if is_instance_valid(voice) and voice.stream is AudioStreamWAV:
		var sample := voice.stream as AudioStreamWAV
		audio_signatures[sample.data.hex_encode().sha256_text()] = true
		if DisplayServer.get_name() != "headless" or OS.has_feature("movie"):
			check(voice.playing, "weapon sample plays: " + weapon)
	print("RELEASE frame=%d weapon=%s label=%s" % [Engine.get_process_frames(), weapon, Equipment.item(weapon)[0]])


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)


func frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func check(condition: bool, message: String) -> void:
	failed = failed or not condition
	print("%s %s" % ["PASS" if condition else "FAIL", message])
