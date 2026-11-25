extends SceneTree

const Generator := preload("res://addons/tile_previews/generator.gd")


func _initialize() -> void:
	var generator := Generator.new()
	for path in Generator.INDEX:
		var texture := generator._generate_from_path(path, Vector2i(64, 64), {})
		if not ResourceLoader.exists(path) or not texture or texture.get_size() != Vector2(64, 64) or not texture.get_image().get_used_rect().has_area():
			push_error("Invalid tile preview for " + path)
			quit(1)
			return
	print("PASS: %d scene thumbnails at 64x64" % Generator.INDEX.size())
	quit()
