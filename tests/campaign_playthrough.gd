extends "res://tests/stage_1_playthrough.gd"

const Save := preload("res://scripts/camp_save.gd")
const REGION := ["temple", "corridor", "court"]

var start_frame := 0
var route: FileAccess
var latest_region := -1
var deaths := 0


func run() -> void:
	var trace_path := OS.get_environment("ULTIMA_ROUTE_CSV")
	if not trace_path.is_empty():
		route = FileAccess.open(trace_path, FileAccess.WRITE)
		if route == null:
			push_error("Unable to open route trace: " + trace_path)
			quit(1)
			return
		route.store_csv_line(PackedStringArray(["seconds", "region", "x", "y", "hp", "event"]))
	if not verify(Save.read().get("state", {}).is_empty(), "isolated profile has no checkpoint"):
		return
	change_scene_to_file("res://scenes/title.tscn")
	await scene_changed
	await frames(20)
	start_frame = Engine.get_physics_frames()
	physics_frame.connect(_sample)
	await click(current_scene.new_game)
	if not await enter_region(0):
		return
	await tap("hunt_switch")
	await frames(5)
	if not verify(hunter.with_bow, "selected hunter bow"):
		return
	for enemy in ruins.enemies.duplicate():
		if enemy.species not in ["spider", "lizard", "treant"]:
			continue
		var species: String = enemy.species
		if not verify(await defeat(enemy), "defeated " + species):
			return
		if species == "lizard":
			if not ruins.collected_souls.has("lizard"):
				await go_to(drop_x("lizard"))
				await frames(20)
			for slot in range(ruins.collected_souls.size()):
				if hunter.equipped_soul == "lizard":
					break
				await tap("hunt_equip")
				await frames(3)
			if not verify(hunter.equipped_soul == "lizard", "collected and equipped wing soul"):
				return
	if not verify(await walk_to(753), "reached east edge of broken bridge"):
		return
	if not verify(await glide_to(183), "glided west across broken bridge"):
		return
	await tap("hunt_interact")
	await frames(12)
	if not verify(ruins.completed, "opened the temple west gate"):
		return
	await press_key(KEY_E)
	if not await enter_region(1):
		return
	var crab = find_enemy("lantern_crab")
	if not verify(await break_guard(crab), "shot down the crab's lantern during its tell"):
		return
	if not verify(await walk_to(drop_x("lantern"), 9), "approached the fallen lantern"):
		return
	await frames(25)
	if not verify(ruins.lantern_found, "collected lantern and opened dark waterway"):
		return
	if not await camp_reload():
		return
	if not verify(ruins.lantern_found and hunter.equipped_soul == "lizard", "Continue restores lantern and wing soul"):
		return
	if not verify(await walk_to(1590, 6), "passed the illuminated physical gate"):
		return
	if not verify(await glide_to(1895), "crossed the first corridor gap"):
		return
	if not verify(await walk_to(1963), "reached the second corridor gap"):
		return
	if not verify(await glide_to(2225), "crossed the second corridor gap"):
		return
	if not verify(await walk_to(3121, 8, true), "reached the corridor drain exit"):
		return
	await tap("hunt_interact")
	if not await enter_region(2):
		return
	if not verify(await walk_to(540, 12), "reached the court approach"):
		return
	if not verify(await glide_to(1080), "glided past the court bowman"):
		return
	for leg in [[1180, 1680], [1825, 2400], [2498, 2670]]:
		if not verify(await walk_to(leg[0], 12, true), "reached takeoff %d" % leg[0]):
			return
		if not verify(await glide_to(leg[1]), "glided to court waypoint %d" % leg[1]):
			return
	if not verify(await glide_to(3070), "glided behind the seal keeper"):
		return
	var keeper = find_enemy("seal_keeper")
	if not verify(await push_keeper_to_seal(keeper), "reached the keeper's shield phase"):
		return
	if not verify(await break_guard(keeper), "broke the keeper's seal with a bow shot"):
		return
	if not verify(await defeat(keeper), "defeated the final seal keeper"):
		return
	if not verify(await walk_to(3130, 8, true), "reached the main altar"):
		return
	await tap("hunt_interact")
	await frames(10)
	if not verify(ruins.completed and ruins.end_screen.visible and Save.read().state.get("keeper_felled", false),
			"ending visible and final victory saved"):
		return
	mark("FINISH deaths=%d" % deaths)
	await frames(120)
	if DisplayServer.get_name() == "headless":
		# A fixed-FPS run finishes before the real-time dummy audio mixer.
		ruins.hit_effects.clear()
		OS.delay_msec(250)
		await process_frame
	quit(0)


func enter_region(region: int) -> bool:
	ruins = null
	hunter = null
	for frame in range(240):
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.has_method("_spawn_enemies") and current_scene.region == region:
			ruins = current_scene
			hunter = ruins.hunter
			latest_region = region
			hunter.defeated.connect(func(): deaths += 1; mark("defeated by damage"))
			await frames(16)
			return verify(true, "entered " + REGION[region])
	return verify(false, "entered " + REGION[region])


func camp_reload() -> bool:
	if not verify(await walk_to(ruins.landscape.shrine.position.x, 28), "returned to the corridor camp with the lantern"):
		return false
	await tap("hunt_interact")
	await frames(10)
	if not verify(ruins.camp_menu.visible, "opened camp menu by pressing E"):
		return false
	var save_button: Button = ruins.camp_rest.get_parent().get_child(-1)
	await click(save_button)
	for frame in range(180):
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/title.tscn":
			await frames(20)
			if not verify(not current_scene.continue_game.disabled, "saved to camp and returned to title"):
				return false
			await click(current_scene.continue_game)
			return await enter_region(1)
		await physics_frame
	return verify(false, "returned to title from camp")


func push_keeper_to_seal(keeper: Node2D) -> bool:
	for shot in range(24):
		if not is_instance_valid(keeper) or ruins.restarting:
			break
		if keeper.second_phase:
			release_inputs()
			return true
		var offset: float = keeper.position.x - hunter.position.x
		if absf(offset) > 350.0:
			await walk_to(keeper.position.x - signf(offset) * 280.0, 12)
		elif absf(offset) < 180.0:
			var retreat := clampf(keeper.position.x - signf(offset) * 224.0, 2470.0, 3255.0)
			if absf(retreat - hunter.position.x) > 12.0:
				await walk_to(retreat, 10)
		await aim_at(keeper.position.x)
		await tap("hunt_attack")
		await frames(24)
	release_inputs()
	return false


func aim_at(x: float) -> void:
	var direction := signf(x - hunter.position.x)
	if hunter.facing != direction:
		move(direction)
		await frames(2)
	move(0)


func break_guard(enemy: Node2D) -> bool:
	var fired := false
	for frame in range(930):
		await physics_frame
		if not is_instance_valid(enemy):
			break
		if not enemy.armed:
			release_inputs()
			return true
		var offset: float = enemy.position.x - hunter.position.x
		var distance := absf(offset)
		var reach: float = enemy.attack.trigger_range
		var direction := signf(offset)
		if enemy.windup > 0.23 and hunter.facing == direction and distance < reach + 16.0:
			move(0)
			if not fired:
				await tap("hunt_attack")
				fired = true
		else:
			fired = false
			move(direction if distance > reach - 5.0 or hunter.facing != direction else 0.0)
	release_inputs()
	return false


func walk_to(x: float, tolerance: float = 12.0, attack := false) -> bool:
	for frame in range(1400):
		await physics_frame
		var remaining: float = x - hunter.position.x
		if absf(remaining) <= tolerance:
			release_inputs()
			await frames(5)
			return true
		move(signf(remaining))
		hold("hunt_attack", attack)
	release_inputs()
	return false


func glide_to(x: float) -> bool:
	var direction := signf(x - hunter.position.x)
	move(direction)
	Input.action_press("hunt_soul")
	await tap("hunt_jump")
	var glided := false
	for frame in range(250):
		await physics_frame
		glided = glided or hunter.gliding
		if direction * (x - hunter.position.x) < 6:
			break
		move(direction)
	move(0)
	Input.action_release("hunt_soul")
	for frame in range(50):
		await physics_frame
		if hunter.is_on_floor():
			break
	return glided and absf(hunter.position.x - x) < 48 and hunter.is_on_floor()


func release_inputs() -> void:
	move(0)
	hold("hunt_attack", false)


func find_enemy(id: String) -> Node2D:
	for enemy in ruins.enemies:
		if enemy.species == id:
			return enemy
	return null


func drop_x(kind: String) -> float:
	for drop in ruins.drops:
		if drop.kind == kind:
			return drop.at.x
	return hunter.position.x


func click(button: Button) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	var up := event.duplicate() as InputEventMouseButton
	up.pressed = false
	root.push_input(up, true)
	await process_frame


func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	var up := event.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up, true)


func verify(condition: bool, description: String) -> bool:
	mark(("%s " % ("PASS" if condition else "FAIL")) + description)
	if not condition:
		quit(1)
	return condition


func mark(event: String) -> void:
	var point: Vector2 = hunter.position if is_instance_valid(hunter) else Vector2.ZERO
	print("%6.2fs x=%6.1f y=%6.1f  %s" % [seconds(), point.x, point.y, event])
	_sample(event)


func _sample(event := "") -> void:
	if route == null or (event.is_empty() and Engine.get_physics_frames() % 15 != 0):
		return
	var valid := is_instance_valid(hunter)
	var point: Vector2 = hunter.position if valid else Vector2.ZERO
	route.store_csv_line(PackedStringArray([str(seconds()), REGION[latest_region] if valid else "title",
		str(point.x) if valid else "", str(point.y) if valid else "", str(hunter.health) if valid else "", event]))
	if not event.is_empty():
		route.flush()


func seconds() -> float:
	return float(maxi(0, Engine.get_physics_frames() - start_frame)) / 60.0
