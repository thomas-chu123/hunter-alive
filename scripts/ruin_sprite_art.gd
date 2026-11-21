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
const CRAB := preload("res://assets/monster/lantern_crab.png")
const KEEPER := preload("res://assets/monster/seal_keeper.png")
const LANTERN_REGION := Rect2(1366, 423, 240, 325)


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


static func draw_stage_guard(canvas: Node2D, crab: bool, facing: float,
		armed: bool, lean: float, tint: Color) -> void:
	canvas.draw_set_transform(Vector2.ZERO, lean * facing, Vector2(facing, 1))
	if crab:
		var offset := Vector2(836, 814)
		var scale := 0.085
		if armed:
			var source := Rect2(130, 28, 1490, 790)
			canvas.draw_texture_rect_region(CRAB, Rect2((source.position - offset) * scale, source.size * scale), source, tint)
		else:
			# Keep the pincer while omitting the hanging lantern beneath it.
			for source in [Rect2(130, 28, 1230, 790), Rect2(1360, 28, 260, 386)]:
				canvas.draw_texture_rect_region(CRAB, Rect2((source.position - offset) * scale, source.size * scale), source, tint)
	else:
		var source := Rect2(0, 0, KEEPER.get_width(), KEEPER.get_height())
		var scale := 0.128
		var feet := Vector2(594, 1307)
		canvas.draw_texture_rect_region(KEEPER, Rect2(-feet * scale, source.size * scale), source, tint)
	canvas.draw_set_transform(Vector2.ZERO)


const BESTIARY_ATLASES := [
	preload("res://assets/monster/stage3_beasts_a.png"),
	preload("res://assets/monster/stage3_beasts_b.png"),
]


static func draw_bestiary(canvas: Node2D, index: int, facing: float, lean: float, tint: Color) -> void:
	var atlas: Texture2D = BESTIARY_ATLASES[0 if index < 8 else 1]
	var frame := index % 8
	var cell := atlas.get_size() / Vector2(4, 2)
	var source := Rect2(Vector2(frame % 4, 0 if frame < 4 else 1) * cell, cell)
	var size := Vector2(103, 103)
	canvas.draw_set_transform(Vector2.ZERO, lean * facing, Vector2(facing, 1))
	canvas.draw_texture_rect_region(atlas, Rect2(Vector2(-size.x * 0.5, -size.y * 0.88), size), source, tint)
	canvas.draw_set_transform(Vector2.ZERO)
