extends RefCounted

const ATLAS := [
	preload("res://assets/monster/spider.png"),
	preload("res://assets/monster/lizard.png"),
	preload("res://assets/monster/treant.png"),
]
const COLUMNS := [0, 309, 618, 927, 1254]
const BODY_ANCHOR := [
	[146, 145, 125, 110],
	[158, 159, 148, 151],
	[121, 129, 127, 145],
]
const MOTH_ATLAS := preload("res://assets/monster/bell_moth.png")
const MOTH_CELL := 627.0
# Abdomen position within each cell, kept aligned with the in-game warning glow.
const MOTH_ABDOMEN := [Vector2(305, 365), Vector2(307, 372),
	Vector2(334, 383), Vector2(298, 373)]


static func draw_actor(canvas: Node2D, row: int, pose: int, scale: float,
		facing: float, torso_motion: float, tint: Color = Color.WHITE) -> void:
	var width: float = COLUMNS[pose + 1] - COLUMNS[pose]
	var texture: Texture2D = ATLAS[row]
	var height := float(texture.get_height())
	var source := Rect2(COLUMNS[pose], 0, width, height)
	var dest := Rect2(-BODY_ANCHOR[row][pose] * scale, -height * scale,
		width * scale, height * scale)
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	if is_zero_approx(torso_motion):
		canvas.draw_texture_rect_region(texture, dest, source, tint)
		return

	# Keep the feet anchored while the upper body breathes or follows the stride.
	var upper_height := floorf(height * 0.70)
	var lower_source := Rect2(source.position + Vector2(0, upper_height),
		Vector2(width, height - upper_height))
	var lower_dest := Rect2(dest.position + Vector2(0, upper_height * scale),
		lower_source.size * scale)
	var upper_dest := Rect2(dest.position + Vector2(0, torso_motion),
		Vector2(dest.size.x, upper_height * scale - torso_motion))
	canvas.draw_texture_rect_region(texture, lower_dest, lower_source, tint)
	canvas.draw_texture_rect_region(texture, upper_dest,
		Rect2(source.position, Vector2(width, upper_height)), tint)


static func draw_bell_moth(canvas: Node2D, pose: int, facing: float, flap: float, tint: Color) -> void:
	var cell := Vector2(MOTH_CELL, MOTH_CELL)
	var quadrant := Vector2(float(pose % 2), 1.0 if pose >= 2 else 0.0)
	var scale := 0.126
	var source := Rect2(quadrant * cell, cell)
	var dest := Rect2(-MOTH_ABDOMEN[pose] * scale, cell * scale)
	canvas.draw_set_transform(Vector2(0, -22), 0, Vector2(facing * flap, 1))
	canvas.draw_texture_rect_region(MOTH_ATLAS, dest, source, tint)
	canvas.draw_set_transform(Vector2.ZERO)
