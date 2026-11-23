extends SceneTree

const Monster := preload("res://scripts/character/ruin_monster.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")
const ARTIFACT_DIR := "/Users/skynet/.gemini/antigravity/brain/3420e472-ba92-485f-8fd8-607dd789e8a9"

var level: Ruins
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		printerr("FAIL ", message)


func run() -> void:
	print("--- Starting Monster Locomotion Smoke Verification ---")
	change_scene_to_file("res://scenes/flooded_corridor/flooded_corridor.tscn")
	await scene_changed
	level = current_scene

	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	level.lantern_found = true
	level._sync_region_gate()

	var hunter = level.hunter
	check(hunter != null, "Ruins hunter initialized")

	# Spawn burial_ram at x=800 on flat open corridor
	level._add_monster("burial_ram", 800.0)
	var monster: Monster = level.enemies.back()
	check(monster != null, "Spawned burial_ram for procedural locomotion testing")

	# Setup camera on monster
	level.camera.position_smoothing_enabled = false
	level.camera.zoom = Vector2(2.0, 2.0)
	level.camera.position = monster.position + Vector2(0, -60)

	# Put hunter far away so monster enters natural PATROL state
	hunter.position = Vector2(1600.0, 539.0)
	hunter.velocity = Vector2.ZERO

	var observed_dust := false
	var max_dust_count := 0
	var min_stretch_y := 1.0
	var max_stretch_y := 1.0
	var min_stretch_x := 1.0
	var max_stretch_x := 1.0
	var observed_travel := 0.0
	var initial_x := monster.position.x

	# 1. Test Patrol Locomotion & Dust Generation
	print("--- Phase 1: Testing Patrol Locomotion & Gait ---")
	for frame in range(120):
		await physics_frame
		if monster.walking:
			observed_travel += absf(monster.velocity.x) * (1.0 / 60.0)
		if monster.foot_dust.size() > 0:
			observed_dust = true
			max_dust_count = maxi(max_dust_count, monster.foot_dust.size())
		min_stretch_y = minf(min_stretch_y, monster.stretch_y)
		max_stretch_y = maxf(max_stretch_y, monster.stretch_y)
		min_stretch_x = minf(min_stretch_x, monster.stretch_x)
		max_stretch_x = maxf(max_stretch_x, monster.stretch_x)

	await process_frame

	# Center camera right at monster for clean screenshot
	level.camera.position = monster.position + Vector2(0, -50)
	await process_frame

	# Capture Patrol Locomotion Screenshot
	var img_patrol = root.get_viewport().get_texture().get_image()
	if img_patrol != null:
		var err = img_patrol.save_png(ARTIFACT_DIR + "/monster_locomotion_patrol.png")
		check(err == OK, "Saved monster locomotion patrol screenshot")

	check(observed_travel > 15.0 or absf(monster.position.x - initial_x) > 15.0,
		"Monster walked along patrol route (traveled %.1f px)" % observed_travel)
	check(monster.gait_distance > 10.0, "Monster gait distance advanced dynamically (gait_distance: %.2f)" % monster.gait_distance)
	check(observed_dust, "Ground dust puffs generated during footsteps (max active dust: %d)" % max_dust_count)
	check(min_stretch_y < 0.99 and max_stretch_y > 1.01,
		"Organic squash and stretch dynamic range verified (stretch_y: %.3f - %.3f)" % [min_stretch_y, max_stretch_y])
	check(min_stretch_x < 0.99 and max_stretch_x > 1.01,
		"Volume-conserving horizontal stretch dynamic range verified (stretch_x: %.3f - %.3f)" % [min_stretch_x, max_stretch_x])
	check(monster.bob_y < -0.1, "Vertical stride bobbing is active during walking (bob_y: %.2f)" % monster.bob_y)

	# 2. Test Smooth Turnaround Transition
	print("--- Phase 2: Testing Turnaround Direction Smoothness ---")
	monster.facing = -monster.facing
	monster.patrol_dir = monster.facing

	var seen_intermediate_turn := false
	for frame in range(40):
		await physics_frame
		if absf(monster.visual_turn) > 0.05 and absf(monster.visual_turn) < 0.95:
			seen_intermediate_turn = true

	await process_frame
	# Capture Turnaround Screenshot
	var img_turn = root.get_viewport().get_texture().get_image()
	if img_turn != null:
		var err = img_turn.save_png(ARTIFACT_DIR + "/monster_locomotion_turnaround.png")
		check(err == OK, "Saved monster locomotion turnaround screenshot")

	check(seen_intermediate_turn, "Visual turn smoothly interpolated across directional flip instead of popping")

	# 3. Test Sprint Lean During Chase
	print("--- Phase 3: Testing Sprint Lean During Chase ---")
	# Place hunter in front of monster within sight & leash range
	hunter.position = monster.position + Vector2(180.0 * monster.facing, 0)
	for frame in range(60):
		await physics_frame
		if monster.state == Monster.State.CHASE:
			break

	var observed_sprint_lean := 0.0
	for frame in range(60):
		await physics_frame
		if absf(monster.velocity.x) > 40.0:
			observed_sprint_lean = maxf(observed_sprint_lean, absf(monster.sprint_lean))

	print("Max sprint lean observed during chase: ", observed_sprint_lean, " rad")
	check(observed_sprint_lean > 0.02,
		"Monster leans forward organically when sprinting towards player (lean: %.3f rad)" % observed_sprint_lean)

	print("--- Locomotion Verification Complete. Failures: ", failures, " ---")
	quit(1 if failures > 0 else 0)
