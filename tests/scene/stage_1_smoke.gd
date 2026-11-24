extends SceneTree

const Landscape := preload("res://scripts/scene/ruin_landscape.gd")

var failures := 0


func _initialize() -> void:
	run_checks.call_deferred()


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])


func run_checks() -> void:
	var scene: PackedScene = load("res://scenes/ruins/ruins.tscn")
	var ruins = scene.instantiate()
	root.add_child(ruins)
	await physics_frame

	var species: Array[String] = []
	for monster in ruins.enemies:
		species.append(monster.species)
	check(species.slice(0, 5) == ["spider", "lizard", "spider", "treant", "bell_moth"], "ruins retain the five prototype encounters")
	if failures > 0:
		quit(1)
		return

	ruins.hunter.position = ruins.landscape.portals[0].global_position
	ruins._interact()
	check(not ruins.completed, "gate stays closed until guardian is defeated")

	# Arrange combat states directly. The bridge below uses real input and physics.
	var lizard = ruins.enemies[1]
	var guardian = ruins.enemies[3]
	lizard.receive_hit(lizard.health, false)
	for drop: Dictionary in ruins.drops:
		if drop.kind == "lizard":
			drop.spawn = ruins.elapsed - 1.0
			ruins.hunter.position = drop.at + Vector2(0, 25)
	ruins._collect_drops()
	ruins._equip_next_soul()
	check(ruins.hunter.equipped_soul == "lizard", "lizard defeat yields an equippable wing soul")

	guardian.windup = 0.5
	guardian.receive_hit(1, true)
	check(not guardian.armed and ruins._has_drop("blade"), "guardian disarm yields its blade")
	guardian.receive_hit(guardian.health, false)
	check(ruins.guardian_felled and ruins.landscape.portal_open, "guardian defeat unlocks the gate")

	var hunter = ruins.hunter
	hunter.position = Vector2(743, Landscape.FLOOR_Y - 2)
	hunter.velocity = Vector2.ZERO
	for frame in range(12):
		await physics_frame
	check(hunter.is_on_floor(), "hunter is grounded at the east end of the bridge")

	Input.action_press("hunt_left")
	Input.action_press("hunt_jump")
	Input.action_press("hunt_soul")
	await physics_frame
	await physics_frame
	Input.action_release("hunt_jump")
	var glided := false
	for frame in range(180):
		await physics_frame
		glided = glided or hunter.gliding
		if hunter.position.x < 210.0:
			break
	Input.action_release("hunt_left")
	Input.action_release("hunt_soul")
	for frame in range(60):
		await physics_frame
		if hunter.is_on_floor():
			break
	check(glided and hunter.position.x < 312.0 and hunter.is_on_floor(), "jump and wing input cross the bridge onto the west platform")

	ruins._interact()
	check(ruins.completed and ruins.end_screen.visible, "west gate shows the completion screen")
	quit(0 if failures == 0 else 1)
