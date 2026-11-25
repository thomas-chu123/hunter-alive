extends SceneTree

const Plugin := preload("res://addons/tile_previews/plugin.gd")
const SETS := [
	preload("res://assets/environment/common/traps/trap_tileset.tres"),
	preload("res://assets/environment/common/props/props_tileset.tres"),
	preload("res://assets/environment/common/props/background_props_tileset.tres"),
	preload("res://assets/environment/common/props/obstacle_props_tileset.tres"),
]

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var plugin := Plugin.new()
	for tiles: TileSet in SETS:
		var layer := TileMapLayer.new()
		layer.tile_set = tiles
		root.add_child(layer)
		var cells := {}
		for i in tiles.get_source_count():
			var id := tiles.get_source_id(i)
			var source := tiles.get_source(id) as TileSetScenesCollectionSource
			for j in source.get_scene_tiles_count():
				var tile_id := source.get_scene_tile_id(j)
				var cell := Vector2i(j, i)
				layer.set_cell(cell, id, Vector2i.ZERO, tile_id)
				cells[source.get_scene_tile_scene(tile_id).resource_path] = layer.map_to_local(cell)
		layer.update_internals()
		plugin._watch_layer(layer)
		await process_frame
		var count := 0
		for tile in layer.get_children(true):
			if tile.scene_file_path not in cells:
				continue
			count += 1
			var rect := plugin.placement.bounds(tile)
			var center: Vector2 = tile.transform * rect.get_center()
			check(rect.has_area() and center.is_equal_approx(cells[tile.scene_file_path]),
				"%s center %s, painted %s" % [tile.name, center, cells[tile.scene_file_path]])
		check(count == cells.size(), "%s checked all %d tiles" % [tiles.resource_name, cells.size()])
		var old_cell := Vector2i.ZERO
		var new_cell := Vector2i(-4, 7)
		layer.set_pattern(new_cell, layer.get_pattern([old_cell]))
		layer.erase_cell(old_cell)
		layer.update_internals()
		await process_frame
		await process_frame
		var moved := false
		for tile in layer.get_children(true):
			if not tile is Node2D or not plugin.original_positions.has(tile.get_instance_id()):
				continue
			if plugin.original_positions[tile.get_instance_id()] == layer.map_to_local(new_cell):
				var rect := plugin.placement.bounds(tile)
				moved = (tile.transform * rect.get_center()).is_equal_approx(layer.map_to_local(new_cell))
				cells[tile.scene_file_path] = layer.map_to_local(new_cell)
		check(moved, "%s moved tile centers on its new cell" % tiles.resource_name)
		plugin._watch_layer(null)
		for tile in layer.get_children(true):
			if tile.scene_file_path in cells:
				check(tile.position.is_equal_approx(cells[tile.scene_file_path]), "%s restores gameplay origin" % tile.name)
		layer.free()
	plugin.free()
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", message])
