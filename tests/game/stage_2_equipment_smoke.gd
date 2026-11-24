extends SceneTree

const SAVE := preload("res://scripts/game/camp_save.gd")
const MONSTER := preload("res://scripts/character/ruin_monster.gd")
const RUINS := "res://scenes/ruins/ruins.tscn"

var failed := false


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file(RUINS)
	await scene_changed
	var ruins = current_scene
	var hunter = ruins.hunter
	await wait_frames(9)
	await key(KEY_ESCAPE)
	check(ruins.pause_menu.visible and not hunter.is_physics_processing(), "Escape opens pause settings")
	ruins.pause_volume.value = 65
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.65)), "pause volume updates the Master bus")
	await show_view()
	await key(KEY_ESCAPE)
	await action("hunt_interact")
	check(ruins.camp_menu.visible and ruins.owned_equipment.has("linen_hood") and ruins.owned_equipment.has("hunter_wraps"), "camp grants hood and handwraps")
	await key(KEY_ESCAPE)
	await wait_frames(4)
	await key(KEY_I)
	check(ruins.gear_menu.visible and not hunter.is_physics_processing(), "I opens gear and pauses combat")
	var portrait = ruins.gear_menu.find_child("HunterPortrait", true, false)
	check(portrait is TextureRect and portrait.texture != null, "left panel displays the hunter")
	var stats := ruins.gear_menu.find_child("HunterStats", true, false) as GridContainer
	var status_panel := stats.get_parent().get_parent() as VBoxContainer
	check(status_panel.get_child(0).text == "目前狀態" and stats.get_global_rect().position.x > portrait.get_global_rect().end.x,
		"current status heading and stats appear to the right of the portrait")
	check_stat(ruins, "Level", "0")
	check_stat(ruins, "HP", "6 / 6")
	check_stat(ruins, "MP", "4 / 4")
	check_stat(ruins, "攻擊力", "2")
	check_stat(ruins, "攻擊頻率", "3.45 次/秒")
	check_stat(ruins, "護甲", "0")
	check_stat(ruins, "防禦力", "0%")
	check_stat(ruins, "魂", "0")
	await equip(ruins, "linen_hood")
	check(hunter.max_health() == 7, "hood raises maximum HP")
	check_stat(ruins, "HP", "6 / 7")
	check_stat(ruins, "護甲", "1")
	check_stat(ruins, "防禦力", "3%")
	check(ruins.gear_name.text == "+1 營火布兜" and ruins.gear_slot.text == "頭部  ·  已裝備"
		and ruins.gear_apply.text == "卸下　E" and ruins.destroy_item.text == "銷毀　D",
		"hood details show the ranked name, slot, status and shortcuts")
	var linen_index: int = ruins.gear_ids.find("linen_hood")
	check(ruins.gear_list.get_item_text(linen_index) == "E +1 營火布兜"
		and ruins.gear_list.get_item_tooltip(linen_index) == "+1 營火布兜"
		and ruins.gear_slot_images["頭部"].tooltip_text == "頭部　+1 營火布兜",
		"inventory, item tooltip and equipped slot use the same ranked name")
	check(ruins.gear_slot_images["頭部"].texture == ruins.gear_list.get_item_icon(linen_index)
		and ruins.gear_values.text.begins_with("最大體力　6 → 7"), "hood image and numerical values match the equipped slot")
	await show_view()
	await equip(ruins, "linen_hood")
	check(hunter.max_health() == 6, "removing hood restores base maximum HP")
	check_stat(ruins, "HP", "6 / 6")
	check_stat(ruins, "防禦力", "0%")
	check(ruins.gear_slot_images["頭部"].texture == null, "removing hood clears the slot image")
	await equip(ruins, "hunter_wraps")
	check_stat(ruins, "攻擊頻率", "4.35 次/秒")
	await show_view()
	await key(KEY_I)
	Input.action_press("hunt_attack")
	await wait_frames(5)
	Input.action_release("hunt_attack")
	check(is_equal_approx(hunter.attack_duration, 0.23), "handwraps shorten the real knife attack")

	# Start below the terrace and jump up each ledge using game inputs.
	hunter.position = Vector2(1665, 539)
	hunter.velocity = Vector2.ZERO
	var moth
	for enemy in ruins.enemies.duplicate():
		if enemy.species == "bell_moth":
			moth = enemy
		else:
			ruins.enemies.erase(enemy)
			enemy.queue_free()
	check(moth._attack_pose() == MONSTER.AttackPose.IDLE, "bell moth uses its hover sprite before engaging")
	await wait_frames(15)
	await hop(hunter, 1795, 473)
	await hop(hunter, 1930, 412)
	await hop(hunter, 2050, 348)
	Input.action_press("hunt_right")
	for frame in range(120):
		if hunter.position.x > 2245:
			break
		await physics_frame
	Input.action_release("hunt_right")
	await action("hunt_interact")
	check(ruins.owned_equipment.has("ember_staff") and ruins.owned_equipment.has("moss_vest"), "stone cache grants staff and vest")
	check(ruins.notice_label.text == "取得+1 苔織獵衣、+1 餘火魔法杖和 3 份素材。按 I 看裝備。", "cache notice uses ranked item names")
	if OS.has_feature("movie"):
		await show_view()
	await key(KEY_I)
	await equip(ruins, "moss_vest")
	await equip(ruins, "ember_staff")
	check(hunter.with_staff and ruins.gear_list.item_count == 6, "loadout contains three weapons and supports staff selection")
	check_stat(ruins, "攻擊力", "3")
	check_stat(ruins, "攻擊頻率", "1.85 次/秒")
	check_stat(ruins, "護甲", "2")
	check_stat(ruins, "防禦力", "6%")
	check(ruins.gear_slot_images["武器"].texture == ruins.gear_list.get_item_icon(ruins.gear_ids.find("ember_staff"))
		and ruins.gear_values.text.contains("傷害 3") and ruins.gear_values.text.contains("法力 1"),
		"staff image and damage and mana values match selection")
	await show_view()
	await key(KEY_I)

	hunter.position = Vector2(2320, 539)
	hunter.velocity = Vector2.ZERO
	for frame in range(130):
		if hunter.pollen_left > 0:
			break
		await physics_frame
	check(hunter.pollen_left > 2.0, "standing underneath released pollen slows the hunter")
	check(moth._attack_pose() == MONSTER.AttackPose.RELEASE, "bell moth switches to its pollen sprite")
	await show_view()
	hunter.position = Vector2(2210, 539)
	hunter.velocity = Vector2.ZERO
	await wait_frames(12)
	for frame in range(160):
		if moth.windup > 0.6:
			break
		await physics_frame
	check(moth.windup > 0.6, "moth signals its pollen attack")
	check(moth._attack_pose() == MONSTER.AttackPose.ANTICIPATION, "bell moth switches to its glowing windup sprite")
	var mana: int = hunter.mana
	Input.action_press("hunt_attack")
	await wait_frames(5)
	Input.action_press("hunt_jump")
	await wait_frames(1)
	Input.action_release("hunt_jump")
	await wait_frames(16)
	Input.action_release("hunt_attack")
	check(hunter.mana == mana - 1 and moth.health == 3 and moth.windup == 0.0, "jump-height horizontal fireball uses mana, hits airborne moth and interrupts pollen")
	check(moth._attack_pose() == MONSTER.AttackPose.RECOVERY, "interrupted bell moth switches to its recoil sprite")
	if OS.has_feature("movie"):
		print("TIMING first staff hit checked at %.2fs" % (Engine.get_process_frames() / 60.0))
	await wait_frames(21)
	ruins.loot_rng.seed = 2 # Keep the guaranteed hood pickup separate from random gear.
	Input.action_press("hunt_attack")
	await wait_frames(5)
	Input.action_press("hunt_jump")
	await wait_frames(1)
	Input.action_release("hunt_jump")
	await wait_frames(13)
	Input.action_release("hunt_attack")
	check(not is_instance_valid(moth) and ruins._has_drop("scaleveil_hood"), "defeating moth drops its hood")
	for drop in ruins.drops:
		if drop.kind == "scaleveil_hood":
			hunter.position = Vector2(drop.at.x, 539)
			break
	await wait_frames(19)
	check(ruins.owned_equipment.has("scaleveil_hood"), "moth hood is collected from the ground")
	check(ruins.notice_label.text == "取得+1 鱗紗兜帽。按 I 看裝備。", "drop pickup notice uses the ranked item name")
	if OS.has_feature("movie"):
		await show_view()
	await key(KEY_I)
	await equip(ruins, "scaleveil_hood")
	await show_view()
	await key(KEY_I)
	hunter.apply_pollen()
	check(is_equal_approx(hunter.pollen_left, 1.2), "wearing moth hood halves slowdown duration")

	hunter.position = Vector2(950, 539)
	hunter.velocity = Vector2.ZERO
	await wait_frames(8)
	await action("hunt_interact")
	await press(ruins.camp_rest)
	var current_health: int = hunter.health
	hunter.hurt(hunter.position.x + 50)
	check(hunter.health == current_health and not hunter.vest_ready and hunter.mana == hunter.MAX_MANA, "camp replenishes mana and vest blocks its first hit")
	await press(ruins.camp_save_exit)
	await scene_changed
	var title = current_scene
	check(title.volume.value == 65, "title and pause share saved settings")
	await press(title.continue_game)
	await scene_changed
	ruins = current_scene
	check(ruins.owned_equipment.has("ember_staff") and ruins.hunter.selected_weapon() == "ember_staff", "Continue restores the selected staff")
	check(ruins.hunter.gear.get("頭部") == "scaleveil_hood" and ruins.hunter.gear.get("手部") == "hunter_wraps" and ruins.hunter.gear.get("身體") == "moss_vest", "Continue restores all equipped slots")
	await key(KEY_I)
	for index in range(ruins.gear_list.item_count):
		check(ruins.gear_list.get_item_icon(index) != null, "inventory icon loads for " + ruins.gear_ids[index])
	await show_view()
	var hood_index: int = ruins.gear_ids.find("linen_hood")
	ruins.gear_list.select(hood_index)
	ruins.gear_list.item_selected.emit(hood_index)
	var count: int = ruins.inventory.size()
	await key(KEY_D)
	check(ruins.destroy_dialog.visible and ruins.inventory.size() == count, "D opens confirmation before destroying")
	await show_view()
	await key(KEY_ESCAPE)
	check(not ruins.destroy_dialog.visible and ruins.inventory.size() == count, "cancel keeps the selected item")
	await key(KEY_D)
	await press(ruins.destroy_dialog.get_ok_button())
	check(ruins.inventory.size() == count - 1 and not ruins.gear_ids.has("linen_hood"), "confirm destroys only the selected item")
	await show_view()
	quit(1 if failed else 0)


func check_stat(ruins: Node, title: String, expected: String) -> void:
	var actual: String = ruins.gear_stat_values[title].text
	check(actual == expected, "current status %s = %s (expected %s)" % [title, actual, expected])


func equip(ruins: Node, id: String) -> void:
	var index: int = ruins.gear_ids.find(id)
	if not check(index >= 0, "gear list contains " + id):
		return
	if DisplayServer.get_name() == "headless":
		ruins.gear_list.select(index)
		ruins.gear_list.item_selected.emit(index)
	else:
		await process_frame
		var list: ItemList = ruins.gear_list
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = list.get_global_transform_with_canvas() * list.get_item_rect(index, false).get_center()
		click.pressed = true
		root.push_input(click, true)
		var release := click.duplicate() as InputEventMouseButton
		release.pressed = false
		root.push_input(release, true)
		check(list.get_selected_items() == PackedInt32Array([index]), "click selects item icon for " + id)
	await key(KEY_E)


func press(button: Button) -> void:
	button.grab_focus()
	await key(KEY_ENTER)


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	root.push_input(event)


func action(id: StringName) -> void:
	Input.action_press(id)
	await wait_frames(3)
	Input.action_release(id)


func wait_frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


func show_view() -> void:
	await create_timer(0.65).timeout


func check(condition: bool, message: String) -> bool:
	failed = failed or not condition
	print("%s %s" % ["PASS" if condition else "FAIL", message])
	return condition


func hop(hunter: Node, x: float, y: float) -> void:
	Input.action_press("hunt_right")
	await action("hunt_jump")
	for frame in range(65):
		if hunter.position.x >= x:
			Input.action_release("hunt_right")
		if frame > 8 and hunter.is_on_floor() and absf(hunter.position.y - y) < 3:
			break
		await physics_frame
	Input.action_release("hunt_right")
	check(hunter.is_on_floor() and absf(hunter.position.y - y) < 3, "jump reached ledge at y=%d" % int(y))
	await wait_frames(8)
