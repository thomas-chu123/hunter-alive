extends SceneTree

const Ruins := preload("res://scripts/scene/ruins.gd")
const Save := preload("res://scripts/game/camp_save.gd")
const LEVEL := "res://scenes/ruins/ruins_3.tscn"

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	set_meta(Save.RESTORE_META, {"stage": 3, "region": 0, "player_level": 10})
	change_scene_to_file(LEVEL)
	await scene_changed
	var level := current_scene as Ruins
	level.loot_rng.seed = 42
	var background := level.get_node("Landscape/BackgroundProps") as TileMapLayer
	var terrain := level.get_node("Landscape/Terrain") as TileMapLayer
	for id in range(1, 11):
		var cells := background.get_used_cells_by_id(1, Vector2i.ZERO, id)
		check(cells.size() == 1 and terrain.get_cell_tile_data(cells.front()) != null
			and terrain.get_cell_tile_data(cells.front() + Vector2i.UP) == null,
			"woodland tile %d is painted on exposed terrain" % id)

	var ranks: Array[int] = []
	var rewarded: Dictionary = {}
	var restored_key_count := 0
	for chest in level.landscape.equipment_chests:
		if chest.loot_rank == 0:
			continue
		ranks.append(chest.loot_rank)
		var ground := terrain.local_to_map(terrain.to_local(chest.global_position))
		check(terrain.get_cell_tile_data(ground) != null and terrain.get_cell_tile_data(ground + Vector2i.UP) == null,
			"%s stands on exposed ground" % chest.name)
		level.hunter.global_position = chest.global_position
		var previous := level.inventory.size()
		if chest.loot_rank == 5:
			var real_inventory := level.inventory.duplicate()
			while not level._bag_full():
				level.inventory.append(real_inventory.front())
			var rng_state := level.loot_rng.state
			level._interact()
			check(not chest.opened and level.loot_rng.state == rng_state and level.opened_treasure.is_empty(),
				"full bag preserves the closed chest and its random roll")
			level.inventory.assign(real_inventory)
		var base := chest.sprite.get_rect().end.y
		level._interact()
		var item: Dictionary = level.inventory.back()
		rewarded[item.item] = true
		check(level.inventory.size() == previous + 1 and item.rank == chest.loot_rank
			and level.loot_catalog.has(item.item), "%s grants one catalog item at +%d" % [chest.name, chest.loot_rank])
		check(chest.opened and chest.sprite.texture == chest.open_texture
			and chest.open_texture != chest.closed_texture and is_equal_approx(chest.sprite.get_rect().end.y, base),
			"%s opens with a matching sprite and a fixed base" % chest.name)
		level._interact()
		check(level.inventory.size() == previous + 1, "%s pays only once" % chest.name)
	ranks.sort()
	check(ranks == [1, 2, 3, 4, 5], "all five chest tiers are painted")
	check(rewarded.size() > 1, "different chests can award different equipment")

	var state := level._checkpoint_state()
	set_meta(Save.RESTORE_META, state)
	change_scene_to_file(LEVEL)
	await scene_changed
	level = current_scene as Ruins
	for chest in level.landscape.equipment_chests:
		if chest.loot_rank > 0 and chest.opened and chest.sprite.texture == chest.open_texture:
			restored_key_count += 1
	check(restored_key_count == 5, "restoring a checkpoint preserves all five opened chests")
	quit(1 if failures else 0)


func check(passed: bool, label: String) -> void:
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
