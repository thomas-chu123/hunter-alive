extends SceneTree

const Gallery := preload("res://assets/environment/common/roomwalls/roomwalls_tilemap.tscn")

func _initialize() -> void:
	var layer := Gallery.instantiate() as TileMapLayer
	var valid := layer.get_used_cells().size() == 30 and layer.tile_set.get_source_count() == 5
	for category in range(5):
		for column in range(6):
			var pos := Vector2i(column, category)
			var data := layer.get_cell_tile_data(pos)
			var number := category * 6 + column + 1
			if layer.get_cell_source_id(pos) != category or data == null:
				valid = false
			elif not str(data.get_custom_data("wall_name")).begins_with("%02d " % number):
				valid = false
	layer.free()
	print("Roomwalls: 5 categories, 30 numbered cells: ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
