extends SceneTree

const Props := preload("res://assets/environment/common/props/props_tileset.tres")
const DoorSight := preload("res://assets/environment/common/props/doors/door_sight.gd")


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
		var sight := stop.get_node("Sight") as DoorSight
		var occluder := stop.get_node("Occluder") as LightOccluder2D
		var door_shadow := door.get_node("Occluder") as LightOccluder2D
		var shadow := Rect2(occluder.occluder.polygon[0], occluder.occluder.polygon[2] - occluder.occluder.polygon[0])
		var lit_side_visible := true
		var far_side_hidden := true
		for side in [-1, 1]:
			sight.project(Vector2(side * 34, 4))
			lit_side_visible = lit_side_visible and not Geometry2D.is_point_in_polygon(Vector2(side * 4, 4), sight.polygon)
			far_side_hidden = far_side_hidden and sight.visible \
				and Geometry2D.is_point_in_polygon(Vector2(-side * 4, 4), sight.polygon) \
				and Geometry2D.is_point_in_polygon(Vector2(-side * 40, 4), sight.polygon)
		sight.project(Vector2(0, 4))
		var blocks := shadow == post_bounds and first_post.end.y >= door_shadow.occluder.polygon[0].y \
			and sight.bounds == post_bounds and sight.is_in_group("door_stop_sight") \
			and lit_side_visible and far_side_hidden and not sight.visible
		var passed := joins and matches and blocks
		errors += 0 if passed else 1
		print("%s %s joins its door frame and blocks light and rear visibility from both sides"
			% ["PASS" if passed else "FAIL", stop.name])
		door.free()
		stop.free()
	quit(1 if errors else 0)
