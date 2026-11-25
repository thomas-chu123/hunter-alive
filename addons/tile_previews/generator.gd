@tool
extends EditorResourcePreviewGenerator

const INDEX := preload("res://addons/tile_previews/index.gd").PATHS
var sheet := Image.load_from_file("res://addons/tile_previews/tiles.png")
const CELL := 96
const COLUMNS := 8


func _handles(type: String) -> bool:
	return type == "PackedScene"


func _generate_from_path(path: String, size: Vector2i, _metadata: Dictionary) -> Texture2D:
	var index := INDEX.find(path)
	if index < 0:
		return null
	@warning_ignore("integer_division")
	var cell := Vector2i(index % COLUMNS, index / COLUMNS)
	var thumbnail := sheet.get_region(Rect2i(cell * CELL, Vector2i(CELL, CELL)))
	var side := mini(size.x, size.y)
	thumbnail.resize(side, side, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(thumbnail)


func _generate(resource: Resource, size: Vector2i, metadata: Dictionary) -> Texture2D:
	return _generate_from_path(resource.resource_path, size, metadata)
