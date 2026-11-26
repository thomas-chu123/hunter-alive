extends SceneTree

const SETS := [
	preload("res://assets/environment/common/traps/trap_tileset.tres"),
	preload("res://assets/environment/common/props/props_tileset.tres"),
	preload("res://assets/environment/common/props/background_props_tileset.tres"),
	preload("res://assets/environment/common/props/obstacle_props_tileset.tres"),
	preload("res://assets/monster/monster_tileset.tres"),
]

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for tiles: TileSet in SETS:
		var layer := TileMapLayer.new()
		layer.tile_set = tiles
		root.add_child(layer)
		var expected := {}
		for i in tiles.get_source_count():
			var id := tiles.get_source_id(i)
			var source := tiles.get_source(id) as TileSetScenesCollectionSource
			for j in source.get_scene_tiles_count():
				var tile_id := source.get_scene_tile_id(j)
				var cell := Vector2i(j, i)
				layer.set_cell(cell, id, Vector2i.ZERO, tile_id)
				expected[layer.map_to_local(cell)] = source.get_scene_tile_scene(tile_id).resource_path
		layer.update_internals()
		check(instances_match(layer, expected), "%s: %d scene tiles preserve their painted origins" % [tiles.resource_name, expected.size()])

		var old_cell := Vector2i.ZERO
		var new_cell := Vector2i(-4, 7)
		layer.set_pattern(new_cell, layer.get_pattern([old_cell]))
		layer.erase_cell(old_cell)
		expected[layer.map_to_local(new_cell)] = expected[layer.map_to_local(old_cell)]
		expected.erase(layer.map_to_local(old_cell))
		layer.update_internals()
		await process_frame
		check(instances_match(layer, expected), "%s: moving a tile updates only its painted origin" % tiles.resource_name)
		layer.free()
	quit(1 if failures else 0)


func instances_match(layer: TileMapLayer, expected: Dictionary) -> bool:
	var actual := {}
	for tile in layer.get_children(true):
		if tile is Node2D and not tile.scene_file_path.is_empty():
			if actual.has(tile.position):
				return false
			actual[tile.position] = tile.scene_file_path
	return actual == expected


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", message])
