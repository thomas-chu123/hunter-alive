extends SceneTree

const Generator := preload("res://addons/tile_previews/generator.gd")
const PROP_TILESETS := [
	preload("res://assets/environment/common/props/background_props_tileset.tres"),
	preload("res://assets/environment/common/props/props_tileset.tres"),
]


func _initialize() -> void:
	var generator := Generator.new()
	for tileset: TileSet in PROP_TILESETS:
		var count := 0
		for i in tileset.get_source_count():
			var source := tileset.get_source(tileset.get_source_id(i)) as TileSetScenesCollectionSource
			if source == null:
				continue
			for j in source.get_scene_tiles_count():
				var path := source.get_scene_tile_scene(source.get_scene_tile_id(j)).resource_path
				if not Generator.INDEX.has(path):
					push_error("Missing baked preview for " + path)
					quit(1)
					return
				count += 1
		print("PASS: %s indexes all %d scene tiles" % [tileset.resource_name, count])
	for path in Generator.INDEX:
		var texture := generator._generate_from_path(path, Vector2i(64, 64), {})
		if not ResourceLoader.exists(path) or not texture or texture.get_size() != Vector2(64, 64) or not texture.get_image().get_used_rect().has_area():
			push_error("Invalid tile preview for " + path)
			quit(1)
			return
	print("PASS: %d scene thumbnails at 64x64" % Generator.INDEX.size())
	quit()
