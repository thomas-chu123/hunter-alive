extends SceneTree

const Campaign := preload("res://scripts/game/campaign.gd")
const Save := preload("res://scripts/game/camp_save.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	if "--court-grounding" in OS.get_cmdline_user_args():
		await check_court_grounding()
		quit(1 if failures else 0)
		return
	change_scene_to_file(Campaign.SCENES[Campaign.Region.TEMPLE])
	await scene_changed
	var level = current_scene
	check(level.region == Campaign.Region.TEMPLE, "new game starts in the temple")
	await view()

	# Stage 1 exercises the temple's full input route. Begin this fixture at its exit.
	level.hunter.bow_level = 2
	level.hunter.with_bow = true
	level.collected_souls.append("lizard")
	level.hunter.equipped_soul = "lizard"
	level.guardian_felled = true
	await stand(level, level.landscape.portals[0].global_position.x)
	await tap("hunt_interact")
	check(level.completed, "temple west gate opens the transition card")
	await view()
	await key(KEY_E)
	await scene_changed
	level = current_scene
	check(level.region == Campaign.Region.CORRIDOR and Save.read().state.region == Campaign.Region.CORRIDOR, "corridor transition saves its arrival checkpoint")
	check(level.hunter.with_bow and level.hunter.bow_level == 2 and level.hunter.equipped_soul == "lizard", "weapon and wing soul survive the transition")
	await view()
	check(level.landscape.get_node("Darkness").visible and not level.landscape.light_gates[0].get_node("Collision").disabled,
		"dark waterway blocks passage before collecting its lantern")
	await stand(level, level.landscape.portals[0].global_position.x)
	await tap("hunt_interact")
	check(current_scene == level and not level.transitioning, "corridor exit stays locked without lantern")
	var crab = enemy(level, "lantern_crab")
	await stand(level, crab.position.x - 120.0)
	await wait_for_windup(crab)
	check(crab.armed and crab.windup > 0.0, "crab telegraphs the lantern opportunity")
	await view(0.12)
	await shoot()
	check(not crab.armed and level._has_drop("lantern"), "real bow input knocks the lantern loose")
	await view(0.25)
	await stand(level, find_drop(level, "lantern"))
	await frames(18)
	check(level.lantern_found and not level.landscape.get_node("Darkness").visible and level.landscape.light_gates[0].get_node("Collision").disabled,
		"picking up the lantern illuminates the route and opens the physical gate")
	await view()
	await stand(level, level.landscape.campfires[0].global_position.x)
	await tap("hunt_interact")
	await press(level.camp_save_exit)
	await scene_changed
	await press(current_scene.continue_game)
	await scene_changed
	level = current_scene
	check(level.region == Campaign.Region.CORRIDOR and level.lantern_found, "Continue restores the correct camp and lantern")
	await stand(level, level.landscape.portals[0].global_position.x)
	await tap("hunt_interact")
	for index in range(15):
		if current_scene != null and current_scene.region == Campaign.Region.COURT:
			break
		await process_frame
	level = current_scene
	check(level.region == Campaign.Region.COURT, "lit exit advances to the buried court")
	if level.region != Campaign.Region.COURT:
		quit(1)
		return
	await view()
	await stand(level, level.landscape.portals[0].global_position.x)
	await tap("hunt_interact")
	check(not level.completed, "court altar stays sealed while keeper lives")

	var keeper = enemy(level, "seal_keeper")
	await stand(level, keeper.position.x + 190.0, -1.0)
	for shot in range(12):
		if keeper.second_phase:
			break
		await shoot()
	check(keeper.second_phase and keeper.armed and keeper.health == 13, "keeper enters its shield phase at half health")
	await view(0.16)
	await stand(level, minf(keeper.position.x + 151.0, 3180.0), -1.0)
	await wait_for_windup(keeper)
	await shoot()
	check(keeper.second_phase and not keeper.armed, "bow input hits the keeper's glowing seal and shatters the shield")
	await view(0.18)
	for shot in range(14):
		if not is_instance_valid(keeper):
			break
		await shoot()
	check(level.keeper_felled, "keeper can be defeated after seal breaks")
	await stand(level, level.landscape.portals[0].global_position.x)
	await tap("hunt_interact")
	check(level.completed and level.end_screen.visible and Save.read().state.keeper_felled,
		"altar shows the ending and persists boss victory")
	await view()
	if DisplayServer.get_name() == "headless" and not OS.has_feature("movie"):
		# A fixed-FPS test outpaces the real-time dummy audio mixer.
		level.hit_effects.clear()
		OS.delay_msec(250)
		await process_frame
	var ending_input_handled := await key(KEY_E)
	if current_scene == null:
		await scene_changed
	check(ending_input_handled and current_scene != null and current_scene.scene_file_path == "res://scenes/title/title.tscn",
		"ending consumes the interaction before returning to the title")
	await view()
	quit(1 if failures else 0)


func check_court_grounding() -> void:
	change_scene_to_file("res://scenes/buried_court/buried_court.tscn")
	await scene_changed
	var level := current_scene as Ruins
	for monster in level.enemies:
		monster.queue_free()
	level.enemies.clear()
	level.notice_left = 0.0
	level.camera.zoom = Vector2.ONE * 1.8
	level.camera.position.y = -102
	level.camera.position_smoothing_enabled = false
	level._grant_equipment("tide_hammer")
	var hunter := level.hunter
	hunter.select_weapon("tide_hammer")
	var terrain: TileMapLayer = level.landscape.get_node("Terrain")
	var landing_cell := terrain.local_to_map(Vector2(780, 485))
	var tile := terrain.get_cell_tile_data(landing_cell)
	check(tile != null and tile.get_collision_polygons_count(0) > 0,
		"first raised court platform has tile collision")
	var landing_y := terrain.map_to_local(landing_cell).y - terrain.tile_set.tile_size.y * 0.5
	var shrine := level.landscape.campfires[0]
	var brazier: Sprite2D = shrine.get_node("Sprite")
	var brazier_width := brazier.get_rect().size.x * brazier.scale.x
	var brazier_base := brazier.get_rect().end.y * brazier.scale.y
	check(brazier_width <= 86.0 and absf(brazier_base) < 4.0,
		"court brazier is %.1f px wide and its base sits on the floor" % brazier_width)
	await frames(24)
	check(hunter.is_on_floor() and absf(hunter.position.y - shrine.global_position.y) < 0.25,
		"hunter stands at the floor beside the brazier")
	await tap("hunt_interact")
	check(level.camp_menu.visible, "interact still opens the court camp")
	await frames(19)
	await key(KEY_ESCAPE)
	await frames(6)

	Input.action_press("hunt_right")
	await frames(33)
	Input.action_release("hunt_right")
	await frames(16)
	check(hunter.is_on_floor() and absf(hunter.position.y - shrine.global_position.y) < 0.25,
		"hunter walks along the floor without sinking")
	await stand(level, 640.0)
	Input.action_press("hunt_right")
	await tap("hunt_jump")
	await frames(35)
	Input.action_release("hunt_right")
	await frames(20)
	check(hunter.is_on_floor() and absf(hunter.position.y - landing_y) < 0.25,
		"hunter lands on the raised stone platform")
	await frames(17)


func enemy(level: Node, species: String) -> Node2D:
	for candidate in level.enemies:
		if candidate.species == species:
			return candidate
	return null


func find_drop(level: Node, kind: String) -> float:
	for drop in level.drops:
		if drop.kind == kind:
			return drop.at.x
	return level.hunter.position.x


func stand(level: Node, x: float, facing: float = 1.0) -> void:
	level.hunter.position = Vector2(x, 538)
	level.hunter.velocity = Vector2.ZERO
	level.hunter.facing = facing
	await frames(5)


func wait_for_windup(target: Node2D) -> void:
	for index in range(210):
		if target.windup > 0.48:
			return
		await physics_frame


func shoot() -> void:
	await tap("hunt_attack")
	await frames(24)


func tap(action: StringName) -> void:
	Input.action_press(action)
	await frames(3)
	Input.action_release(action)


func press(button: Button) -> void:
	button.grab_focus()
	await key(KEY_ENTER)


func key(code: Key) -> bool:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	var handled := root.is_input_handled()
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)
	return handled


func frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func view(seconds: float = 0.7) -> void:
	await create_timer(seconds).timeout


func check(passed: bool, title: String) -> void:
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", title])
