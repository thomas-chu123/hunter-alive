extends SceneTree

const Armory := preload("res://scripts/game/ruin_armory.gd")
const Campaign := preload("res://scripts/game/campaign.gd")
const Save := preload("res://scripts/game/camp_save.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")
const TILESETS := {
	"Props": preload("res://assets/environment/common/props/props_tileset.tres"),
	"BackgroundProps": preload("res://assets/environment/common/props/background_props_tileset.tres"),
	"ObstacleProps": preload("res://assets/environment/common/props/obstacle_props_tileset.tres"),
	"Traps": preload("res://assets/environment/common/traps/trap_tileset.tres"),
}
const PROP_COUNTS := [22, 15, 15, 13]
const CHEST_COUNTS := [2, 5, 4, 0]

var failures := 0
var output := OS.get_environment("HUNTER_PROP_PROOF")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check_tile_sources()
	check_brazier_art()
	check_seeded_braziers()
	for region in Campaign.SCENES.size():
		change_scene_to_file(Campaign.SCENES[region])
		await scene_changed
		var level: Ruins = current_scene
		level.hunter.set_physics_process(false)
		for enemy in level.enemies:
			enemy.set_physics_process(false)
		check_props(level, region)
		check_lighting(level)
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

	for region in Campaign.IDS.size():
		for stage in range(1, Campaign.BOSS_STAGE + 1):
			change_scene_to_file(Campaign.scene_path({"region": region, "stage": stage}))
			await scene_changed
			var level := current_scene as Ruins
			check_lighting(level)
			check_floor_visibility(level)

	await check_moved_and_copied_props()
	await check_reliquary()
	quit(1 if failures else 0)


func check_tile_sources() -> void:
	var sources := {
		"Props": {0: ["Props", 12], 1: ["Weapons", 3], 2: ["Armor", 8], 3: ["Traversal", 4]},
		"BackgroundProps": {0: ["BackgroundProps", 8]},
		"ObstacleProps": {0: ["ObstacleProps", 3]},
		"Traps": {0: ["Mechanical", 5], 1: ["Elemental", 5], 2: ["Portals", 4], 3: ["Environment Effects", 3]},
	}
	for layer_name in sources:
		var tileset: TileSet = TILESETS[layer_name]
		check(tileset.resource_name == layer_name and tileset.get_source_count() == sources[layer_name].size(),
			"%s uses its own named TileSet" % layer_name)
		for source_id in sources[layer_name]:
			var expected: Array = sources[layer_name][source_id]
			var source := tileset.get_source(source_id) as TileSetScenesCollectionSource
			check(source != null and source.resource_name == expected[0] and source.get_scene_tiles_count() == expected[1],
				"%s contains %d tiles in %s" % [layer_name, expected[1], expected[0]])
			if source == null:
				continue
			for index in source.get_scene_tiles_count():
				var packed := source.get_scene_tile_scene(source.get_scene_tile_id(index))
				var prop := packed.instantiate()
				if prop is Ruins.Landscape.EquipmentChest:
					var item_id: String = prop.equipment_id
					check(layer_name == "Props" and ((source_id == 1 and Armory.WEAPONS.has(item_id))
						or (source_id == 2 and Armory.WEAR.has(item_id))), "%s is categorized by equipment type" % item_id)
				prop.free()


func check_props(level: Ruins, region: int) -> void:
	var layers: Array[String] = []
	var count := 0
	for layer in level.landscape.get_children():
		if layer is not TileMapLayer or not layer.is_in_group("prop_tiles"):
			continue
		layers.append(layer.name)
		check(layer.tile_set == TILESETS.get(String(layer.name)) and layer.tile_set.tile_size == Vector2i(20, 20),
			"%s/%s uses its 20 × 20 TileSet" % [level.name, layer.name])
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
		if layer.name == &"Props":
			count -= layer.get_used_cells_by_id(0, Vector2i.ZERO, Ruins.Landscape.BRAZIER_TILE_ID).size()
	layers.sort()
	check(layers == ["BackgroundProps", "ObstacleProps", "Props", "Traps"] and not level.landscape.has_node("Effects"),
		"%s uses the shared Traps layer in place of Effects" % level.name)
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


func check_brazier_art() -> void:
	var source := TILESETS.Props.get_source(0) as TileSetScenesCollectionSource
	var brazier := source.get_scene_tile_scene(Ruins.Landscape.BRAZIER_TILE_ID).instantiate()
	var campfire := source.get_scene_tile_scene(1).instantiate()
	var sprite := brazier.get_node("Sprite") as Sprite2D
	var camp_sprite := campfire.get_node("Sprite") as Sprite2D
	var art := sprite.texture as AtlasTexture
	check(art != null and art.atlas != null and art.atlas != camp_sprite.texture,
		"the randomized brazier has its own art distinct from the campfire")
	var bounds := sprite.transform * sprite.get_rect()
	var light := brazier.get_node("Light") as PointLight2D
	check(bounds.size.y > bounds.size.x and is_zero_approx(bounds.end.y)
		and bounds.has_point(light.position) and light.position.y < bounds.get_center().y,
		"the narrow brazier stands at the tile origin and the light is in its fire basket")
	brazier.free()
	campfire.free()


func check_seeded_braziers() -> void:
	var packed := load(Campaign.scene_path({})) as PackedScene
	var layouts: Array[Array] = []
	var random := RandomNumberGenerator.new()
	for placement_seed in [12, 12, 34]:
		var level := packed.instantiate() as Ruins
		var landscape := level.get_node("Landscape") as Ruins.Landscape
		var props := landscape.get_node("Props") as TileMapLayer
		var authored_cells := props.get_used_cells()
		random.seed = placement_seed
		landscape.place_braziers(Ruins.STAGE_WIDTH, random)
		var cells := props.get_used_cells_by_id(0, Vector2i.ZERO, Ruins.Landscape.BRAZIER_TILE_ID)
		cells.sort()
		layouts.append(cells)
		check(not cells.is_empty() and cells.all(func(cell: Vector2i) -> bool: return cell not in authored_cells),
			"seed %d adds braziers to empty cells" % placement_seed)
		level.free()
	check(layouts[0] == layouts[1] and layouts[0] != layouts[2], "seeded braziers reproduce and vary across seeds")


func check_lighting(level: Ruins) -> void:
	var path := level.scene_file_path.get_file()
	var ambient := level.get_node_or_null("AmbientLight") as CanvasModulate
	var nearby := level.hunter.get_node_or_null("NearbyLight") as PointLight2D
	var ambient_luminance := ambient.color.get_luminance() if ambient != null else 0.0
	check(ambient_luminance >= 0.28 and ambient_luminance <= 0.38 and level.background.self_modulate == ambient.color
		and level.health_hearts.get_canvas() != ambient.get_canvas(), "%s uses moderate ambient light with a separate HUD canvas" % path)
	check(nearby != null and nearby.enabled and nearby.shadow_enabled and nearby.texture != null and nearby.energy > 0
		and nearby.texture.get_width() * nearby.texture_scale < 400.0, "%s lights a small area around the hunter and casts terrain shadows" % path)

	var props := level.landscape.get_node("Props") as TileMapLayer
	var terrain := level.landscape.get_node("Terrain") as TileMapLayer
	var braziers: Array[Node] = get_nodes_in_group("brazier_light")
	var cells := props.get_used_cells_by_id(0, Vector2i.ZERO, Ruins.Landscape.BRAZIER_TILE_ID)
	check(cells.size() >= 2 and cells.size() == braziers.size(), "%s instantiates %d brazier light tiles" % [path, cells.size()])
	for brazier: Node2D in braziers:
		var floor_cell := terrain.local_to_map(terrain.to_local(brazier.global_position) + Vector2.DOWN)
		var lamp := brazier.get_node_or_null("Light") as PointLight2D
		check(brazier.get_parent() == props and terrain.get_cell_source_id(floor_cell) >= 0
			and terrain.get_cell_source_id(floor_cell + Vector2i.UP) == -1
			and lamp != null and lamp.enabled and lamp.shadow_enabled and lamp.texture != null and lamp.color.r > lamp.color.b,
			"%s has a floor-mounted warm light with shadows at %s" % [path, brazier.position])
	cells.sort()
	for index in range(1, cells.size()):
		check(props.map_to_local(cells[index]).x - props.map_to_local(cells[index - 1]).x >= Ruins.Landscape.BRAZIER_MIN_GAP,
			"%s keeps space between brazier lights" % path)


func check_floor_visibility(level: Ruins) -> void:
	var path := level.scene_file_path.get_file()
	var visibility := level.get_node_or_null("FloorVisibility") as Ruins.FloorVisibility
	if level.stage == Campaign.BOSS_STAGE:
		check(visibility == null, "%s leaves the single-floor arena open" % path)
		return
	check(visibility != null and visibility.visible_band(500.0) == Vector2(420.0, 560.0)
		and visibility.visible_band(459.0) == Vector2(420.0, 560.0),
		"%s shows the ground floor and its short steps without exposing the floor above" % path)
	if visibility == null:
		return
	check(visibility.visible_band(410.0) == Vector2(300.0, 440.0)
		and visibility.visible_band(40.0) == Vector2(-INF, 80.0),
		"%s changes floors across the slab and leaves the top floor open above" % path)
	check(visibility.layer > 0 and visibility.layer < (level.health_hearts.get_canvas_layer_node() as CanvasLayer).layer,
		"%s draws the darkness above the world and below the HUD" % path)
	var upper_mask := visibility.get_child(0) as ColorRect
	var lower_mask := visibility.get_child(1) as ColorRect
	for foot_y in [540.0, 420.0]:
		level.hunter.position.y = foot_y
		level.camera.reset_smoothing()
		level.camera.force_update_scroll()
		visibility._process(0.0)
		var canvas := root.get_canvas_transform()
		var view_size := root.get_visible_rect().size
		var ceiling_y := clampf((canvas * Vector2(0, foot_y - 120.0)).y, 0.0, view_size.y)
		var floor_y := clampf((canvas * Vector2(0, foot_y + 20.0)).y, 0.0, view_size.y)
		check(upper_mask.size.is_equal_approx(Vector2(view_size.x, ceiling_y))
			and is_equal_approx(lower_mask.position.y, floor_y)
			and lower_mask.size.is_equal_approx(Vector2(view_size.x, view_size.y - floor_y))
			and upper_mask.color.a == 1.0 and lower_mask.color.a == 1.0,
			"%s masks both other floors to the viewport edges at y=%d" % [path, foot_y])


func check_lava_tiles(level: Ruins) -> void:
	var layer := level.get_node("Landscape/Traps") as TileMapLayer
	var obstacle := level.get_node("Landscape/ObstacleProps") as TileMapLayer
	var barrier := obstacle.get_child(0).get_node("Collision") as CollisionShape2D
	check(barrier.global_position == Vector2(390, 552) and barrier.shape.size == Vector2(400, 20),
		"lava barrier retains its world coordinates and collision size")
	var original := Vector2i(15, 27)
	var target := original + Vector2i(5, -4)
	var focus := layer.to_global(layer.map_to_local(original)) + Vector2(90, 0)
	check(layer.get_used_cells().size() == 4, "volcano places all four lava pools")
	var pool_widths := {Vector2(300, 540): 180, Vector2(1200, 540): 280,
		Vector2(2000, 540): 240, Vector2(2800, 540): 280}
	for instance: Node2D in layer.get_children():
		var pool := instance.get_node("Pool") as Polygon2D
		check(pool_widths.get(instance.global_position) == roundi(pool.polygon[1].x)
			and instance.has_node("Glow"), "lava pool and glow retain their placement and width at %s" % instance.global_position)
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
		var base := chest.sprite.get_rect().end.y
		level.hunter.position = at
		if not output.is_empty():
			await capture(level, at, "weapon-01-chest")
		await interact()
		await process_frame
		check(level.hunter.unlocked_weapons.has("sluice_spear") and level._near_treasure().is_empty(),
			"opening the spear chest grants the spear and consumes the interaction")
		check_open_chest(chest, base, "spear chest")
		if not output.is_empty():
			await capture(level, at, "weapon-02-looted")

		set_meta(Save.RESTORE_META, level._checkpoint_state())
		change_scene_to_file(level.scene_file_path)
		await scene_changed
		var restored := current_scene as Ruins
		for restored_chest in restored.landscape.equipment_chests:
			if restored_chest.equipment_id == "sluice_spear":
				check_open_chest(restored_chest, base, "spear chest restored from checkpoint")
				return
		check(false, "the restored scene contains the spear chest")
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


func check_reliquary() -> void:
	var scene: String = Campaign.SCENES[Campaign.Region.TEMPLE]
	change_scene_to_file(scene)
	await scene_changed
	var level := current_scene as Ruins
	var cache := level.landscape.reliquaries[0]
	var base := cache.sprite.get_rect().end.y
	check(not cache.opened and cache.sprite.texture == cache.closed_texture, "a fresh reliquary is closed")
	level.hunter.set_physics_process(false)
	level.hunter.position = cache.global_position
	if not output.is_empty():
		await capture(level, cache.global_position, "cache-01-closed")
	var materials := level.materials
	await interact()
	check(level.landscape.cache_open and level.materials == materials + 3, "opening the reliquary grants materials")
	check_open_chest(cache, base, "reliquary")
	await interact()
	check(level.materials == materials + 3, "the opened reliquary grants materials only once")
	if not output.is_empty():
		await capture(level, cache.global_position, "cache-02-open")

	set_meta(Save.RESTORE_META, level._checkpoint_state())
	change_scene_to_file(scene)
	await scene_changed
	var restored := current_scene as Ruins
	check_open_chest(restored.landscape.reliquaries[0], base, "reliquary restored from checkpoint")


func check_open_chest(chest: Ruins.Landscape.Reliquary, base: float, label: String) -> void:
	var sprite := chest.sprite
	check(chest.opened and chest.visible and sprite.texture == chest.OPEN_TEXTURE
		and sprite.modulate == Color.WHITE and is_equal_approx(sprite.get_rect().end.y, base),
		"%s displays the undimmed open sprite at its original base" % label)


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
