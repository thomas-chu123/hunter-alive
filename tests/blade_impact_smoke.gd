extends SceneTree

const Ruins := preload("res://scripts/ruins.gd")
const Monster := preload("res://scripts/ruin_monster.gd")
const HitEffects := preload("res://scripts/ruin_hit_effects.gd")

var level: Ruins
var target: Monster
var heading: Label
var releases: Array[Dictionary] = []
var release_limit := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/ruins/ruins.tscn")
	await scene_changed
	level = current_scene
	for monster: Monster in level.enemies:
		monster.queue_free()
	level.enemies.clear()
	level.camera.zoom = Vector2.ONE * 2.35
	level.camera.position.y = -91.0
	level.camera.position_smoothing_enabled = false
	level.hunter.position = Vector2(1120, 539)
	level.hunter.facing = -1.0
	level.hunter.invincible_left = 0.0
	level.hunter.attacked.connect(record_release)
	AudioServer.set_bus_mute(0, false)
	AudioServer.set_bus_volume_db(0, 0.0)
	var layer := CanvasLayer.new()
	layer.layer = 7
	level.add_child(layer)
	heading = Label.new()
	heading.position = Vector2(28, 91)
	heading.add_theme_font_override("font", level.font)
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_constant_override("outline_size", 8)
	layer.add_child(heading)
	heading.text = "獵刀｜向左空揮"
	await frames(29)

	attack(1)
	await frames(44)
	check(releases.size() == 1 and observed(0, "step") == 1 and observed(0, "direction") == -1.0
		and observed(0, "sparks") == 0 and observed(0, "scale") == 1.0,
		"leftward whiff plays a slash without impact, hitstop or shake")
	check(level.hit_effects.slashes.is_empty(), "whiff trail expires")

	heading.text = "蛛牙短刃｜正斬、反手、終結"
	level._grant_equipment("fang_dagger")
	level.hunter.select_weapon("fang_dagger")
	level.hunter.facing = 1.0
	level._add_monster("lizard", 1174)
	target = level.enemies.back()
	target.max_health = 10
	target.health = target.max_health
	await frames(18)
	var initial_hp := target.health
	attack(3)
	await frames(63)
	check(releases.size() == 4 and observed(1, "step") == 1 and observed(2, "step") == 2
		and observed(3, "step") == 3, "held attack releases stages 1, 2 and 3 in order")
	check(observed(1, "hp") == initial_hp - 2 and observed(2, "hp") == initial_hp - 4
		and observed(3, "hp") == initial_hp - 7, "fang dagger still deals 2, 2 and 3 damage")
	check(observed(1, "scale") == 0.20 and observed(3, "scale") == 0.12
		and observed(3, "shake") > observed(1, "shake"), "finisher increases hitstop and camera impulse")
	check(observed(1, "flash") and observed(2, "flash") and observed(3, "flash")
		and observed(1, "recoil") < 0.0 and observed(1, "enemy_hit"),
		"damage lights the sprite white and recoils both combatants")
	check(Engine.time_scale == 1.0 and level.camera.offset == Vector2.ZERO
		and target.actor_art.material == null and level.hit_effects.sparks.is_empty(),
		"hitstop, shake, flash and sparks all expire")

	heading.text = "蛛牙短刃｜盾牌格擋"
	level.enemies.erase(target)
	target.queue_free()
	level._add_monster("shield_heron", level.hunter.position.x + 51.0)
	target = level.enemies.back()
	target.set_physics_process(false)
	initial_hp = target.health
	attack(1)
	await frames(27)
	check(observed(4, "step") == 1, "combo returns to stage 1 after its window")
	check(observed(4, "hp") == initial_hp and observed(4, "sparks") == 1 and observed(4, "scale") == 1.0
		and not observed(4, "flash") and observed(4, "shake") == 0.0,
		"guard contact sparks without damage or a confirmed-hit reaction")
	await frames(39)

	var effects: HitEffects = level.hit_effects
	effects.clear()
	if DisplayServer.get_name() == "headless":
		# Fixed-FPS headless tests can outrun the audio mixer.
		OS.delay_msec(250)
		await process_frame
	Engine.time_scale = 0.85
	effects._punctuate_hit(1.0, false)
	effects._punctuate_hit(1.0, true)
	effects.clear()
	check(Engine.time_scale == 0.85 and level.camera.offset == Vector2.ZERO,
		"clearing overlapping hitstops restores the prior slowdown and camera offset")
	effects._punctuate_hit(-1.0, false)
	effects.queue_free()
	await process_frame
	await process_frame
	check(Engine.time_scale == 0.85 and level.camera.offset == Vector2.ZERO,
		"freeing the effect owner during hitstop restores time and camera offset")
	Engine.time_scale = 1.0
	if DisplayServer.get_name() != "headless" or OS.has_feature("movie"):
		root.get_node("GameMusic").play_region(-1)
		await frames(66)
	quit(1 if failures else 0)


func attack(count: int) -> void:
	release_limit = releases.size() + count
	Input.action_press("hunt_attack")


func record_release(_origin: Vector2, direction: float, _ranged: bool, _damage: int, _weapon: String) -> void:
	var has_target := is_instance_valid(target)
	releases.append({
		"step": level.hit_effects.slashes.back().step,
		"direction": direction,
		"hp": target.health if has_target else -1,
		"sparks": level.hit_effects.sparks.size(),
		"scale": Engine.time_scale,
		"shake": level.camera.offset.length(),
		"flash": has_target and target.actor_art.material != null,
		"recoil": level.hunter.blade_recoil,
		"enemy_hit": has_target and target.hit_left > 0.0,
	})
	print("%5.2fs release %s" % [Engine.get_process_frames() / 60.0, releases.back()])
	if releases.size() >= release_limit:
		Input.action_release("hunt_attack")


func observed(index: int, key: String) -> Variant:
	return releases[index][key] if index < releases.size() else 0


func frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func check(passed: bool, message: String) -> void:
	print("%s %s" % ["PASS" if passed else "FAIL", message])
	if not passed:
		failures += 1
