extends SceneTree

const Ruins := preload("res://scripts/ruins.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/ruins/ruins.tscn")
	await scene_changed
	var level: Ruins = current_scene
	await frames(24)
	Input.action_press("hunt_interact")
	await frames(2)
	Input.action_release("hunt_interact")
	check(level.camp_menu.visible and level.camp_rest.icon != null and level.camp_level_up.icon != null,
		"camp interaction opens the service cards")
	level._grant_equipment("ember_staff")
	level.soul_balance = 26
	level.materials = 4
	level._update_camp_menu()
	await frames(36)

	var inventory := level.camp_rank_items
	var item_index := inventory.item_count - 1
	check(inventory.get_item_icon(item_index) != null, "workshop displays ranked equipment artwork")
	if DisplayServer.get_name() == "headless":
		inventory.select(item_index)
		inventory.item_selected.emit(item_index)
	else:
		var pointer := InputEventMouseButton.new()
		pointer.position = inventory.get_global_transform_with_canvas() * inventory.get_item_rect(item_index, false).get_center()
		pointer.button_index = MOUSE_BUTTON_LEFT
		pointer.pressed = true
		root.push_input(pointer, true)
		pointer = pointer.duplicate()
		pointer.pressed = false
		root.push_input(pointer, true)
	check(level.camp_selected_item.text == "+1 餘火魔法杖"
		and inventory.get_item_text(item_index) == "+1 餘火魔法杖"
		and inventory.get_item_tooltip(item_index) == "+1 餘火魔法杖"
		and level.camp_rank_up.text == "+1 → +2　花費 10 魂", "workshop uses numeric ranks for the tile, tooltip and upgrade action")
	await frames(44)
	level.camp_rank_up.grab_focus()
	await enter()
	check(level.camp_selected_item.text == "+2 餘火魔法杖" and level.soul_balance == 16,
		"upgrading the selected tile refreshes its rank and soul cost")
	await frames(45)
	for rank in range(3, 6):
		level._grant_equipment("ember_staff", rank, true)
	level._update_camp_menu()
	for rank in range(3, 6):
		check(inventory.get_item_text(item_index + rank - 2) == "+%d 餘火魔法杖" % rank,
			"workshop shows the numeric name for rank %d" % rank)
	inventory.select(inventory.item_count - 1)
	inventory.item_selected.emit(inventory.item_count - 1)
	check(level.camp_rank_up.disabled and level.camp_rank_up.text == "已達 +5", "max rank uses numeric text")
	await frames(40)
	level.camp_rest.grab_focus()
	await enter()
	check(level.camp_rest.has_focus() and level.hunter.health == level.hunter.max_health(), "rest card restores health")
	await frames(30)
	level.camp_leave.grab_focus()
	await enter()
	check(not level.camp_menu.visible and level.hunter.is_physics_processing(), "return button resumes exploration")

	level.hunter.select_weapon("ember_staff")
	level.camera.zoom = Vector2.ONE * 2.45
	level.camera.position.y = -89
	level.camera.position_smoothing_enabled = false
	await frames(65)
	Input.action_press("hunt_attack")
	await frames(17)
	Input.action_release("hunt_attack")
	check(not level.arrows.is_empty(), "redrawn staff still releases a projectile")
	await frames(43)
	level.hit_effects.clear()
	if DisplayServer.get_name() != "headless":
		for enemy in level.enemies:
			enemy.queue_free()
		root.get_node("GameMusic").play_region(-1)
		await frames(76)
	quit(1 if failures else 0)


func enter() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	await process_frame
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)


func frames(count: int) -> void:
	for index in range(count):
		await process_frame


func check(condition: bool, message: String) -> void:
	print("%.2fs %s %s" % [Engine.get_process_frames() / 60.0, "PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1
