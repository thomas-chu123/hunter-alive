extends SceneTree

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const Monster := preload("res://scripts/character/ruin_monster.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")

var level: Ruins
var caption: Label
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/flooded_corridor/flooded_corridor.tscn")
	await scene_changed
	level = current_scene
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	level.lantern_found = true
	level._sync_region_gate()
	level.camera.zoom = Vector2.ONE * 2.35
	level.camera.position.y = -88.0
	level.camera.position_smoothing_enabled = false
	make_caption()
	var roster_size := 0
	for id in Bestiary.creatures:
		await test_knife(id)
		roster_size += 1
	check(roster_size == 21, "all 20 ordinary species and the final boss were exercised")
	await check_protected_attacks()
	if DisplayServer.get_name() == "headless":
		level.hit_effects.clear()
		OS.delay_msec(250)
		await process_frame
	else:
		change_scene_to_file("res://scenes/title/title.tscn")
		await scene_changed
		await frames(75)
	quit(1 if failures else 0)


func test_knife(id: String) -> void:
	prepare_hunter(856.0)
	caption.text = "%s｜短刀命中後的硬直與後仰" % Bestiary.creatures[id].name
	var monster := spawn(id)
	# Arrange the same vulnerable recovery window for every species.
	monster._start_recovery(0.79)
	if id == "shield_heron":
		# The rear is exposed while the bird is looking away from the hunter.
		monster.facing = 1.0
		monster.visual_turn = 1.0
	await frames(6)
	var start_hp := monster.health
	if id == "bell_moth":
		await tap("hunt_jump")
		await frames(5)
	await tap("hunt_attack")
	for _frame in range(22):
		if monster.state == Monster.State.STAGGER:
			break
		await physics_frame
	check(monster.health < start_hp and monster.state == Monster.State.STAGGER and monster.hit_left > 0.0,
		"%s visibly staggers from real knife input" % id)
	var before := monster.position.x
	var moved := 0.0
	var time := 0
	while monster.state == Monster.State.STAGGER and time < 30:
		await physics_frame
		var travel := monster.hover_recoil if id == "bell_moth" else monster.position.x - before
		moved = maxf(moved, travel)
		time += 1
	var profile: Dictionary = monster.hit_reaction
	check(moved > 1.1 and absf(time / 60.0 - float(profile.duration)) < 0.035
		and monster.state == Monster.State.RECOVER and monster.recovery > 0.0,
		"%s backs away %.1f px over %d frames and resumes its recovery" % [id, moved, time])
	await frames(26)
	remove(monster)


func check_protected_attacks() -> void:
	prepare_hunter(856.0)
	caption.text = "護甲、重型蓄力與首領護印"
	var beetle := spawn("shale_beetle")
	beetle.receive_hit(1, false, false, "hunter_knife", 1.0)
	check(beetle.health == beetle.max_health and beetle.state != Monster.State.STAGGER,
		"closed shell absorbs the knife without staggering")
	remove(beetle)

	var treant := spawn("treant")
	await physics_frame
	treant._begin_windup()
	treant.receive_hit(1, false, false, "hunter_knife", 1.0)
	check(treant.hit_left > 0.0 and treant.windup > 0.0 and treant.state == Monster.State.WINDUP,
		"treant visibly flinches while staying committed to a heavy windup")
	remove(treant)

	var keeper := spawn("seal_keeper")
	await physics_frame
	keeper.receive_hit(keeper.max_health, false, false, "hunter_knife", 1.0)
	check(keeper.health == 13 and keeper.second_phase and keeper.armed and not keeper.is_queued_for_deletion(),
		"even lethal damage enters the keeper's seal phase")
	keeper.receive_hit(5, false, false, "hunter_knife", 1.0)
	check(keeper.health == 13 and keeper.state != Monster.State.STAGGER, "the intact seal still prevents damage and stagger")
	keeper._begin_windup()
	keeper.receive_hit(1, true, true, "hunter_bow", 1.0)
	check(not keeper.armed and keeper.recovery > 0.0 and keeper.hit_left > 0.0,
		"shooting the seal during windup starts the existing disarm recovery")
	await frames(44)
	remove(keeper)


func prepare_hunter(x: float) -> void:
	level.hunter.position = Vector2(x, 539.0)
	level.hunter.velocity = Vector2.ZERO
	level.hunter.facing = 1.0
	level.hunter.invincible_left = 0.0
	level.hunter.hurt_left = 0.0
	level.hunter.rest()


func spawn(id: String) -> Monster:
	level._add_monster(id, 920.0)
	return level.enemies.back()


func remove(monster: Monster) -> void:
	level.enemies.erase(monster)
	monster.queue_free()
	level.arrows.clear()


func make_caption() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 7
	level.add_child(overlay)
	caption = Label.new()
	caption.position = Vector2(25, 93)
	caption.add_theme_font_override("font", level.font)
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_constant_override("outline_size", 7)
	overlay.add_child(caption)


func tap(action: StringName) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)


func frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func check(passed: bool, message: String) -> void:
	if not passed:
		failures += 1
	print("%5.2fs %s %s" % [Engine.get_physics_frames() / 60.0, "PASS" if passed else "FAIL", message])
