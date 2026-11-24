extends SceneTree

const Armory := preload("res://scripts/game/ruin_armory.gd")
const Campaign := preload("res://scripts/game/campaign.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")
const PROPS := preload("res://assets/environment/common/props/props_tileset.tres")
const PROP_COUNTS := [22, 15, 15, 13]
const CHEST_COUNTS := [2, 5, 4, 0]

var failures := 0
var output := OS.get_environment("HUNTER_PROP_PROOF")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check_tile_sources()
	for region in Campaign.SCENES.size():
		change_scene_to_file(Campaign.SCENES[region])
		await scene_changed
		var level: Ruins = current_scene
		level.hunter.set_physics_process(false)
		for enemy in level.enemies:
			enemy.set_physics_process(false)
		check_props(level, region)
		if not output.is_empty():
			await capture(level, level.landscape.campfires[0].global_position, "%d-camp" % region)
			var focus := level.landscape.portals[0].global_position
			await capture(level, focus, "%d-arch" % region)
			await capture(level, level.landscape.reliquaries[0].global_position, "%d-reliquary" % region)
			if region == Campaign.Region.CORRIDOR:
				var gate := level.landscape.light_gates[0]
				await capture(level, gate.global_position, "corridor-01-locked")
				level.lantern_found = true
				level._sync_region_gate()
				await capture(level, gate.global_position, "corridor-02-open")
		if region == Campaign.Region.CORRIDOR:
			await check_weapon_chest(level)
		if region == Campaign.Region.VOLCANO:
			await check_lava_tiles(level)

	await check_moved_and_copied_props()
	quit(1 if failures else 0)


func check_tile_sources() -> void:
	var expected_names := ["Scene Props", "Weapons", "Armor", "Effects"]
	var expected_counts := [20, 3, 8, 3]
	check(PROPS.get_source_count() == expected_names.size(), "TileSet has all named scene collections")
	for source_id in expected_names.size():
		var source := PROPS.get_source(source_id) as TileSetScenesCollectionSource
		if source == null:
			check(false, "%s scene collection exists" % expected_names[source_id])
			continue
		var count := source.get_scene_tiles_count()
		var categorized: bool = source.resource_name == expected_names[source_id] and count == expected_counts[source_id]
		for index in count:
			var packed := source.get_scene_tile_scene(source.get_scene_tile_id(index))
			var prop := packed.instantiate()
			if prop is Ruins.Landscape.EquipmentChest:
				var item_id: String = prop.equipment_id
				categorized = categorized and ((source_id == 1 and Armory.WEAPONS.has(item_id))
					or (source_id == 2 and Armory.WEAR.has(item_id)))
			else:
				categorized = categorized and (source_id == 0 or (source_id == 3
					and prop.has_node("Pool") and prop.has_node("Glow")))
			prop.free()
		check(categorized, "%s contains %d correctly categorized tiles" % [source.resource_name, count])


func check_props(level: Ruins, region: int) -> void:
	var layers: Array[String] = []
	var count := 0
	for layer in level.landscape.get_children():
		if layer is not TileMapLayer or not layer.is_in_group("prop_tiles"):
			continue
		layers.append(layer.name)
		check(layer.tile_set == PROPS and layer.tile_set.tile_size == Vector2i(20, 20),
			"%s/%s uses the shared 20 × 20 prop TileSet" % [level.name, layer.name])
		var cells: Array[Vector2i] = layer.get_used_cells()
		var instances := {}
		for prop in layer.get_children():
			instances[(prop as Node2D).position] = prop.scene_file_path
		var matches := 0
		for cell in cells:
			var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetScenesCollectionSource
			var scene_id: int = layer.get_cell_alternative_tile(cell)
			var scene := source.get_scene_tile_scene(scene_id)
			if scene != null and instances.get(layer.map_to_local(cell)) == scene.resource_path:
				matches += 1
		check(matches == cells.size(), "%s/%s instantiates all %d scene tiles at their cell centers"
			% [level.name, layer.name, cells.size()])
		count += matches
	layers.sort()
	check(layers == ["BackgroundProps", "Effects", "ObstacleProps", "Props"],
		"%s uses the standard layer names" % level.name)
	check(count == PROP_COUNTS[region], "%s has all %d migrated prop placements" % [level.name, PROP_COUNTS[region]])
	var landscape := level.landscape
	check(landscape.campfires.size() == 1 and landscape.portals.size() == 1 and landscape.reliquaries.size() == 1,
		"%s registers the campfire, exit and reliquary from scene tiles" % level.name)
	check(landscape.equipment_chests.size() == CHEST_COUNTS[region],
		"%s registers all %d equipment chests" % [level.name, CHEST_COUNTS[region]])
	var terrain := landscape.get_node("Terrain") as TileMapLayer
	for chest in landscape.equipment_chests:
		var position := terrain.to_local(chest.global_position)
		var cell := terrain.local_to_map(position)
		check(terrain.get_cell_tile_data(cell) != null and terrain.get_cell_tile_data(cell + Vector2i.UP) == null
			and is_equal_approx(position.y, terrain.map_to_local(cell).y - 10.0),
			"%s rests on a terrain tile at %s" % [chest.equipment_id, position])


func check_lava_tiles(level: Ruins) -> void:
	var layer := level.get_node("Landscape/Effects") as TileMapLayer
	var obstacle := level.get_node("Landscape/ObstacleProps") as TileMapLayer
	var barrier := obstacle.get_child(0).get_node("Collision") as CollisionShape2D
	check(barrier.global_position == Vector2(390, 552) and barrier.shape.size == Vector2(400, 20),
		"lava barrier retains its world coordinates and collision size")
	var original := Vector2i(15, 27)
	var target := original + Vector2i(5, -4)
	var focus := layer.to_global(layer.map_to_local(original)) + Vector2(90, 0)
	check(layer.get_used_cells().size() == 4, "volcano places all four lava pools")
	if not output.is_empty():
		await capture(level, focus, "lava-01-original")
	layer.set_pattern(target, layer.get_pattern([original]))
	layer.update_internals()
	var copied := false
	for instance in layer.get_children():
		if instance.position == layer.map_to_local(target):
			copied = instance.has_node("Pool") and instance.has_node("Glow")
	check(copied, "copying the lava cell places both the pool and its glow at the new cell")
	if not output.is_empty():
		await capture(level, focus, "lava-02-copied")
	layer.erase_cell(target)
	layer.update_internals()
	await process_frame
	check(layer.get_child_count() == 4, "erasing the copied lava cell removes both visuals")


func check_weapon_chest(level: Ruins) -> void:
	for chest in level.landscape.equipment_chests:
		if chest.equipment_id != "sluice_spear":
			continue
		var at := chest.global_position
		level.hunter.position = at
		if not output.is_empty():
			await capture(level, at, "weapon-01-chest")
		await interact()
		await process_frame
		check(level.hunter.unlocked_weapons.has("sluice_spear") and not chest.visible,
			"opening the spear chest in Weapons grants the spear and hides the chest")
		if not output.is_empty():
			await capture(level, at, "weapon-02-looted")
		return
	check(false, "the original spear chest is in the corridor")


func check_moved_and_copied_props() -> void:
	var old_position := Vector2(1500, 440)
	var chest_position := Vector2(1160, 540)
	var camp_position := Vector2(1020, 540)
	var level := (load(Campaign.SCENES[0]) as PackedScene).instantiate() as Ruins
	var props := level.get_node("Landscape/Props") as TileMapLayer
	var original_camp := props.get_used_cells_by_id(0, Vector2i.ZERO, 1)[0]
	var original_chest := props.local_to_map(old_position - props.position)

	# Stamp the same pattern that the TileMap clipboard copies, then erase the chest's old cell.
	props.set_pattern(props.local_to_map(camp_position - props.position), props.get_pattern([original_camp]))
	props.set_pattern(props.local_to_map(chest_position - props.position), props.get_pattern([original_chest]))
	props.erase_cell(original_chest)
	unload_current_scene()
	root.add_child(level)
	current_scene = level
	level.hunter.set_physics_process(false)
	for enemy in level.enemies:
		enemy.set_physics_process(false)

	check(level.landscape.campfires.size() == 2 and level.landscape.campfires.any(
		func(campfire: Node2D) -> bool: return campfire.global_position == camp_position),
		"copying a campfire tile creates a second usable campfire")
	level.hunter.position = camp_position
	if not output.is_empty():
		await capture(level, camp_position, "copy-01-campfires")
	await interact()
	check(level.camp_menu.visible, "interacting at the copied cell opens the camp menu")
	if not output.is_empty():
		await capture(level, camp_position, "copy-02-camp-menu")
	level._set_camp_open(false)
	level.hunter.set_physics_process(false)
	await physics_frame
	await physics_frame
	level.hunter.position = old_position
	check(level._near_treasure().is_empty(), "erasing the old chest cell removes its interaction")
	level.hunter.position = chest_position
	check(level._near_treasure() == "cliff_boots", "the moved chest exposes its original reward at its new cell")
	if not output.is_empty():
		await capture(level, chest_position, "move-01-chest")
	await interact()
	await process_frame
	check(level.obtained_equipment.has("cliff_boots") and level._near_treasure().is_empty(),
		"opening the moved chest grants the equipment once")
	if not output.is_empty():
		await capture(level, chest_position, "move-02-looted")


func interact() -> void:
	Input.action_press("hunt_interact")
	for frame in range(3):
		await physics_frame
	Input.action_release("hunt_interact")


func capture(level: Ruins, focus: Vector2, name: String) -> void:
	level.camera.position_smoothing_enabled = false
	level.camera.position = focus - level.hunter.position + Vector2(0, -150)
	level.camera.force_update_scroll()
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(output.path_join(name + ".png")) == OK, "captured %s" % name)


func check(condition: bool, message: String) -> void:
	print("%s %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1
