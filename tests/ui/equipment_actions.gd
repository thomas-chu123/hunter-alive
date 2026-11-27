extends SceneTree

const Ruins := preload("res://scripts/scene/ruins.gd")

var failed := false


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/ruins/ruins.tscn")
	await scene_changed
	var ruins := current_scene as Ruins
	ruins._grant_equipment("linen_hood")
	for index in range(3):
		ruins._grant_equipment("hunter_knife", 1, true)
	await key(KEY_I)
	await process_frame
	var first := ruins.gear_list.get_item_rect(0)
	var fourth := ruins.gear_list.get_item_rect(3)
	var fifth := ruins.gear_list.get_item_rect(4)
	check(first.has_area() and fourth.position.y == first.position.y and fourth.position.x > first.position.x
		and fifth.position.y > first.position.y and fifth.position.x == first.position.x,
		"four compact backpack tiles per row: %s, %s, %s" % [first, fourth, fifth])
	var activations: Array[bool] = []
	ruins.gear_apply.pressed.connect(func(): activations.append(true))
	await click(ruins.gear_apply)
	await key(KEY_E)
	check(ruins.gear_apply.disabled and activations.is_empty() and ruins.hunter.selected_weapon() == "hunter_knife",
		"equipped weapon stays disabled for mouse and E")
	var hood := ruins.gear_ids.find("linen_hood")
	ruins.gear_list.select(hood)
	ruins.gear_list.item_selected.emit(hood)
	var actions := ruins.gear_apply.get_parent() as HBoxContainer
	var close := actions.get_node("ReturnToExploration") as Button
	var equip_rect := ruins.gear_apply.get_rect()
	var destroy_rect := ruins.destroy_item.get_rect()
	var group_gap := destroy_rect.position.x - equip_rect.end.x
	var return_gap := close.position.x - destroy_rect.end.x
	check(equip_rect.size == destroy_rect.size, "equip and destroy sizes match: %s, %s" % [equip_rect.size, destroy_rect.size])
	check(return_gap > group_gap and is_equal_approx(close.get_rect().end.x, actions.size.x),
		"return is right-aligned: action gap %.0f, return gap %.0f" % [group_gap, return_gap])
	for button: Button in [ruins.gear_apply, ruins.destroy_item, close]:
		var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
		var pressed := button.get_theme_stylebox("pressed") as StyleBoxTexture
		check(normal != null and pressed != null and normal.region_rect != pressed.region_rect, "raised and pressed faces for " + button.text)
	check(ruins.gear_list.get_theme_stylebox("panel") is StyleBoxTexture, "inventory uses the ornamental frame")
	await click(ruins.gear_apply)
	check(ruins.hunter.gear.get("頭部") == "linen_hood", "mouse equips selected hood")
	check(ruins.gear_apply.size == ruins.destroy_item.size, "unequip and destroy sizes still match")
	await key(KEY_E)
	check(not ruins.hunter.gear.has("頭部"), "E removes the same hood")
	await click(ruins.destroy_item)
	check(ruins.destroy_dialog.visible, "mouse opens destroy confirmation")
	ruins.destroy_dialog.hide()
	await key(KEY_D)
	check(ruins.destroy_dialog.visible and ruins.gear_ids.has("linen_hood"), "D opens confirmation without removing the item")
	ruins.destroy_dialog.hide()
	await click(close)
	check(not ruins.gear_menu.visible, "mouse returns to exploration")
	await key(KEY_I)
	await key(KEY_ESCAPE)
	check(not ruins.gear_menu.visible and not ruins.pause_menu.visible, "Esc returns to exploration")
	await key(KEY_I)
	await key(KEY_I)
	check(not ruins.gear_menu.visible, "I returns to exploration")
	quit(int(failed))


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame


func click(button: Button) -> void:
	await process_frame
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame


func check(condition: bool, message: String) -> void:
	failed = failed or not condition
	print("%s %s" % ["PASS" if condition else "FAIL", message])
