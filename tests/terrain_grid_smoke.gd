extends SceneTree

const TERRAIN_TILESET := preload("res://assets/environment/common/terrain/terrain_tileset.tres")
const Armory := preload("res://scripts/ruin_armory.gd")
const TILE_SIZE := Vector2i(20, 20)
const TILE_CORNERS := [
	Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)
]
const MAPS := [
	"res://scenes/ruins/ruins.tscn",
	"res://scenes/flooded_corridor/flooded_corridor.tscn",
	"res://scenes/buried_court/buried_court.tscn",
]

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for region in range(MAPS.size()):
		var path: String = MAPS[region]
		var packed := load(path) as PackedScene
		var level := packed.instantiate() as Node2D
		var landscape := level.get_node("Landscape") as Node2D
		var terrain := landscape.get_node("Terrain") as TileMapLayer
		var layers := landscape.find_children("*", "TileMapLayer")
		check(layers.size() == 1 and terrain != null, "%s has one terrain layer" % path)
		if terrain != null:
			check(level.transform == Transform2D.IDENTITY and landscape.transform == Transform2D.IDENTITY
				and terrain.transform == Transform2D.IDENTITY, "%s uses the world origin" % path)
			check(terrain.tile_set == TERRAIN_TILESET and terrain.tile_set.tile_size == TILE_SIZE,
				"%s uses the shared 20 × 20 TileSet" % path)
			var cells := terrain.get_used_cells()
			check(terrain.collision_enabled and cells_match_grid(terrain, cells),
				"%s aligns %d tile textures and collision rectangles to the grid" % [path, cells.size()])
			check(chests_match_terrain(terrain, Armory.CHESTS[region]), "%s has grounded treasure chests" % path)
			check(can_paint_pattern(terrain), "%s can stamp a pattern on the same grid" % path)
		level.free()
	await process_frame
	quit(0 if failures == 0 else 1)


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
		if tile.texture_origin != Vector2i.ZERO or tile.get_collision_polygons_count(0) != 1:
			return false
		if tile.get_collision_polygon_points(0, 0) != expected_polygon:
			return false
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(TILE_SIZE)
		if terrain.map_to_local(cell) != center or terrain.local_to_map(center) != cell:
			return false
	return true


func chests_match_terrain(terrain: TileMapLayer, chests: Array) -> bool:
	for chest in chests:
		var position := Vector2(chest[1], chest[2])
		var cell := terrain.local_to_map(position)
		if not is_equal_approx(position.y, terrain.map_to_local(cell).y - TILE_SIZE.y * 0.5):
			return false
		if terrain.get_cell_source_id(cell) < 0 or terrain.get_cell_source_id(cell + Vector2i.UP) >= 0:
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


func check(result: bool, message: String) -> void:
	print("%s %s" % ["PASS" if result else "FAIL", message])
	if not result:
		failures += 1
