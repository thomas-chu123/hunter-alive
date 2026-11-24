extends SceneTree

const Monster := preload("res://scripts/character/ruin_monster.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")
const Art := preload("res://scripts/character/ruin_sprite_art.gd")

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
	change_scene_to_file("res://scenes/flooded_corridor/flooded_corridor.tscn")
	await scene_changed
	level = current_scene
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	level.lantern_found = true
	level._sync_region_gate()

	var hunter := level.hunter
	hunter.position = Vector2(1600.0, 539.0)
	hunter.velocity = Vector2.ZERO
	level._add_monster("burial_ram", 800.0)
	var monster: Monster = level.enemies.back()

	var walked := {}
	var turned := {}
	var dust := false
	for frame in range(240):
		await physics_frame
		var cell := monster._locomotion_cell()
		if cell.y == Art.Locomotion.WALK and monster.walking:
			walked[cell.x] = true
		elif cell.y == Art.Locomotion.TURN:
			turned[cell.x] = true
		dust = dust or not monster.foot_dust.is_empty()
	check(walked.size() == 4 and monster.gait_distance > 10.0, "Patrol advances all four walk frames by ground travel")
	check(turned.size() > 1, "Changing patrol direction advances through turn frames")
	check(dust, "Footsteps still produce dust while patrolling")

	# Keep the target visible and beyond melee range during the chase.
	hunter.set_physics_process(false)
	var direction := monster.facing
	var ran := {}
	for frame in range(90):
		hunter.position = monster.position + Vector2(170.0 * direction, 0.0)
		await physics_frame
		var cell := monster._locomotion_cell()
		if monster.state == Monster.State.CHASE and cell.y == Art.Locomotion.RUN:
			ran[cell.x] = true
	check(ran.size() > 1, "Chasing uses consecutive frames from the run row")
	print("Locomotion verification: %d failures" % failures)
	quit(1 if failures else 0)
