extends CanvasLayer

const DARKNESS := Color("#06080c")
const HUNTER_VIEW_HEIGHT := 24.0

var _hunter: Node2D
var _floor_surfaces := PackedFloat32Array()
var _slab_height: float
var _above := ColorRect.new()
var _below := ColorRect.new()


func _init(terrain: TileMapLayer, hunter: Node2D, level_width: float, ground_y: float) -> void:
	layer = 1
	_hunter = hunter
	var tile_size := terrain.tile_set.tile_size
	_slab_height = tile_size.y
	var tiles_per_row := {}
	for cell in terrain.get_used_cells():
		var tile := terrain.get_cell_tile_data(cell)
		if tile != null and tile.get_collision_polygons_count(0) > 0 and tile.is_collision_polygon_one_way(0, 0):
			tiles_per_row[cell.y] = tiles_per_row.get(cell.y, 0) + 1

	# The broad one-way rows are full floors. Short ledges between them are steps.
	for row: int in tiles_per_row:
		if tiles_per_row[row] * tile_size.x > level_width * 0.5:
			var center := terrain.map_to_local(Vector2i(0, row))
			_floor_surfaces.append(terrain.to_global(center - Vector2(0, _slab_height / 2.0)).y)
	_floor_surfaces.append(ground_y)
	_floor_surfaces.sort()


func _ready() -> void:
	for mask in [_above, _below]:
		mask.color = DARKNESS
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mask)
	process_priority = 10
	_update_masks()


func _process(_delta: float) -> void:
	_update_masks()


func visible_band(world_y: float) -> Vector2:
	var ceiling := -INF
	for floor_y in _floor_surfaces:
		if world_y < floor_y:
			return Vector2(ceiling, floor_y + _slab_height)
		ceiling = floor_y
	return Vector2(ceiling, INF)


func _update_masks() -> void:
	var viewport := get_viewport()
	var view_size := viewport.get_visible_rect().size
	var world_to_screen := viewport.get_canvas_transform()
	var band := visible_band(_hunter.global_position.y - HUNTER_VIEW_HEIGHT)
	var top := _screen_y(band.x, world_to_screen, view_size.y)
	var bottom := _screen_y(band.y, world_to_screen, view_size.y)
	_above.size = Vector2(view_size.x, top)
	_below.position.y = bottom
	_below.size = Vector2(view_size.x, view_size.y - bottom)


func _screen_y(world_y: float, canvas_transform: Transform2D, view_height: float) -> float:
	if is_inf(world_y):
		return 0.0 if world_y < 0.0 else view_height
	return clampf((canvas_transform * Vector2(0, world_y)).y, 0.0, view_height)
