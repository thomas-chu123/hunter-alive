extends SceneTree

const CELL := 96
const COLUMNS := 8
const OUT := "res://addons/tile_previews/"


func _initialize() -> void:
	var paths: Array[String] = []
	collect_tiles("res://assets", paths)
	paths.sort()
	var sheet := Image.create_empty(COLUMNS * CELL, ceili(float(paths.size()) / COLUMNS) * CELL, false, Image.FORMAT_RGBA8)
	for i in paths.size():
		var scene: Node = load(paths[i]).instantiate()
		var art: Array[Dictionary] = []
		collect_art(scene, Transform2D.IDENTITY, art)
		if art.is_empty():
			# Invisible barrier tiles use their collision footprint in the palette.
			for collision in scene.find_children("*", "CollisionShape2D", true, false):
				if collision.shape is RectangleShape2D:
					var rect: Rect2 = collision.shape.get_rect()
					art.append({"rect": rect, "transform": collision.transform, "color": Color.SKY_BLUE})
		var tile := paint(art)
		scene.free()
		if tile.get_used_rect().has_area() == false:
			push_error("Empty thumbnail for " + paths[i])
			quit(1)
			return
		@warning_ignore("integer_division")
		sheet.blit_rect(tile, Rect2i(0, 0, CELL, CELL), Vector2i(i % COLUMNS, i / COLUMNS) * CELL)
	if sheet.save_png(OUT + "tiles.png") != OK:
		quit(1)
		return
	var index := FileAccess.open(OUT + "index.gd", FileAccess.WRITE)
	index.store_line("const PATHS := [")
	for path in paths:
		index.store_line('\t"' + path + '",')
	index.store_line("]")
	print("Baked %d scene tile previews" % paths.size())
	quit()


func collect_tiles(folder: String, paths: Array[String]) -> void:
	for name in DirAccess.get_files_at(folder):
		if not name.ends_with("tileset.tres"):
			continue
		var tiles: TileSet = load(folder.path_join(name))
		for i in tiles.get_source_count():
			var source := tiles.get_source(tiles.get_source_id(i)) as TileSetScenesCollectionSource
			if source:
				for j in source.get_scene_tiles_count():
					var path := source.get_scene_tile_scene(source.get_scene_tile_id(j)).resource_path
					if path not in paths:
						paths.append(path)
	for dir in DirAccess.get_directories_at(folder):
		collect_tiles(folder.path_join(dir), paths)


func collect_art(node: Node, transform: Transform2D, art: Array[Dictionary]) -> void:
	if node is Node2D:
		if not node.visible:
			return
		transform = transform * node.transform
	if node is Sprite2D and node.texture:
		var img: Image = node.texture.get_image()
		if node.region_enabled:
			img = img.get_region(Rect2i(node.region_rect))
		var frame_size := img.get_size() / Vector2i(node.hframes, node.vframes)
		img = img.get_region(Rect2i(node.frame_coords * frame_size, frame_size))
		if node.flip_h:
			img.flip_x()
		if node.flip_v:
			img.flip_y()
		art.append({"rect": node.get_rect(), "transform": transform, "image": img})
	elif node is Polygon2D and not node.polygon.is_empty():
		var rect := Rect2(node.polygon[0], Vector2.ZERO)
		for point in node.polygon:
			rect = rect.expand(point)
		art.append({"rect": rect, "transform": transform, "polygon": node.polygon, "color": node.color})
	for child in node.get_children():
		collect_art(child, transform, art)


func paint(art: Array[Dictionary]) -> Image:
	var tile := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	if art.is_empty():
		return tile
	var bounds: Rect2 = art[0].transform * art[0].rect
	for part in art:
		bounds = bounds.merge(part.transform * part.rect)
	var scale_factor := (CELL - 6) / maxf(bounds.size.x, bounds.size.y)
	for part in art:
		var inverse: Transform2D = part.transform.affine_inverse()
		var rect: Rect2 = part.rect
		for y in CELL:
			for x in CELL:
				var world := bounds.get_center() + (Vector2(x + 0.5, y + 0.5) - Vector2.ONE * CELL / 2) / scale_factor
				var local := inverse * world
				if not rect.has_point(local):
					continue
				var color: Color
				if part.has("image"):
					var img: Image = part.image
					color = img.get_pixelv(Vector2i((local - rect.position) / rect.size * Vector2(img.get_size())))
				else:
					if part.has("polygon") and not Geometry2D.is_point_in_polygon(local, part.polygon):
						continue
					color = part.color
				tile.set_pixel(x, y, tile.get_pixel(x, y).blend(color))
	return tile
