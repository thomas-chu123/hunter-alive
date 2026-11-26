extends SceneTree

const Progression := preload("res://scripts/game/ruin_progression.gd")
const Equipment := preload("res://scripts/game/ruin_equipment.gd")
const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const Save := preload("res://scripts/game/camp_save.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")

var level: Ruins
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	verify_tables()
	await load_temple()
	check(level.hunter.level == 0 and level.hunter.max_health() == 6 and level.inventory.size() == 2,
		"new game starts at level 0 with two items in a ten-slot backpack")
	for rank in range(2, 6):
		level._grant_equipment("hunter_knife", rank, true)
	for id in ["sealed_cap", "reed_coat", "rune_gloves", "cliff_boots"]:
		level._grant_equipment(id)
	check(level.inventory.size() == 10 and level._bag_full(), "every individual item and equipped weapons use backpack slots")
	var gold_knife := find_uid("hunter_knife", 5)
	var wood_knife := find_uid("hunter_knife", 1)

	var beast = spawn_loot_encounter()
	check(beast.level == 1 and beast.max_health == 4, "enemy instance uses its configured level and hit points")
	var enemy_hp_before: int = beast.health
	level.hunter.position = Vector2(1060, 539)
	level.hunter.facing = 1.0
	await frames(8)
	Input.action_press("hunt_attack")
	for _frame in range(100):
		await physics_frame
		if not is_instance_valid(beast):
			break
	Input.action_release("hunt_attack")
	var random_drop := find_rolled_drop()
	check(enemy_hp_before == 4 and not is_instance_valid(beast) and not random_drop.is_empty(),
		"real knife input defeats the enemy and its seeded drop roll produces equipment")
	if random_drop.is_empty():
		quit(1)
		return
	var loot_id: String = random_drop.kind
	check(random_drop.rank == 1, "default hare drop keeps its +1 quality on the floor")
	level.hunter.position.x = random_drop.at.x
	await frames(30)
	check(not find_rolled_drop().is_empty() and level.inventory.size() == 10 and level.soul_balance in [1, 2],
		"a full bag leaves gear on the ground while still collecting a soul reward")
	await key(KEY_I)
	check(level.gear_menu.visible, "I opens the ranked inventory")
	var interiors := {}
	for rank in range(1, 6):
		var index := level.gear_uids.find(find_uid("hunter_knife", rank))
		var texture := level.gear_list.get_item_icon(index)
		var expected: Color = Progression.COLORS[rank]
		var image: Image = texture.get_image()
		interiors[hash(image.get_region(Rect2i(3, 3, 58, 58)).get_data())] = true
		check(image.get_pixel(0, 0).is_equal_approx(expected),
			"quality +%d renders its own border around the same knife artwork" % rank)
	check(interiors.size() == 1, "the art inside all five borders is identical")
	await view(78)
	var gold_index := level.gear_uids.find(gold_knife)
	check(gold_index == 0, "highest-ranked weapon appears first in the equipment grid")
	await select_gear(gold_index)
	check(level.gear_stat_targets["攻擊力"].text == "6" and level.gear_stat_targets["攻擊力"].is_visible_in_tree()
		and level.gear_stat_targets["攻擊力"].get_theme_color("font_color") == Color("#ff9890")
		and level.hunter.weapon_damage("hunter_knife") == 2, "gold duplicate previews damage 2 to 6 in red before equipping")
	await click(level.gear_apply)
	check(level._equipped_uid("武器") == gold_knife and level.hunter.weapon_damage("hunter_knife") == 6,
		"equipping the gold duplicate increases the selected weapon's actual damage")
	await view(65)
	var armor_uid := find_uid("sealed_cap", 1)
	await select_gear(level.gear_uids.find(armor_uid))
	await click(level.gear_apply)
	check(level._equipped_uid("頭部") == armor_uid and level.hunter.armor_reduction() == 3,
		"wearable quality contributes armor only while worn")
	var destroy_uid := find_uid("cliff_boots", 1)
	await select_gear(level.gear_uids.find(destroy_uid))
	await click(level.destroy_item)
	check(level.destroy_dialog.visible and level.inventory.size() == 10, "destroying an item requires confirmation")
	await view(54)
	await key(KEY_ENTER)
	await frames(8)
	check(level._inventory_item(destroy_uid).is_empty() and level.inventory.size() == 9, "confirmed destruction frees one backpack slot")
	await key(KEY_I)
	await frames(38)
	check(find_rolled_drop().is_empty() and level.inventory.size() == 10 and find_uid(loot_id, 1) != 0,
		"the blocked equipment drop can be picked up after freeing a slot")
	# The workshop only accepts unequipped copies for salvage.
	await key(KEY_I)
	await select_gear(level.gear_uids.find(wood_knife))
	await click(level.gear_apply)
	await key(KEY_I)
	await view(60)
	var soul_reward := level.soul_balance
	level.soul_balance += 120
	level.hunter.position = level.landscape.campfires[0].global_position
	level.hunter.velocity = Vector2.ZERO
	await frames(5)
	await tap("hunt_interact")
	await frames(5)
	check(level.camp_menu.visible, "E opens the camp progression controls")
	await click(level.camp_level_up)
	check(level.hunter.level == 1 and level.hunter.max_health() == 7 and level.soul_balance == soul_reward + 110
		and Progression.bag_capacity(level.hunter.level) == 12, "first level costs 10 souls, adds one HP and two slots")
	await view(68)
	await click(level.camp_level_up)
	check(level.hunter.level == 2 and level.soul_balance == soul_reward + 90 and level.hunter.max_health() == 8
		and Progression.bag_capacity(level.hunter.level) == 14, "level two costs 20 souls and grows health and capacity")
	select_camp(wood_knife)
	await view(56)
	await click(level.camp_rank_up)
	check(level._inventory_item(wood_knife).rank == 2 and level.soul_balance == soul_reward + 80
		and level._inventory_item(gold_knife).rank == 5, "first wood upgrade costs 10 souls and affects only the selected copy")
	await click(level.camp_rank_up)
	check(level._inventory_item(wood_knife).rank == 3 and level.soul_balance == soul_reward + 60,
		"the second equipment upgrade costs 20 souls")
	await view(62)
	select_camp(armor_uid)
	await click(level.camp_rank_up)
	check(level._inventory_item(armor_uid).rank == 2 and level.hunter.armor_reduction() == 6,
		"armor upgrade refreshes the currently equipped item")
	select_camp(gold_knife)
	check(level.camp_rank_up.disabled, "gold +5 cannot be upgraded")
	await view(54)
	var balance_before := level.soul_balance
	var count_before := level.inventory.size()
	await click(level.camp_salvage)
	check(level.soul_balance == balance_before + 10 and level.inventory.size() == count_before - 1
		and level._inventory_item(gold_knife).is_empty() and level._inventory_item(wood_knife).rank == 3,
		"camp salvage exchanges the selected gold copy for ten souls and frees its slot")
	await view(57)
	var save_state: Dictionary = Save.read().get("state", {})
	check(save_state.player_level == 2 and int(save_state.soul_balance) == level.soul_balance
		and save_state.inventory.size() == level.inventory.size(), "camp transactions persist immediately")
	await click(level.camp_save_exit)
	await scene_changed
	await frames(12)
	await click(current_scene.continue_game)
	await scene_changed
	level = current_scene
	await frames(12)
	check(level.hunter.level == 2 and level.soul_balance == balance_before + 10
		and level._inventory_item(wood_knife).rank == 3 and level._equipped_uid("頭部") == armor_uid,
		"Continue restores levels, currency, individual ranks and equipped instance IDs")
	var prior_hp := level.hunter.health
	level.hunter.armor_credit = 94
	level.hunter.hurt(level.hunter.position.x + 12, 1)
	check(level.hunter.health == prior_hp and level.hunter.armor_credit == 0,
		"equipped armor's accumulated reduction prevents actual incoming damage")
	await verify_level_cap()
	await view(78)
	await verify_legacy_save()
	if DisplayServer.get_name() != "headless":
		change_scene_to_file("res://scenes/title/title.tscn")
		await scene_changed
		await frames(62)
	quit(1 if failures else 0)


func verify_tables() -> void:
	for tier in range(1, 6):
		check(Progression.drop_rank(0.38749, tier) == tier and Progression.drop_rank(0.3875, tier) == 0,
			"tier %d equipment drops at the configured chance" % tier)
	var lower: int = Bestiary.creatures.spider.soul_reward[0]
	var boss: Dictionary = Bestiary.creatures.seal_keeper
	check(Bestiary.creatures.size() == 21 and Equipment.catalog_ids().size() == 30
		and boss.level == 10 and boss.health > Bestiary.creatures.spider.health and boss.soul_reward[0] > lower,
		"configured enemy levels, HP and soul rewards differ across the roster")


func verify_level_cap() -> void:
	level.soul_balance = 1000
	await tap("hunt_interact")
	await frames(5)
	if not level.camp_menu.visible:
		check(false, "reopened camp after Continue")
		return
	for _step in range(8):
		level._level_up()
	check(level.hunter.level == 10 and level.hunter.max_health() == 16
		and Progression.bag_capacity(level.hunter.level) == 30 and level.soul_balance == 480
		and level.camp_level_up.disabled, "character caps at level 10 with 30 slots and escalating costs")


func verify_legacy_save() -> void:
	var items := ["linen_hood", "hunter_wraps", "moss_vest", "scaleveil_hood", "ember_staff",
		"root_blade", "cliff_boots", "ash_cowl", "reed_coat", "copper_helm"]
	set_meta(Save.RESTORE_META, {
		"owned_equipment": items, "gear": {"頭部": "linen_hood"}, "weapon": "hunter_bow", "bow_level": 2,
	})
	await load_temple()
	check(level.inventory.size() == 12 and level._bag_full() and level.hunter.level == 0
		and level.hunter.bow_level == 2 and level.hunter.weapon_damage("hunter_bow") == 3
		and level.hunter.max_health() == 7 and find_uid("moss_vest", 1) != 0,
		"legacy saves keep every item, old weapon upgrades and gear even when over the new capacity")


func load_temple() -> void:
	change_scene_to_file("res://scenes/ruins/ruins.tscn")
	await scene_changed
	level = current_scene
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	await frames(10)


func spawn_loot_encounter() -> Node:
	level._add_monster("dust_hare", 1116)
	var monster = level.enemies.back()
	monster._start_recovery(2.2)
	var rng := RandomNumberGenerator.new()
	for seed in range(10000):
		rng.seed = seed
		rng.randi_range(1, 2)
		if Progression.drop_rank(rng.randf(), monster.tier) > 0:
			level.loot_rng.seed = seed
			break
	return monster


func find_rolled_drop() -> Dictionary:
	for drop in level.drops:
		if drop.rolled:
			return drop
	return {}


func find_uid(id: String, rank: int) -> int:
	for entry in level.inventory:
		if entry.item == id and entry.rank == rank:
			return int(entry.uid)
	return 0


func select_camp(uid: int) -> void:
	for index in range(level.camp_rank_items.item_count):
		if level.camp_rank_items.get_item_metadata(index) == uid:
			level.camp_rank_items.select(index)
			level.camp_rank_items.item_selected.emit(index)
			return


func select_gear(index: int) -> void:
	level.gear_list.select(index)
	level.gear_list.item_selected.emit(index)
	await process_frame


func tap(action: StringName) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	root.push_input(event, true)
	await process_frame
	var up := event.duplicate() as InputEventKey
	up.pressed = false
	root.push_input(up, true)
	await process_frame


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


func view(count: int) -> void:
	if OS.has_feature("movie"):
		await frames(count)


func frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame


func check(ok: bool, description: String) -> void:
	print("%5.2fs %s %s" % [Engine.get_physics_frames() / 60.0, "PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1
