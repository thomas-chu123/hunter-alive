extends SceneTree

const Ruins := preload("res://scripts/scene/ruins.gd")

var failed := false


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/ruins/ruins.tscn")
	await scene_changed
	var level: Ruins = current_scene
	var hunter := level.hunter
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	level.notice_left = 0.0
	level.camera.zoom = Vector2.ONE * 1.65
	level.camera.position.y = -108
	await frames(24)

	var pickup_x := hunter.position.x + 90.0
	level._drop("soul_currency", pickup_x, 7)
	level._drop("material", pickup_x, 2)
	level._drop("lizard", pickup_x)
	level._drop("scaleveil_hood", pickup_x, 1, 3)
	await frames(20)
	Input.action_press("hunt_right")
	Input.action_press("hunt_walk")
	for frame in range(65):
		if level.drops.is_empty():
			break
		await physics_frame
	check(level.drops.is_empty() and level.soul_balance == 7 and level.materials == 2,
		"walking over the drops collects the loot")
	var labels := PackedStringArray()
	for popup in level.pickup_feedback:
		labels.append(popup.text)
	check(labels == PackedStringArray(["+3 鱗紗兜帽", "蜥翼之魂", "素材 +2", "魂 +7"]),
		"simultaneous gear, spirit, material and soul pickups have individual labels")
	mark("four pickup labels follow the moving hunter")
	await frames(24)
	Input.action_release("hunt_right")
	Input.action_release("hunt_walk")
	await frames(62)
	check(level.pickup_feedback.is_empty(), "pickup labels expire")

	level._grant_equipment("copper_helm")
	level._grant_equipment("ember_staff")
	await tap_gear()
	await frames(8)
	var panel := level.gear_menu.get_child(0) as Control
	var details := level.gear_detail_scroll.get_parent() as Control
	var panel_rect := panel.get_global_rect()
	var detail_rect := details.get_global_rect()
	mark("two-row weapon details")
	await frames(25)
	await select_gear(level, "scaleveil_hood")
	check(level.gear_values.visible and level.gear_armor.visible, "hood shows a third detail row")
	check(panel.get_global_rect() == panel_rect and details.get_global_rect() == detail_rect,
		"three-row hood details leave both panel rectangles fixed")
	mark("three-row hood details")
	await frames(25)
	await select_gear(level, "copper_helm")
	check(not level.gear_values.visible and level.gear_armor.visible, "helm shows two detail rows")
	check(panel.get_global_rect() == panel_rect and details.get_global_rect() == detail_rect,
		"switching back to two rows leaves both panel rectangles fixed")
	mark("two-row helm details")
	await frames(25)
	await tap_gear()

	hunter.select_weapon("ember_staff")
	hunter.position = Vector2(1260, 539)
	hunter.velocity = Vector2.ZERO
	level.camera.zoom = Vector2.ONE * 2.85
	level.camera.position.y = -75
	level.camera.reset_smoothing()
	await frames(22)
	var start_x := hunter.position.x
	Input.action_press("hunt_walk")
	Input.action_press("hunt_right")
	await frames(20)
	check(hunter.walking and is_equal_approx(hunter.velocity.x, hunter.WALK_SPEED) and hunter.position.x > start_x,
		"holding walk with the ember staff moves at walk speed")
	mark("ember staff walk right")
	await frames(28)
	Input.action_release("hunt_walk")
	await frames(18)
	check(not hunter.walking and is_equal_approx(hunter.velocity.x, hunter.RUN_SPEED),
		"releasing walk with the ember staff moves at run speed")
	mark("ember staff run right")
	await frames(22)
	Input.action_release("hunt_right")
	Input.action_press("hunt_left")
	await frames(30)
	check(hunter.facing == -1.0 and is_equal_approx(hunter.velocity.x, -hunter.RUN_SPEED),
		"ember staff run also moves and faces left")
	mark("ember staff run left")
	await frames(25)
	Input.action_release("hunt_left")
	await frames(18)
	quit(1 if failed else 0)


func select_gear(level: Ruins, id: String) -> void:
	var list := level.gear_list
	var index := level.gear_ids.find(id)
	if DisplayServer.get_name() == "headless":
		list.select(index)
		list.item_selected.emit(index)
	else:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = list.get_global_transform_with_canvas() * list.get_item_rect(index, false).get_center()
		click.pressed = true
		root.push_input(click, true)
		click = click.duplicate()
		click.pressed = false
		root.push_input(click, true)
	check(list.is_selected(index), "selected " + id)
	await frames(4)


func tap_gear() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_I
	key.physical_keycode = KEY_I
	key.pressed = true
	root.push_input(key)
	await process_frame
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)


func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


func mark(message: String) -> void:
	print("FRAME %d %s" % [Engine.get_process_frames(), message])


func check(condition: bool, message: String) -> void:
	failed = failed or not condition
	print("%s %s" % ["PASS" if condition else "FAIL", message])
