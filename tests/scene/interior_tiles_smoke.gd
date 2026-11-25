extends SceneTree

const Terrain := preload("res://assets/environment/common/terrain/terrain_tileset.tres")
const Surfaces := preload("res://assets/environment/common/terrain/interior_surfaces_tileset.tres")
const Fixtures := preload("res://assets/environment/common/terrain/interior_fixtures_tileset.tres")
const Props := preload("res://assets/environment/common/props/props_tileset.tres")
const Hunter := preload("res://scripts/character/ruin_hunter.gd")
const Campaign := preload("res://scripts/game/campaign.gd")
const Landscape := preload("res://scripts/scene/ruin_landscape.gd")
const FLOOR_Y := 280
const PATTERNS := [
	"Interior stone wall", "Interior plank wall", "Interior brick wall",
	"Interior slate floor", "Interior timber floor", "Timber ceiling", "Carpet runner",
	"Iron-banded timber brace", "Carved stone trim", "Stone doorway frame", "Closed timber door",
	"Mullioned window", "Wooden chair", "Hanging chandelier", "Wall lantern",
	"Dungeon restraint chair", "Ceremonial blade rack", "Hanging tapestry",
]

# RoomFixtures source IDs in the numbered furniture catalog.
const FURNITURE_SOURCES := [
	4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6,
	7, 6, 4, 8, 8, 8, 7, 8, 8, 4, 9, 9, 10, 10, 10,
]

var failures := 0
var proof := OS.get_environment("HUNTER_INTERIOR_PROOF")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check_atlases()
	check_stage_layers()
	var room := Node2D.new()
	root.add_child(room)
	var ambient := CanvasModulate.new()
	ambient.color = Color("#535750")
	room.add_child(ambient)
	var background := add_layer(room, Surfaces)
	for y in range(2, 14, 3):
		for x in range(0, 30, 3):
			paint(background, Vector2i(x, y), x / 12)
	for x in range(0, 30, 3):
		paint(background, Vector2i(x, 2), 5)
		paint(background, Vector2i(x, 14), 3 if x < 15 else 4)
	for x in range(9, 15, 3):
		paint(background, Vector2i(x, 14), 6)
	paint(background, Vector2i(0, 5), 7)
	paint(background, Vector2i(27, 5), 8)

	var fixtures := add_layer(room, Fixtures)
	var fixture_cells := [
		Vector2i(4, 13), Vector2i(8, 13), Vector2i(11, 8), Vector2i(11, 13), Vector2i(14, 3),
		Vector2i(17, 5), Vector2i(16, 13), Vector2i(28, 9), Vector2i(25, 3),
	]
	for index in fixture_cells.size():
		paint(fixtures, fixture_cells[index], index)
	await check_interior_lights(background, fixtures, fixture_cells[5])
	if "--lighting-only" in OS.get_cmdline_user_args():
		room.free()
		quit(1 if failures else 0)
		return

	var solid := add_layer(room, Terrain)
	for x in range(30):
		solid.set_cell(Vector2i(x, 14), 0, Vector2i.ZERO)
	for x in range(23, 30):
		solid.set_cell(Vector2i(x, 10), 0, Vector2i.ZERO)
	solid.modulate = Color(1.0, 1.0, 1.0, 0.8)
	var landscape := Landscape.new()
	check(landscape._has_brazier_space(solid, Vector2i(7, 14)), "solid tiles support a brazier")
	check(not landscape._has_brazier_space(background, Vector2i(7, 14)), "interior floor art cannot support a brazier")
	landscape.free()

	var traversal := add_layer(room, Props)
	traversal.position = Vector2(-10, -10)
	var positions := [Vector2i(20, 14), Vector2i(2, 14), Vector2i(13, 14), Vector2i(18, 14)]
	for index in positions.size():
		traversal.set_cell(positions[index], 3, Vector2i.ZERO, index + 1)
	traversal.update_internals()
	check(traversal.get_child_count() == 4, "Props instantiates all four traversal scene tiles")
	var hunter := Hunter.new()
	hunter.position = Vector2(40, FLOOR_Y)
	room.add_child(hunter)
	if not proof.is_empty():
		root.size = Vector2i(1200, 640)
		var camera := Camera2D.new()
		camera.position = Vector2(300, 160)
		camera.zoom = Vector2(1.9, 1.9)
		room.add_child(camera)
		await capture("01-interior")

	for index in range(1, positions.size()):
		var foot := traversal.to_global(traversal.map_to_local(positions[index]))
		await check_climb(hunter, foot, ["", "rope", "wooden ladder", "iron ladder"][index])
	await check_stairs(hunter)
	await check_stacked_rope(hunter, traversal)
	room.free()
	quit(1 if failures else 0)


func check_stage_layers() -> void:
	for region in Campaign.IDS.size():
		for stage in range(1, Campaign.BOSS_STAGE + 1):
			var path := Campaign.scene_path({"region": region, "stage": stage})
			var level := (load(path) as PackedScene).instantiate()
			var walls: TileMapLayer = level.get_node("Landscape/RoomWalls")
			var fixtures: TileMapLayer = level.get_node("Landscape/RoomFixtures")
			var terrain: TileMapLayer = level.get_node("Landscape/Terrain")
			var valid := terrain.tile_set == Terrain and walls.tile_set == Surfaces \
				and fixtures.tile_set == Fixtures and walls.z_index < fixtures.z_index
			for layer: TileMapLayer in [terrain, walls, fixtures]:
				for cell in layer.get_used_cells():
					valid = valid and layer.tile_set.has_source(layer.get_cell_source_id(cell))
			check(valid, "%s uses the assigned palettes and valid cell sources" % path)
			if region == Campaign.Region.TEMPLE and stage == 1:
				var anchor := walls.get_used_rect().end + Vector2i.ONE
				walls.set_pattern(anchor, Surfaces.get_pattern(0))
				fixtures.set_pattern(anchor, Fixtures.get_pattern(0))
				check(walls.get_cell_source_id(anchor) == 1 and fixtures.get_cell_source_id(anchor) == 2
					and fixtures.get_cell_atlas_coords(anchor) == Vector2i.ZERO,
					"a stone doorway can share a wall cell on separate layers")
			level.free()


func check_atlases() -> void:
	check(Terrain.tile_size == Vector2i(20, 20) and Props.tile_size == Terrain.tile_size,
		"Terrain and Props use the shared 20 px grid")
	check(Terrain.get_source_count() == 1 and Terrain.has_source(0)
		and Surfaces.get_source_count() == 6 and Surfaces.has_source(1)
		and Fixtures.get_source_count() == 9 and Fixtures.has_source(2) and Fixtures.has_source(3),
		"terrain, walls and fixtures expose only their assigned sources")
	for source_id in [1, 2]:
		var tileset := Surfaces if source_id == 1 else Fixtures
		var atlas := tileset.get_source(source_id) as TileSetAtlasSource
		var expected := 57 if source_id == 1 else 9
		check(atlas != null and atlas.get_tiles_count() == expected, "interior source %d contains %d tiles" % [source_id, expected])
		if atlas == null:
			continue
		var image := atlas.texture.get_image()
		var decorative := true
		for index in atlas.get_tiles_count():
			var coords := atlas.get_tile_id(index)
			var tile := atlas.get_tile_data(coords, 0)
			var region := image.get_region(atlas.get_tile_texture_region(coords))
			decorative = decorative and tile.get_collision_polygons_count(0) == 0
			decorative = decorative and tile.get_occluder_polygons_count(0) == 0
			decorative = decorative and not region.is_invisible()
		check(decorative, "interior source %d has visible art with no collision or shadow polygons" % source_id)
	var palette := TileMapLayer.new()
	for index in PATTERNS.size():
		palette.tile_set = Surfaces if index < 9 else Fixtures
		var pattern := palette.tile_set.get_pattern(index % 9)
		var origin := Vector2i(5, 5)
		palette.clear()
		palette.set_pattern(origin, pattern)
		var valid: bool = pattern.resource_name == PATTERNS[index] and not palette.get_used_cells().is_empty()
		for cell in palette.get_used_cells():
			if index == 13 or index == 14:
				valid = valid and palette.get_cell_source_id(cell) == 3 \
					and palette.get_cell_alternative_tile(cell) == (2 if index == 13 else 1)
			else:
				valid = valid and palette.get_cell_source_id(cell) == (1 if index < 9 else 2) \
					and palette.get_cell_tile_data(cell) != null
		check(valid, "%s stamps valid tiles on its assigned layer" % PATTERNS[index])
	palette.tile_set = Surfaces
	for index in range(30):
		var pattern := Surfaces.get_pattern(9 + index)
		palette.clear()
		palette.set_pattern(Vector2i.ZERO, pattern)
		var valid: bool = pattern.resource_name.begins_with("%02d " % (index + 1)) and palette.get_used_cells().size() == 9
		for cell in palette.get_used_cells():
			var atlas_origin := Vector2i(index % 3, (index % 6) / 3) * 3
			valid = valid and palette.get_cell_source_id(cell) == 2 + index / 6 \
				and palette.get_cell_atlas_coords(cell) == atlas_origin + cell \
				and palette.get_cell_tile_data(cell) != null
		check(valid, "%s stamps nine wall cells" % pattern.resource_name)
	check_furniture(palette)
	palette.free()


func check_furniture(palette: TileMapLayer) -> void:
	palette.tile_set = Fixtures
	var seen := {}
	for index in FURNITURE_SOURCES.size():
		var pattern := Fixtures.get_pattern(9 + index)
		if pattern == null:
			check(false, "missing furniture pattern %02d" % (index + 1))
			continue
		palette.clear()
		palette.set_pattern(Vector2i.ZERO, pattern)
		var source_id := palette.get_cell_source_id(Vector2i.ZERO)
		var coords := palette.get_cell_atlas_coords(Vector2i.ZERO)
		var key := Vector3i(coords.x, coords.y, source_id)
		var tile := palette.get_cell_tile_data(Vector2i.ZERO)
		var valid: bool = pattern.resource_name.begins_with("%02d " % (index + 1)) \
			and palette.get_used_cells().size() == 1 and source_id == FURNITURE_SOURCES[index] \
			and tile != null and not seen.has(key)
		if valid:
			var atlas := Fixtures.get_source(source_id) as TileSetAtlasSource
			var rect := atlas.get_tile_texture_region(coords)
			var art := atlas.texture.get_image().get_region(rect)
			var used := art.get_used_rect()
			valid = used.has_area() and used != Rect2i(Vector2i.ZERO, rect.size) \
				and tile.get_collision_polygons_count(0) == 0
			var offset := (rect.size.y - Fixtures.tile_size.y) / 2
			valid = valid and tile.texture_origin.y == (offset if index == 23 else -offset)
		seen[key] = true
		check(valid, "%s stamps one distinct furniture tile in its category" % pattern.resource_name)


func check_interior_lights(background: TileMapLayer, fixtures: TileMapLayer, lantern_cell: Vector2i) -> void:
	fixtures.update_internals()
	var lantern := fixtures.get_node_or_null("WallLantern") as Node2D
	var chandelier := fixtures.get_node_or_null("Chandelier") as Node2D
	check(lantern != null and chandelier != null, "the wall lantern and chandelier patterns instantiate scene tiles")
	if lantern == null or chandelier == null:
		return
	check(lantern.position == fixtures.map_to_local(lantern_cell)
		and background.get_cell_source_id(lantern_cell) == 1, "the live lantern overlays the wall at the same grid cell")
	for fixture in [lantern, chandelier]:
		var light := fixture.get_node("Light") as PointLight2D
		check(light.enabled and light.shadow_enabled and light.color.r > light.color.b
			and light.texture.get_width() * light.texture_scale >= 340.0,
			"%s casts warm light across the room with terrain shadows" % fixture.name)
	var flame := lantern.get_node("Flame") as AnimatedSprite2D
	var lamp := lantern.get_node("Light") as PointLight2D
	var start_frame := flame.frame
	var start_energy := lamp.energy
	await frames(12)
	check(flame.is_playing() and flame.frame != start_frame and not is_equal_approx(start_energy, lamp.energy),
		"the lantern animates its flame and flickers its light")
	check(chandelier.get_children().filter(func(node: Node) -> bool:
		return node is AnimatedSprite2D and node.is_playing()).size() == 5,
		"all five chandelier candles animate")
	var copy_cell := lantern_cell + Vector2i.RIGHT * 3
	fixtures.set_cell(copy_cell, fixtures.get_cell_source_id(lantern_cell),
		fixtures.get_cell_atlas_coords(lantern_cell), fixtures.get_cell_alternative_tile(lantern_cell))
	fixtures.update_internals()
	check(fixtures.get_child_count() == 3, "copying the lantern cell adds another flame and light")
	fixtures.erase_cell(copy_cell)
	fixtures.update_internals()
	await process_frame
	check(fixtures.get_child_count() == 2, "erasing the copied cell removes its entire lamp")


func check_climb(hunter: Hunter, foot: Vector2, label: String) -> void:
	hunter.respawn(foot)
	hunter.invincible_left = 0
	await frames(3)
	Input.action_press("hunt_climb_up")
	await frames(33)
	if not proof.is_empty():
		await capture("02-" + label.replace(" ", "-") + "-ascending")
	await frames(67)
	check(hunter.prop_climbing and absf(hunter.position.y - (foot.y - 128)) < 2.0,
		"%s climbs and stops at the upper end, y=%.1f" % [label, hunter.position.y])
	Input.action_release("hunt_climb_up")
	if not proof.is_empty():
		await capture("03-" + label.replace(" ", "-") + "-top")
	var top := hunter.position.y
	await frames(12)
	check(hunter.prop_climbing and is_equal_approx(hunter.position.y, top), "%s holds position at neutral input" % label)
	Input.action_press("hunt_crouch")
	await frames(30)
	check(hunter.prop_climbing and hunter.position.y > top + 40, "%s climbs back down, y=%.1f" % [label, hunter.position.y])
	if not proof.is_empty():
		await capture("04-" + label.replace(" ", "-") + "-descending")
	Input.action_release("hunt_crouch")
	Input.action_press("hunt_climb_up")
	await frames(3)
	Input.action_press("hunt_jump")
	await frames(8)
	check(not hunter.prop_climbing and hunter.velocity.y < 0.0, "%s releases on jump even while Up stays held" % label)
	Input.action_release("hunt_jump")
	Input.action_release("hunt_climb_up")


func check_stairs(hunter: Hunter) -> void:
	hunter.respawn(Vector2(305, FLOOR_Y))
	hunter.invincible_left = 0
	await frames(3)
	Input.action_press("hunt_right")
	await frames(65)
	check(hunter.is_on_floor() and hunter.position.x > 460 and absf(hunter.position.y - 200) < 1.0,
		"stairs reach the upper platform without jumping at %s" % hunter.position)
	Input.action_release("hunt_right")
	if not proof.is_empty():
		await capture("05-stairs-upper-landing")
	Input.action_press("hunt_left")
	await frames(40)
	check(hunter.position.x < 420 and hunter.position.x > 350 and hunter.position.y > 207 and hunter.position.y < 258,
		"stairs guide the hunter down the slope at %s" % hunter.position)
	if not proof.is_empty():
		await capture("06-stairs-on-slope")
	await frames(32)
	check(hunter.is_on_floor() and hunter.position.x < 345 and absf(hunter.position.y - FLOOR_Y) < 1.0,
		"stairs return to the lower floor without jumping at %s" % hunter.position)
	Input.action_release("hunt_left")
	if not proof.is_empty():
		await capture("07-stairs-lower-floor")


func check_stacked_rope(hunter: Hunter, traversal: TileMapLayer) -> void:
	var upper_cell := Vector2i(2, 8)
	traversal.set_cell(upper_cell, 3, Vector2i.ZERO, 2)
	traversal.update_internals()
	hunter.respawn(Vector2(40, FLOOR_Y))
	await frames(3)
	Input.action_press("hunt_climb_up")
	await frames(150)
	Input.action_release("hunt_climb_up")
	check(hunter.prop_climbing and absf(hunter.position.y - 32.0) < 2.0,
		"two rope tiles connect on ascent, y=%.1f" % hunter.position.y)
	Input.action_press("hunt_crouch")
	await frames(150)
	Input.action_release("hunt_crouch")
	check(hunter.prop_climbing and absf(hunter.position.y - FLOOR_Y) < 2.0,
		"two rope tiles connect on descent, y=%.1f" % hunter.position.y)
	Input.action_press("hunt_right")
	await frames(10)
	Input.action_release("hunt_right")
	check(not hunter.prop_climbing and hunter.position.x > 55.0, "horizontal input dismounts the rope")


func paint(layer: TileMapLayer, cell: Vector2i, pattern_index: int) -> void:
	layer.set_pattern(cell, layer.tile_set.get_pattern(pattern_index))


func add_layer(room: Node2D, tileset: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room.add_child(layer)
	return layer


func frames(count: int) -> void:
	for index in count:
		await physics_frame


func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var output := proof.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(output) == OK, "captured %s" % output)


func check(result: bool, message: String) -> void:
	print("%s %s" % ["PASS" if result else "FAIL", message])
	if not result:
		failures += 1
