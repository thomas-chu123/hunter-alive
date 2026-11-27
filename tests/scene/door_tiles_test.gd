extends SceneTree

const Level := preload("res://scripts/scene/ruins.gd")
const Door := Level.Door
const Campaign := preload("res://scripts/game/campaign.gd")
const Props := preload("res://assets/environment/common/props/props_tileset.tres")
const Save := preload("res://scripts/game/camp_save.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check_tile_directions()
	change_scene_to_file(Campaign.scene_path({}))
	await scene_changed
	var level := current_scene as Level
	level.hunter.set_physics_process(false)
	for monster in level.enemies:
		monster.set_physics_process(false)
		monster.global_position = Vector2(-1000, -1000)
	var stops := get_nodes_in_group("door_stop_sight")
	check(not stops.is_empty(), "Ruins 1 paints door stops from Props")
	if not stops.is_empty():
		var stop := stops[0] as Door.DoorSight
		level.hunter.global_position = stop.global_position + Vector2(-34, 40)
		level._update_door_sight()
		check(stop.visible and Geometry2D.is_point_in_polygon(Vector2(4, 4), stop.polygon),
			"the level updates the placed door stop's rear sight mask")
	var observer := level.enemies[0]
	var doors: Array[Door] = []
	for door: Door in get_nodes_in_group("interactive_door"):
		doors.append(door)
	check(doors.size() == 4 and doors.map(func(door: Door) -> String: return door.door_name).has("場景變更門"),
		"Ruins 1 paints four interactive door scenes from Props")
	for door in doors:
		if not door.scene_exit:
			await check_door(level, door, observer)

	var exit := level.landscape.portals[0] as Door
	if exit == null:
		check(false, "the authored exit is an interactive door")
		quit(1)
		return
	var hunter := level.hunter
	hunter.global_position = exit.global_position + Vector2(-Door.REACH - 1, 0)
	await press_e()
	check(exit.motion == null and not level.transitioning, "E beyond reach does not bypass the exit animation")
	hunter.global_position = exit.global_position + Vector2(-34, 0)
	level.landscape.portal_open = false
	await press_e()
	check(exit.motion == null and not level.transitioning, "a locked exit stays closed")
	level.landscape.portal_open = true
	await press_e()
	check(exit.motion != null and hunter.door_action and exit.opening_side == -1 and current_scene == level,
		"E starts the hunter and exit animations before changing scenes")
	for frame in range(100):
		await physics_frame
		if current_scene is Level and current_scene != level:
			break
	check(current_scene != null and current_scene.scene_file_path == Campaign.scene_path({"stage": 2}),
		"exit animation advances to Ruins 2")
	check(Save.read().get("state", {}).get("stage") == 2, "exit saves the next stage checkpoint")
	print("Door tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func check_tile_directions() -> void:
	var source := Props.get_source(6) as TileSetScenesCollectionSource
	check(source.get_scene_tiles_count() == 8, "Props has eight directional door tiles")
	for tile_id in range(1, 9):
		var door := source.get_scene_tile_scene(tile_id).instantiate() as Door
		var leaf := door.get_node("Leaf") as Sprite2D
		var frame := door.get_node("Frame") as Sprite2D
		var side := 1 if tile_id <= 4 else -1
		var post := frame.transform * frame.get_rect()
		var closed_leaf := leaf.transform * leaf.get_rect()
		check(door.opening_side == side and frame.flip_h == (side < 0) and leaf.flip_h == frame.flip_h
			and post.size.x == 16.0 and post.encloses(closed_leaf),
			"%s uses one side post that covers the closed leaf" % door.name)
		door.free()


func check_door(level: Level, door: Door, observer: Level.Monster) -> void:
	var hunter := level.hunter
	var at := door.global_position
	observer.global_position = at + Vector2(47, 0)
	hunter.global_position = at + Vector2(-34, 0)
	await process_frame
	await physics_frame
	var probe := Vector2(50, -32)
	var crossing := Vector2(68, 0)
	check(not door.opened and door.occluder.visible and not door.collision.disabled
		and door.sight.visible and Geometry2D.is_point_in_polygon(probe, door.sight.polygon)
		and not observer._clear_to_target() and hunter.test_move(hunter.global_transform, crossing),
		"%s closed blocks passage, light, the hunter's view and enemy sight" % door.door_name)
	await press_e()
	if door.motion == null:
		check(false, "%s E starts the opening tween" % door.door_name)
		return
	for frame in range(12):
		await physics_frame
	var amount := door.leaf.scale.x
	check(hunter.door_action and hunter.door_action_opening and hunter.facing == 1.0
		and hunter.door_action_progress > 0.0 and amount > Door.CLOSED_LEAF_SCALE and amount < 0.88
		and signf(door.leaf.position.x) == door.opening_side,
		"%s opening moves both the hunter pose and the door leaf" % door.door_name)
	await door.motion.finished
	await physics_frame
	check(door.opened and not door.occluder.visible and door.collision.disabled and not door.sight.visible
		and observer._clear_to_target() and not hunter.test_move(hunter.global_transform, crossing)
		and signf(door.leaf.position.x) == door.opening_side,
		"%s open passes light, vision and the hunter" % door.door_name)

	hunter.global_position = at
	await press_e()
	check(door.opened and door.motion == null, "%s refuses to close on the hunter" % door.door_name)
	observer.global_position = at + Vector2(-90, 0)
	hunter.global_position = at + Vector2(34, 0)
	await press_e()
	if door.motion == null:
		check(false, "%s E starts the closing tween from the other side" % door.door_name)
		return
	for frame in range(12):
		await physics_frame
	check(hunter.door_action and not hunter.door_action_opening and hunter.facing == -1.0
		and door.leaf.scale.x > Door.CLOSED_LEAF_SCALE and door.leaf.scale.x < 0.88
		and signf(door.leaf.position.x) == door.opening_side,
		"%s closing moves the hunter and leaf from the opposite side" % door.door_name)
	await door.motion.finished
	await physics_frame
	await process_frame
	check(not door.opened and not hunter.door_action and not door.collision.disabled and door.occluder.visible
		and door.sight.visible and Geometry2D.is_point_in_polygon(Vector2(-50, -32), door.sight.polygon)
		and not observer._clear_to_target() and is_zero_approx(door.leaf.position.x), "%s closing restores collision, shadow and sight blocking" % door.door_name)


func press_e() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.device = 16
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await physics_frame
	await physics_frame
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await physics_frame


func check(condition: bool, message: String) -> void:
	print("%s %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1
