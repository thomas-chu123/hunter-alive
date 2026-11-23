extends RefCounted

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")

static var poses := _load_poses()


static func _load_poses() -> Dictionary:
	var result := {}
	for species: String in Bestiary.creatures:
		var art: Dictionary = Bestiary.creatures[species].art
		var sheets := {}
		for action: String in art.poses:
			sheets[action] = load(art.poses[action]) as Texture2D
		if art.has("ground_effect"):
			sheets.ground_effect = load(art.ground_effect.texture) as Texture2D
		result[species] = sheets
	return result


static func draw_ground_idle(canvas: Node2D, species: String, unarmed: bool,
		facing: float, torso_motion: float, tint: Color, offset_y: float = 0.0, stretch_x: float = 1.0) -> void:
	var art: Dictionary = Bestiary.creatures[species].art
	var key := "idle_unarmed" if unarmed else "idle"
	var texture: Texture2D = poses[species][key]
	var anchor: float = art.get("unarmed_anchor", art.anchor) if unarmed else art.anchor
	var scale: float = art.scale
	var size := texture.get_size()
	var source := Rect2(Vector2.ZERO, size)
	var dest := Rect2(-anchor * scale, -size.y * scale, size.x * scale, size.y * scale)
	canvas.draw_set_transform(Vector2(0, offset_y), 0, Vector2(facing * stretch_x, 1))
	if is_zero_approx(torso_motion):
		canvas.draw_texture_rect_region(texture, dest, source, tint)
		canvas.draw_set_transform(Vector2.ZERO)
		return

	# Keep the feet anchored while the upper body breathes or follows the stride.
	var upper_height := floorf(size.y * 0.70)
	var lower_source := Rect2(Vector2(0, upper_height), Vector2(size.x, size.y - upper_height))
	var lower_dest := Rect2(dest.position + Vector2(0, upper_height * scale), lower_source.size * scale)
	var upper_dest := Rect2(dest.position + Vector2(0, torso_motion),
		Vector2(dest.size.x, upper_height * scale - torso_motion))
	canvas.draw_texture_rect_region(texture, lower_dest, lower_source, tint)
	canvas.draw_texture_rect_region(texture, upper_dest, Rect2(Vector2.ZERO, Vector2(size.x, upper_height)), tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_hover_idle(canvas: Node2D, species: String, pose: int, facing: float, flap: float, tint: Color, offset_y: float = 0.0) -> void:
	var art: Dictionary = Bestiary.creatures[species].art
	var cell := Vector2.ONE * float(art.cell)
	var quadrant := Vector2(float(pose % 2), 1.0 if pose >= 2 else 0.0)
	var scale: float = art.scale
	var source := Rect2(quadrant * cell, cell)
	var dest := Rect2(-Bestiary.vector(art.abdomen[pose]) * scale, cell * scale)
	canvas.draw_set_transform(Vector2(0, float(art.y_offset) + offset_y), 0, Vector2(facing * flap, 1))
	canvas.draw_texture_rect_region(poses[species].idle, dest, source, tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_guard_idle(canvas: Node2D, species: String, facing: float,
		armed: bool, lean: float, tint: Color, offset_y: float = 0.0, stretch_y: float = 1.0, stretch_x: float = 1.0) -> void:
	var art: Dictionary = Bestiary.creatures[species].art
	var texture: Texture2D = poses[species].idle
	var anchor := Bestiary.vector(art.anchor)
	var scale: float = art.scale
	var regions: Array = art.get("armed_regions", [])
	if not armed:
		regions = art.get("unarmed_regions", regions)
	canvas.draw_set_transform(Vector2(0, offset_y), lean * facing, Vector2(facing * stretch_x, stretch_y))
	if regions.is_empty():
		var size := texture.get_size()
		canvas.draw_texture_rect_region(texture, Rect2(-anchor * scale, size * scale), Rect2(Vector2.ZERO, size), tint)
	else:
		for region in regions:
			var source := Bestiary.rectangle(region)
			canvas.draw_texture_rect_region(texture, Rect2((source.position - anchor) * scale, source.size * scale), source, tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_bestiary_idle(canvas: Node2D, species: String, facing: float, lean: float, tint: Color,
		stretch: float = 1.0, recoil: float = 0.0, offset_y: float = 0.0, stretch_x: float = 1.0) -> void:
	var sprite: AtlasTexture = poses[species].idle
	var size := Bestiary.vector(Bestiary.rules.art.bestiary_size)
	var anchor_y: float = Bestiary.rules.art.bestiary_anchor_y
	canvas.draw_set_transform(Vector2(recoil, offset_y), lean * signf(facing), Vector2(facing * stretch_x, stretch))
	canvas.draw_texture_rect_region(sprite.atlas, Rect2(Vector2(-size.x * 0.5, -size.y * anchor_y), size), sprite.region, tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_motion_frame(canvas: Node2D, sheet: Texture2D, frame: int, facing: float,
		tint: Color, stretch: float, lean: float, recoil: float, offset_y: float = 0.0, stretch_x: float = 1.0) -> void:
	var art: Dictionary = Bestiary.rules.art
	var cell := Bestiary.vector(art.frame_size)
	var anchor := Bestiary.vector(art.frame_anchor)
	var scale: float = art.frame_scale
	var source := Rect2(Vector2(frame, 0) * cell, cell)
	var dest := Rect2(-anchor * scale, cell * scale)
	canvas.draw_set_transform(Vector2(recoil, offset_y), lean * signf(facing), Vector2(facing * stretch_x, stretch))
	canvas.draw_texture_rect_region(sheet, dest, source, tint)
	canvas.draw_set_transform(Vector2.ZERO)
