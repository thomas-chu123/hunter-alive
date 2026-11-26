extends TileMapLayer

const TALK_RADIUS := 48.0


func nearest_to(world_position: Vector2, radius: float = TALK_RADIUS) -> TileData:
	if tile_set == null:
		return null
	var local_position := to_local(world_position)
	var center := local_to_map(local_position)
	var search_cells := Vector2i((Vector2.ONE * radius / Vector2(tile_set.tile_size)).ceil())
	var nearest: TileData
	var best_distance := radius * radius
	for y in range(center.y - search_cells.y, center.y + search_cells.y + 1):
		for x in range(center.x - search_cells.x, center.x + search_cells.x + 1):
			var cell := Vector2i(x, y)
			var distance := local_position.distance_squared_to(map_to_local(cell))
			if distance >= best_distance:
				continue
			var tile := get_cell_tile_data(cell)
			if tile != null and tile.get_custom_data("dialogue_cue") != "":
				nearest = tile
				best_distance = distance
	return nearest
