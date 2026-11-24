extends Node2D

const FLOOR_Y := 540.0
const Reliquary := preload("res://assets/environment/common/props/reliquary.gd")
const EquipmentChest := preload("res://assets/environment/common/props/equipment_chest.gd")
const BRAZIER_TILE_ID := 12
const BRAZIER_SPACING := 500.0
const BRAZIER_MIN_GAP := 280.0

@export var shrine_flame_height := 29.0

var time := 0.0
var portal_open := false
var cache_open := false:
	set(value):
		cache_open = value
		for cache in reliquaries:
			cache.set_opened(value)
var effects: Node2D

var campfires: Array[Node2D] = []
var portals: Array[Node2D] = []
var reliquaries: Array[Reliquary] = []
var light_gates: Array[StaticBody2D] = []
var equipment_chests: Array[EquipmentChest] = []


func _ready() -> void:
	effects = Node2D.new()
	effects.draw.connect(_draw_effects)
	add_child(effects)


func initialize_props(level_width: float) -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()
	place_braziers(level_width, random)
	for child in get_children():
		if child is TileMapLayer and child.is_in_group("prop_tiles"):
			_collect_props(child)
	campfires.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.x < b.global_position.x or (
			a.global_position.x == b.global_position.x and a.global_position.y < b.global_position.y))


func place_braziers(level_width: float, random: RandomNumberGenerator) -> void:
	var terrain: TileMapLayer = $Terrain
	var props: TileMapLayer = $Props
	var occupied: Array[Vector2] = []
	for layer: TileMapLayer in [$Props, $ObstacleProps, $Traps, $Monster]:
		for cell in layer.get_used_cells():
			occupied.append(to_local(layer.to_global(layer.map_to_local(cell))))

	var band_count := maxi(1, roundi(level_width / BRAZIER_SPACING))
	var band_width := level_width / band_count
	var bands: Array[Array] = []
	for band in band_count:
		bands.append([])
	for floor_cell in terrain.get_used_cells():
		var surface := terrain.map_to_local(floor_cell) - Vector2(0, terrain.tile_set.tile_size.y * 0.5)
		var foot := to_local(terrain.to_global(surface))
		if foot.x < 120.0 or foot.x > level_width - 120.0 or not _has_brazier_space(terrain, floor_cell):
			continue
		var clearance := Rect2(foot - Vector2(100, 72), Vector2(200, 100))
		if occupied.any(func(at: Vector2) -> bool: return clearance.has_point(at)):
			continue
		var band := floori(foot.x / band_width)
		bands[band].append(foot)

	var last_x := -INF
	for band in bands:
		var candidates := band.filter(func(at: Vector2) -> bool: return at.x >= last_x + BRAZIER_MIN_GAP)
		if candidates.is_empty():
			continue
		var foot: Vector2 = candidates[random.randi_range(0, candidates.size() - 1)]
		var cell := props.local_to_map(props.to_local(to_global(foot)))
		props.set_cell(cell, 0, Vector2i.ZERO, BRAZIER_TILE_ID)
		last_x = foot.x


func _has_brazier_space(terrain: TileMapLayer, floor_cell: Vector2i) -> bool:
	for x in range(-1, 2):
		var support := floor_cell + Vector2i(x, 0)
		if not _has_terrain_collision(terrain, support):
			return false
		for y in range(1, 4):
			if _has_terrain_collision(terrain, support + Vector2i(0, -y)):
				return false
	return true


func _has_terrain_collision(terrain: TileMapLayer, cell: Vector2i) -> bool:
	var tile := terrain.get_cell_tile_data(cell)
	return tile != null and tile.get_collision_polygons_count(0) > 0


func _collect_props(layer: TileMapLayer) -> void:
	# Scene tiles normally instantiate at the end of the frame. The level needs its spawn point in _ready().
	layer.update_internals()
	for prop in layer.get_children(true):
		if prop.is_in_group("campfire"):
			campfires.append(prop)
		elif prop.is_in_group("portal"):
			portals.append(prop)
		elif prop.is_in_group("reliquary"):
			reliquaries.append(prop)
		elif prop.is_in_group("light_gate"):
			light_gates.append(prop)
		elif prop is EquipmentChest:
			equipment_chests.append(prop)


func _process(delta: float) -> void:
	time += delta
	effects.queue_redraw()


func _draw_effects() -> void:
	for portal in portals:
		_draw_portal(to_local(portal.global_position))
	for campfire in campfires:
		_draw_shrine(to_local(campfire.global_position))
	if not cache_open:
		for cache in reliquaries:
			effects.draw_circle(to_local(cache.global_position) + Vector2(0, -22), 6 + sin(time * 3.0),
				Color(1.0, 0.75, 0.36, 0.22))
	_draw_motes()


func _draw_portal(ground: Vector2) -> void:
	var p := ground + Vector2(0, -60)
	var glow := Color("#98ead0") if portal_open else Color("#bda370")
	if portal_open:
		for i in range(4, 0, -1):
			effects.draw_circle(p, i * 13.0, Color(glow, 0.06))
	for i in range(4):
		var y := p.y + sin(time * 1.6 + i) * 31
		effects.draw_circle(Vector2(p.x + cos(time + i * 1.4) * 19, y), 2.5, glow)


func _draw_shrine(ground: Vector2) -> void:
	var flame := ground - Vector2(0, shrine_flame_height)
	for i in range(4, 0, -1):
		effects.draw_circle(flame, i * 13.0, Color(0.92, 0.61, 0.25, 0.045))
	for i in range(5):
		var lifetime := fposmod(time * 0.88 + i * 0.2, 1.0)
		var ember := flame + Vector2(sin(time * 2.3 + i) * 8, -22.0 - lifetime * 27.0)
		effects.draw_circle(ember, 1.5, Color(1.0, 0.73, 0.30, 1.0 - lifetime))


func _draw_motes() -> void:
	for i in range(63):
		var x := fposmod(float(i * 137) + time * (9 + i % 12), 3350.0)
		var y := 175.0 + sin(i * 4.0 + time * 0.48) * 100.0 + (i % 7) * 30.0
		var opacity := 0.12 + (sin(time * 1.7 + i) + 1.0) * 0.17
		effects.draw_circle(Vector2(x, y), 1.0 + i % 3 * 0.4, Color(0.85, 0.92, 0.68, opacity))
