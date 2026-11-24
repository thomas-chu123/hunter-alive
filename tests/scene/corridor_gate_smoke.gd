extends SceneTree

const Ruins := preload("res://scripts/scene/ruins.gd")
const Monster := preload("res://scripts/character/ruin_monster.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/flooded_corridor/flooded_corridor.tscn")
	await scene_changed
	var level: Ruins = current_scene
	var crab: Monster
	for enemy in level.enemies.duplicate():
		if enemy.species == "lantern_crab":
			crab = enemy
		else:
			level.enemies.erase(enemy)
			enemy.queue_free()
	crab.set_physics_process(false)
	var hunter := level.hunter
	var gate: StaticBody2D = level.landscape.light_gates[0]
	var barrier: CollisionShape2D = gate.get_node("Collision")
	var darkness: Sprite2D = level.landscape.get_node("Darkness")
	hunter.equipped_soul = "spider"
	hunter.position = Vector2(1380, 539)
	level.camera.zoom = Vector2.ONE * 1.9
	level.camera.position.y = -115
	level.camera.position_smoothing_enabled = false
	await frames(27)
	Input.action_press("hunt_right")
	await frames(19)
	Input.action_press("hunt_jump")
	Input.action_press("hunt_soul")
	var gate_climbed := false
	for frame in range(48):
		await process_frame
		gate_climbed = gate_climbed or hunter.wall_holding
	release_motion()
	check(hunter.position.x < gate.global_position.x and not gate_climbed and not barrier.disabled,
		"locked gate stops the hunter and cannot be climbed")
	check(darkness.visible and darkness.z_index < hunter.z_index,
		"locked corridor tint draws behind the hunter and foreground")

	hunter.position = Vector2(1125, 539)
	hunter.velocity = Vector2.ZERO
	hunter.facing = 1.0
	crab.health = 1
	await frames(24)
	Input.action_press("hunt_attack")
	await frames(13)
	Input.action_release("hunt_attack")
	check(not is_instance_valid(crab) and level._has_drop("lantern"), "one-HP crab dies to a normal melee hit and drops its lantern")
	await frames(24)
	Input.action_press("hunt_right")
	await frames(100)
	Input.action_release("hunt_right")
	check(level.lantern_found and barrier.disabled and not darkness.visible
		and not gate.get_node("Bar").visible and gate.get_node("Arch").visible
		and hunter.position.x > gate.global_position.x, "lantern clears the grate and tint, preserves the arch and allows walking through")

	hunter.position = Vector2(1505, 539)
	hunter.velocity = Vector2.ZERO
	await frames(25)
	Input.action_press("hunt_right")
	Input.action_press("hunt_jump")
	Input.action_press("hunt_soul")
	var climb_frames := 0
	for frame in range(25):
		await process_frame
		if hunter.wall_holding:
			climb_frames += 1
	release_motion()
	check(climb_frames >= 4 and hunter.position.y < 490.0,
		"Spider Step climbs the real landing beyond the gate for %d frames" % climb_frames)
	await frames(25)
	level.hit_effects.clear()
	if DisplayServer.get_name() == "headless":
		OS.delay_msec(250)
		await process_frame
	else:
		root.get_node("GameMusic").play_region(-1)
		await frames(77)
	quit(1 if failures else 0)


func release_motion() -> void:
	for action in ["hunt_right", "hunt_jump", "hunt_soul"]:
		Input.action_release(action)


func frames(count: int) -> void:
	for index in range(count):
		await process_frame


func check(condition: bool, message: String) -> void:
	print("%.2fs %s %s" % [Engine.get_process_frames() / 60.0, "PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1
