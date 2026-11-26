extends SceneTree

const Props := preload("res://assets/environment/common/props/props_tileset.tres")


func _initialize() -> void:
	var doors := Props.get_source(6) as TileSetScenesCollectionSource
	var stops := Props.get_source(7) as TileSetScenesCollectionSource
	var errors := 0
	for tile_id in range(1, 9):
		var door := doors.get_scene_tile_scene(tile_id).instantiate()
		var stop := stops.get_scene_tile_scene(tile_id).instantiate()
		var frame := door.get_node("Frame") as Sprite2D
		var post := stop.get_node("Post") as Sprite2D
		var frame_art := frame.texture as AtlasTexture
		var post_art := post.texture as AtlasTexture
		var frame_bounds := frame.transform * frame.get_rect()
		var post_bounds := post.transform * post.get_rect()
		var first_post := Rect2(post_bounds.position - Vector2(0, 5 * Props.tile_size.y), post_bounds.size)
		var joins := first_post.position.x == frame_bounds.position.x and first_post.size.x == frame_bounds.size.x \
			and first_post.end.y == frame_bounds.position.y + 2 and first_post.size.y == Props.tile_size.y
		var matches := frame_art.atlas == post_art.atlas and frame_art.region.encloses(post_art.region) \
			and post.flip_h == frame.flip_h
		var passed := joins and matches
		errors += 0 if passed else 1
		print("%s %s matches its door frame and stacks at one tile per segment"
			% ["PASS" if passed else "FAIL", stop.name])
		door.free()
		stop.free()
	quit(1 if errors else 0)
