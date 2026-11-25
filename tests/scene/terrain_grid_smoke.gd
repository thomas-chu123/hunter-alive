extends SceneTree

const TERRAIN_TILESET := preload("res://assets/environment/common/terrain/terrain_tileset.tres")
const TILE_SIZE := Vector2i(20, 20)
const TILE_CORNERS := [
	Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
]
const Campaign := preload("res://scripts/game/campaign.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check(terrain_atlas_casts_shadows(), "all solid and one-way terrain tiles use collision-shaped shadow occluders")
	for path in Campaign.SCENES:
		var packed := load(path) as PackedScene
		var level := packed.instantiate() as Node2D
		var landscape := level.get_node("Landscape") as Node2D
		var terrain := landscape.get_node("Terrain") as TileMapLayer
		var layers := landscape.find_children("*", "TileMapLayer").filter(
			func(layer: TileMapLayer) -> bool: return layer.tile_set == TERRAIN_TILESET)
		check(layers.size() == 1 and terrain != null, "%s has one terrain layer" % path)
		if terrain != null:
			check(level.transform == Transform2D.IDENTITY and landscape.transform == Transform2D.IDENTITY
				and terrain.transform == Transform2D.IDENTITY, "%s uses the world origin" % path)
			check(terrain.tile_set == TERRAIN_TILESET and terrain.tile_set.tile_size == TILE_SIZE,
				"%s uses the shared 20 × 20 TileSet" % path)
			var cells := terrain.get_used_cells()
			check(terrain.collision_enabled and cells_match_grid(terrain, cells),
				"%s aligns %d tile textures and collision rectangles to the grid" % [path, cells.size()])
			check(can_paint_pattern(terrain), "%s can stamp a pattern on the same grid" % path)
		level.free()
	await check_natural_rock()
	await check_terrain_categories()
	await process_frame
	quit(0 if failures == 0 else 1)


func terrain_atlas_casts_shadows() -> bool:
	if TERRAIN_TILESET.get_occlusion_layers_count() != 1 or TERRAIN_TILESET.get_occlusion_layer_light_mask(0) != 1:
		return false
	var atlas := TERRAIN_TILESET.get_source(0) as TileSetAtlasSource
	for tile_index in atlas.get_tiles_count():
		var coords := atlas.get_tile_id(tile_index)
		for alternative_index in atlas.get_alternative_tiles_count(coords):
			var alternative := atlas.get_alternative_tile_id(coords, alternative_index)
			var data := atlas.get_tile_data(coords, alternative)
			if data.get_occluder_polygons_count(0) != 1:
				return false
			var occluder := data.get_occluder_polygon(0, 0)
			if occluder == null or not occluder.closed or occluder.polygon != data.get_collision_polygon_points(0, 0):
				return false
	return true


func cells_match_grid(terrain: TileMapLayer, cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var expected_polygon := PackedVector2Array(TILE_CORNERS)
	for cell in cells:
		var atlas_coords := terrain.get_cell_atlas_coords(cell)
		var atlas := terrain.tile_set.get_source(terrain.get_cell_source_id(cell)) as TileSetAtlasSource
		var tile := terrain.get_cell_tile_data(cell)
		if atlas == null or tile == null or atlas.get_tile_texture_region(atlas_coords).size != TILE_SIZE:
			return false
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(TILE_SIZE)
		if terrain.map_to_local(cell) != center or terrain.local_to_map(center) != cell:
			return false
		if terrain.get_cell_source_id(cell) != 0:
			if tile.texture_origin != Vector2i.ZERO:
				return false
			continue
		if tile.texture_origin != Vector2i.ZERO or tile.get_collision_polygons_count(0) != 1:
			return false
		if tile.get_collision_polygon_points(0, 0) != expected_polygon:
			return false
	return true


func can_paint_pattern(terrain: TileMapLayer) -> bool:
	var pattern := terrain.tile_set.get_pattern(0)
	var origin := terrain.get_used_rect().end + Vector2i(1, 1)
	terrain.set_pattern(origin, pattern)
	for source_cell in pattern.get_used_cells():
		var painted := origin + source_cell
		if terrain.get_cell_atlas_coords(painted) != pattern.get_cell_atlas_coords(source_cell):
			return false
		terrain.erase_cell(painted)
	return true


func check_natural_rock() -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = TERRAIN_TILESET
	root.add_child(layer)
	for index in 12:
		var pattern := TERRAIN_TILESET.get_pattern(10 + index)
		var origin := Vector2i(index * 14, 0)
		layer.set_pattern(origin, pattern)
		var valid := pattern.resource_name.begins_with("%02d " % (index + 1))
		var solids := 0
		for cell in pattern.get_used_cells():
			var data := layer.get_cell_tile_data(origin + cell)
			valid = valid and layer.get_cell_source_id(origin + cell) == 1 and data != null
			if data != null:
				solids += data.get_collision_polygons_count(0)
		check(valid and solids > 0, "%s stamps natural rock terrain with collision" % pattern.resource_name)
	layer.update_internals()
	await physics_frame
	await physics_frame
	var space := layer.get_world_2d().direct_space_state
	for index in 6:
		var x := index * 280
		var left := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x + 30, -40), Vector2(x + 30, 145), 1))
		var right := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x + 90, -40), Vector2(x + 90, 145), 1))
		var valid := not left.is_empty() and not right.is_empty()
		if valid:
			var angle := rad_to_deg(atan2(right.position.y - left.position.y, 60))
			var expected := -30 if index == 1 else 30 if index == 2 else 0
			valid = absf(angle - expected) < (2 if index in [1, 2] else 12)
			valid = valid and left.normal.y < -0.7 and right.normal.y < -0.7
		check(valid, "formation %02d has its intended walkable grade" % (index + 1))

	# Join both slopes at their crest, with level ground at either end.
	layer.clear()
	for pair in [[0, Vector2i(0, 4)], [1, Vector2i(7, 0)], [2, Vector2i(14, 0)], [0, Vector2i(21, 4)]]:
		layer.set_pattern(pair[1], TERRAIN_TILESET.get_pattern(10 + pair[0]))
	layer.set_pattern(Vector2i(28, -4), TERRAIN_TILESET.get_pattern(20))
	for x in range(28, 40):
		layer.set_cell(Vector2i(x, 4), 0, Vector2i.ZERO)
	layer.update_internals()
	var hunter := preload("res://scripts/character/ruin_hunter.gd").new()
	hunter.position = Vector2(50, 75)
	root.add_child(hunter)
	Input.action_press("hunt_right")
	var reached_crest := false
	var descended := false
	for tick in 300:
		await physics_frame
		if hunter.is_on_floor():
			reached_crest = reached_crest or (hunter.position.x > 250 and hunter.position.y < 12)
			descended = descended or (hunter.position.x > 435 and absf(hunter.position.y - 80) < 2)
		if hunter.position.x > 775:
			break
	Input.action_release("hunt_right")
	check(reached_crest and descended, "hunter walks up and down the connected slopes without jumping")
	check(hunter.position.x > 775 and hunter.is_on_floor(), "standing hunter crosses the full arch on level ground")
	hunter.free()
	layer.free()


func check_terrain_categories() -> void:
	var categories := ["自然地形", "洞穴地形", "極端環境地形", "人工建築地形", "奇幻地形"]
	var layer := TileMapLayer.new()
	layer.tile_set = TERRAIN_TILESET
	root.add_child(layer)
	for index in 30:
		var group := index / 6
		var source_id := 2 + group
		var origin := Vector2i(index * 10, 0)
		var pattern := TERRAIN_TILESET.get_pattern(22 + index)
		var source := TERRAIN_TILESET.get_source(source_id) as TileSetAtlasSource
		var slot := Vector2i((index % 3) * 9, ((index % 6) / 3) * 5)
		layer.set_pattern(origin, pattern)
		var valid: bool = source.resource_name == categories[group] and pattern.resource_name.begins_with("%02d " % (index + 1))
		var texture := source.texture.get_image()
		for cell in pattern.get_used_cells():
			var coords := layer.get_cell_atlas_coords(origin + cell)
			var tile := layer.get_cell_tile_data(origin + cell)
			valid = valid and tile != null and layer.get_cell_source_id(origin + cell) == source_id and coords == slot + cell
			if tile == null:
				continue
			var region := source.get_tile_texture_region(coords)
			valid = valid and not texture.get_region(region).is_invisible()
			valid = valid and tile.get_occluder_polygons_count(0) == tile.get_collision_polygons_count(0)
		check(valid and not pattern.get_used_cells().is_empty(), "%s / %s stamps its own artwork" % [categories[group], pattern.resource_name])
	layer.update_internals()
	await physics_frame
	await physics_frame
	var space := layer.get_world_2d().direct_space_state
	for index in 30:
		var supported := true
		for offset in [45, 81, 115]:
			var x: int = index * 200 + offset
			var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, -20), Vector2(x, 80), 1))
			supported = supported and not hit.is_empty() and hit.normal.y < -0.7
		check(supported, "terrain %02d supports standing across its upper surface" % (index + 1))
	layer.free()


func check(result: bool, message: String) -> void:
	print("%s %s" % ["PASS" if result else "FAIL", message])
	if not result:
		failures += 1
