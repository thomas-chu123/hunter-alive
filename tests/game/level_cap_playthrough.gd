extends "res://tests/game/campaign_playthrough.gd"

const Progression := preload("res://scripts/game/ruin_progression.gd")
const Equipment := preload("res://scripts/game/ruin_equipment.gd")

var farming := false
var trips := 0
var income_combat := 0
var income_salvage := 0
var spent_levels := 0
var spent_gear := 0
var full_bag_samples := 0
var kills: Dictionary = {}
var stats: FileAccess
var capture_dir := ""
var capture_until := -1
var capture_index := 0
var capture_pending := false
var watch_started := false


func run() -> void:
	var path := OS.get_environment("ULTIMA_LEVEL_TRACE")
	if not path.is_empty():
		stats = FileAccess.open(path, FileAccess.WRITE)
		if stats == null:
			push_error("Could not open progression trace.")
			quit(1)
			return
		stats.store_csv_line(PackedStringArray(["seconds", "region", "x", "y", "hp", "level", "souls",
			"items", "capacity", "trips", "combat_souls", "salvage_souls", "level_spend", "gear_spend", "event"]))
	capture_dir = OS.get_environment("ULTIMA_LEVEL_CAPTURE_DIR")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		process_frame.connect(_schedule_capture)
	await super.run()


func enter_region(region: int) -> bool:
	if not await super.enter_region(region):
		return false
	if not watch_started:
		physics_frame.connect(_watch_drops)
		watch_started = true
	for entity in ruins.enemies:
		entity.felled.connect(_count_defeat)
	if region == 2 and not farming:
		farming = true
		return await reach_cap()
	return true


func reach_cap() -> bool:
	mark("GRIND_START")
	capture_until = Engine.get_physics_frames() + 100
	for trip in range(155):
		if not await purchase_at_camp():
			return false
		if hunter.level == Progression.MAX_LEVEL:
			mark("GRIND_END trips=%d combat=%d salvage=%d level_spend=%d gear_spend=%d deaths=%d full_bag_samples=%d kills=%s" % [
				trips, income_combat, income_salvage, spent_levels, spent_gear, deaths, full_bag_samples, JSON.stringify(kills)])
			capture_until = Engine.get_physics_frames() + 120
			if not verify(hunter.max_health() >= 16 and Save.read().get("state", {}).get("player_level", -1) == 10,
					"reached level 10 and saved at the court camp before the final boss"):
				return false
			await frames(88)
			return await leave_court_camp()
		var archer := find_enemy("thorn_archer")
		if not is_instance_valid(archer):
			if not await reload_court():
				return false
			archer = find_enemy("thorn_archer")
		if not await leave_court_camp():
			return false
		if not verify(hunter.with_bow and is_instance_valid(archer), "began archer hunt with a real bow"):
			return false
		var initial_souls: int = ruins.soul_balance
		if not await hunt_archer(archer):
			return verify(false, "defeated and collected the court archer")
		var collected: int = ruins.soul_balance - initial_souls
		income_combat += collected
		trips += 1
		mark("TRIP %d gain=%d remaining=%d" % [trips, collected, ruins.soul_balance])
		if trips <= 2:
			capture_until = Engine.get_physics_frames() + 110
		if trips == 4 and OS.has_environment("ULTIMA_LEVEL_PREFLIGHT"):
			mark("PREFLIGHT ended after four hunting laps")
			quit(0)
			return false
	return verify(false, "the court hunt reached level 10 within 155 trips")


func leave_court_camp() -> bool:
	if ruins.camp_menu.visible:
		await click(ruins.camp_leave)
	await frames(8)
	return verify(not ruins.camp_menu.visible, "left court camp through its return button")


func purchase_at_camp() -> bool:
	var shrine: float = ruins.landscape.shrine.position.x
	if not ruins.camp_menu.visible:
		if not await walk_to(shrine + 8, 22):
			return verify(false, "walked back to the court camp")
		await tap("hunt_interact")
		await frames(5)
	if not verify(ruins.camp_menu.visible, "opened court camp with E"):
		return false
	await click(ruins.camp_rest)
	if ruins.materials >= 2 + hunter.bow_level and hunter.bow_level < 2:
		await click(ruins.camp_bow)
		mark("BOW_MATERIAL_UPGRADE damage=%d" % hunter.weapon_damage("hunter_bow"))
	if not await select_camp_item("hunter_bow", false):
		return verify(false, "selected the original bow at camp")
	if spent_gear == 0 and ruins.soul_balance >= 10 and hunter.item_rank("hunter_bow") == 1:
		var before: int = ruins.soul_balance
		await click(ruins.camp_rank_up)
		spent_gear += before - ruins.soul_balance
		mark("BOW_QUALITY_UPGRADE damage=%d spent=%d" % [hunter.weapon_damage("hunter_bow"), before - ruins.soul_balance])
	# Sell loot as individual items. Keep the starting weapons and access to combat.
	for _index in range(22):
		if not await select_camp_item("", true):
			break
		var entry: Dictionary = ruins._inventory_item(ruins._selected_camp_item())
		var before: int = ruins.soul_balance
		await click(ruins.camp_salvage)
		if ruins.soul_balance <= before:
			return verify(false, "camp sale credited currency")
		income_salvage += ruins.soul_balance - before
		mark("SALVAGE %s +%d gain=%d" % [entry.item, entry.rank, ruins.soul_balance - before])
	while not ruins.camp_level_up.disabled:
		var before: int = ruins.soul_balance
		var old_level: int = hunter.level
		await click(ruins.camp_level_up)
		if hunter.level != old_level + 1:
			return verify(false, "camp level-up spends souls and advances one level")
		spent_levels += before - ruins.soul_balance
		mark("LEVEL %d cost=%d HP=%d capacity=%d" % [
			hunter.level, before - ruins.soul_balance, hunter.max_health(), Progression.bag_capacity(hunter.level)])
		if hunter.level in [1, 5, 10]:
			capture_until = Engine.get_physics_frames() + 95
			if not capture_dir.is_empty():
				await frames(62)
	return true


func select_camp_item(id: String, sell_extra: bool) -> bool:
	var list: ItemList = ruins.camp_rank_items
	var wanted := -1
	for index in range(list.item_count):
		var entry: Dictionary = ruins._inventory_item(int(list.get_item_metadata(index)))
		if sell_extra:
			if entry.item not in ["hunter_knife", "hunter_bow"] or int(entry.uid) != ruins._first_item(entry.item):
				wanted = index
		elif entry.item == id and int(entry.uid) == ruins._first_item(id):
			wanted = index
			break
	if wanted < 0:
		return false
	if not list.is_selected(wanted):
		# Select only the visible control's entry; the salvage/upgrade button still
		# drives the transaction through the game's input and camp handlers.
		list.select(wanted)
		list.item_selected.emit(wanted)
		await process_frame
	return list.is_selected(wanted)


func reload_court() -> bool:
	await click(ruins.camp_save_exit)
	for _frame in range(150):
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/title/title.tscn":
			await frames(8)
			await click(current_scene.continue_game)
			mark("CONTINUE respawned ordinary enemies")
			return await enter_region(2)
		await physics_frame
	return false


func hunt_archer(archer: Node2D) -> bool:
	# The archer is the closest repeatable high-yield enemy to the court camp.
	if not await walk_to(532, 9):
		return false
	var last_x: float = archer.position.x if is_instance_valid(archer) else hunter.position.x
	for shot in range(19):
		if not is_instance_valid(archer):
			break
		last_x = archer.position.x
		var gap: float = last_x - hunter.position.x
		if absf(gap) > 330:
			await walk_to(last_x - signf(gap) * 228, 11)
		await aim_at(last_x)
		await tap("hunt_attack")
		await frames(25)
	if is_instance_valid(archer):
		return false
	var soul_x := drop_x("soul_currency")
	var stop := maxf(soul_x, last_x)
	if not await walk_to(stop, 10):
		return false
	await frames(12)
	# Ranked drops are offset to the east of the soul, still nearby on this lane.
	var east_pickup := stop + 22.0
	if not await walk_to(east_pickup, 9):
		return false
	await frames(12)
	return true


func _count_defeat(entity: Node2D) -> void:
	kills[entity.species] = int(kills.get(entity.species, 0)) + 1


func _watch_drops() -> void:
	if is_instance_valid(ruins) and Engine.get_physics_frames() % 60 == 0 and ruins._bag_full():
		full_bag_samples += 1


func verify(condition: bool, description: String) -> bool:
	if description == "ending visible and final victory saved":
		var saved: Dictionary = Save.read().get("state", {})
		condition = condition and hunter.level == Progression.MAX_LEVEL and saved.get("player_level", -1) == 10
		description = "ending visible and level 10 persisted with final victory"
	return super.verify(condition, description)


func mark(event: String) -> void:
	super.mark(event)
	if event.begins_with("PASS opened the temple west gate") or event.contains("shot down the crab") or (
			event.contains("broke the keeper") or event.contains("ending visible")):
		capture_until = Engine.get_physics_frames() + 180


func _sample(event := "") -> void:
	super._sample(event)
	if stats == null or (event.is_empty() and Engine.get_physics_frames() % 30 != 0):
		return
	var active := is_instance_valid(ruins) and is_instance_valid(hunter)
	stats.store_csv_line(PackedStringArray([
		str(seconds()), REGION[latest_region] if active else "title",
		str(hunter.position.x) if active else "", str(hunter.position.y) if active else "",
		str(hunter.health) if active else "", str(hunter.level) if active else "",
		str(ruins.soul_balance) if active else "", str(ruins.inventory.size()) if active else "",
		str(Progression.bag_capacity(hunter.level)) if active else "", str(trips), str(income_combat),
		str(income_salvage), str(spent_levels), str(spent_gear), event,
	]))
	if not event.is_empty():
		stats.flush()


func _schedule_capture() -> void:
	if capture_dir.is_empty() or capture_pending or Engine.get_physics_frames() > capture_until or (
			Engine.get_physics_frames() % 6 != 0):
		return
	capture_pending = true
	await RenderingServer.frame_post_draw
	if root != null:
		var image := root.get_texture().get_image()
		image.resize(960, 540, Image.INTERPOLATE_BILINEAR)
		image.save_jpg("%s/shot-%05d.jpg" % [capture_dir, capture_index], 0.87)
		capture_index += 1
	capture_pending = false
