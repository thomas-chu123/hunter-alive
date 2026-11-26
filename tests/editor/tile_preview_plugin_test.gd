extends SceneTree

const PLUGIN_PATH := "res://addons/tile_previews/plugin.gd"


func _initialize() -> void:
	var source := FileAccess.get_file_as_string(PLUGIN_PATH)
	var thumbnails_only := source.contains("add_preview_generator") \
		and source.contains("remove_preview_generator") \
		and not source.contains("selection_changed") \
		and not source.contains("tile.position")
	print("%s tile preview plugin never moves scene-tile instances when layer selection changes"
		% ("PASS" if thumbnails_only else "FAIL"))
	quit(0 if thumbnails_only else 1)
