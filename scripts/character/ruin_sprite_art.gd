extends RefCounted

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const ACTION_CELL := Vector2i(256, 256)
const ACTION_ORIGIN := Vector2(128, 214)
const ACTION_SCALE := 0.8
const ACTION_COLUMNS := 4
enum Locomotion { IDLE, WALK, RUN, TURN }


static func load_poses(art: Dictionary) -> Dictionary:
	var sheets := {}
	for action: String in art.poses:
		sheets[action] = load(art.poses[action]) as Texture2D
	if art.has("ground_effect"):
		sheets.ground_effect = load(art.ground_effect.texture) as Texture2D
	return sheets


static func draw_ground_idle(canvas: Node2D, texture: Texture2D, art: Dictionary,
		facing: float, torso_motion: float, tint: Color, offset_y: float = 0.0, stretch_x: float = 1.0) -> void:
	var anchor: float = art.anchor
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


static func combat_frame_layout(appearance: Dictionary) -> Dictionary:
	return appearance.get("combat_frame_layout", Bestiary.rules.art)


static func draw_motion_frame(canvas: Node2D, sheet: Texture2D, frame: int, facing: float,
		tint: Color, stretch: float, lean: float, recoil: float, offset_y: float = 0.0,
		stretch_x: float = 1.0, layout: Dictionary = {}) -> void:
	var frame_layout: Dictionary = Bestiary.rules.art if layout.is_empty() else layout
	var cell := Bestiary.vector(frame_layout.frame_size)
	var anchor := Bestiary.vector(frame_layout.frame_anchor)
	var scale := float(Bestiary.rules.art.frame_scale)
	var source := Rect2(Vector2(frame, 0) * cell, cell)
	var dest := Rect2(-anchor * scale, cell * scale)
	canvas.draw_set_transform(Vector2(recoil, offset_y), lean * signf(facing), Vector2(facing * stretch_x, stretch))
	canvas.draw_texture_rect_region(sheet, dest, source, tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_locomotion(canvas: Node2D, sheet: Texture2D, cell: Vector2i, facing: float,
		tint: Color, offset_y: float) -> void:
	var source := Rect2(Vector2(cell * ACTION_CELL), Vector2(ACTION_CELL))
	var dest := Rect2(-ACTION_ORIGIN * ACTION_SCALE, source.size * ACTION_SCALE)
	canvas.draw_set_transform(Vector2(0, offset_y), 0.0, Vector2(facing, 1.0))
	canvas.draw_texture_rect_region(sheet, dest, source, tint)
	canvas.draw_set_transform(Vector2.ZERO)
