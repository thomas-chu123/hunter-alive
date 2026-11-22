extends RefCounted

const FRAMES := {
	"idle": preload("res://assets/characters/hunter/idle.png"),
	"walk": preload("res://assets/characters/hunter/walk.png"),
	"run": preload("res://assets/characters/hunter/run.png"),
	"crouch": preload("res://assets/characters/hunter/crouch.png"),
	"jump": preload("res://assets/characters/hunter/jump.png"),
	"land": preload("res://assets/characters/hunter/land.png"),
	"knife_attack": preload("res://assets/characters/hunter/knife_attack.png"),
	"bow_attack": preload("res://assets/characters/hunter/bow_attack.png"),
	"hurt": preload("res://assets/characters/hunter/hurt.png"),
	"glide": preload("res://assets/characters/hunter/glide.png"),
}
const EMBER_POSE := preload("res://assets/characters/hunter/ember_staff_pose.png")
const EMBER_ANCHOR := Vector2(160, 405)
const EMBER_SCALE := 0.17
const EMBER_GRIP := Vector2(228, 173)
const EMBER_GEM_FROM_GRIP := (Vector2(251, 51) - EMBER_GRIP) * EMBER_SCALE
# Trace the painted staff, leaving the standing pose's hand and boot out of the sprite.
const EMBER_STAFF_OUTLINE := [
	Vector2(228, 152), Vector2(228, 119), Vector2(237, 81), Vector2(233, 66),
	Vector2(230, 48), Vector2(241, 29), Vector2(254, 21), Vector2(269, 33),
	Vector2(274, 57), Vector2(260, 76), Vector2(248, 84), Vector2(240, 119),
	Vector2(236, 155), Vector2(233, 193), Vector2(229, 232), Vector2(223, 284),
	Vector2(216, 335), Vector2(212, 381), Vector2(204, 382), Vector2(206, 332),
	Vector2(214, 276), Vector2(218, 228), Vector2(222, 190), Vector2(226, 171),
]

const FRAME_WIDTH := 443
const FRAME_COUNT := 4
const SCALE := 0.38
const BOW_RELEASE_FRAME := 3
# Pixel position of the grip on the release frame, measured from its left edge.
const BOW_GRIP := Vector2(290, 61)
# Outline of the thrust frame with the painted trail outside it. Short blades draw their own trail.
const BLADE_POSE := [
	Vector2(0, 0), Vector2(337, 0), Vector2(337, 57), Vector2(372, 61),
	Vector2(378, 67), Vector2(361, 74), Vector2(338, 79), Vector2(285, 83),
	Vector2(260, 84), Vector2(260, 109), Vector2(270, 123), Vector2(304, 187), Vector2(0, 187),
]
# Each stride uses the original body frame with a cut around the knife blade.
const STRIDE_GRIPS := {
	"walk": [Vector2(262, 98), Vector2(257, 96), Vector2(267, 102), Vector2(271, 93)],
	"run": [Vector2(283, 83), Vector2(282, 79), Vector2(287, 84), Vector2(267, 92)],
}
const STRIDE_KNIFE_CUTS := {
	"walk": [
		[Vector2(268, 88), Vector2(271, 96), Vector2(267, 106)],
		[Vector2(261, 94), Vector2(260, 99), Vector2(253, 100), Vector2(253, 97),
			Vector2(239, 96), Vector2(238, 102), Vector2(242, 104), Vector2(254, 102)],
		[Vector2(272, 90), Vector2(273, 100), Vector2(271, 111)],
		[],
	],
	"run": [
		[Vector2(291, 59), Vector2(289, 76), Vector2(290, 91)],
		[Vector2(290, 60), Vector2(288, 73), Vector2(289, 88)],
		[Vector2(300, 58), Vector2(294, 78), Vector2(294, 94)],
		[Vector2(277, 66), Vector2(275, 85), Vector2(274, 99)],
	],
}
# In the passing step, part of the knife overlaps the tunic. Sample the adjacent fabric.
const WALK_TUNIC_PATCH := [
	Vector2(239, 96), Vector2(249, 97), Vector2(249, 101), Vector2(242, 104), Vector2(238, 102),
]


static func bow_origin(facing: float) -> Vector2:
	var height: float = FRAMES["bow_attack"].get_height()
	var local := (BOW_GRIP - Vector2(FRAME_WIDTH * 0.5, height)) * SCALE
	return Vector2(local.x * facing, local.y)


static func draw_frame(canvas: Node2D, action: String, frame: int, facing: float, bob: float = 0.0) -> void:
	var texture: Texture2D = FRAMES[action]
	var source := Rect2(frame * FRAME_WIDTH, 0, FRAME_WIDTH, texture.get_height())
	var size := source.size * SCALE
	canvas.draw_set_transform(Vector2(0, bob), 0, Vector2(facing, 1))
	canvas.draw_texture_rect_region(texture, Rect2(-size.x * 0.5, -size.y, size.x, size.y), source)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_short_blade(canvas: Node2D, frame: int, facing: float) -> void:
	if frame == 0 or frame == FRAME_COUNT - 1:
		draw_frame(canvas, "knife_attack", frame, facing)
		return
	var texture: Texture2D = FRAMES["knife_attack"]
	_draw_body_outline(canvas, texture, 2, facing, BLADE_POSE)


static func draw_ember_stride(canvas: Node2D, action: String, frame: int, facing: float) -> void:
	var texture: Texture2D = FRAMES[action]
	var grip: Vector2 = STRIDE_GRIPS[action][frame]
	var anchor := Vector2(FRAME_WIDTH * 0.5, texture.get_height())
	var staff_grip := (grip - anchor) * SCALE
	draw_ember_staff(canvas, staff_grip, 0.35 if action == "run" else 0.14, facing)
	draw_stride_body(canvas, action, frame, facing)


static func draw_ember_staff(canvas: Node2D, grip: Vector2, angle: float, facing: float) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point: Vector2 in EMBER_STAFF_OUTLINE:
		points.append((point - EMBER_GRIP) * EMBER_SCALE)
		uvs.append(point / EMBER_POSE.get_size())
	canvas.draw_set_transform(grip * Vector2(facing, 1.0), angle * facing, Vector2(facing, 1.0))
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, EMBER_POSE)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_stride_body(canvas: Node2D, action: String, frame: int, facing: float) -> void:
	var texture: Texture2D = FRAMES[action]
	var cut: Array = STRIDE_KNIFE_CUTS[action][frame]
	if cut.is_empty():
		draw_frame(canvas, action, frame, facing)
		return
	var width := float(FRAME_WIDTH)
	var height := float(texture.get_height())
	var outline := [Vector2.ZERO, Vector2(width, 0), Vector2(width, cut.front().y)]
	outline.append_array(cut)
	outline.append_array([Vector2(width, cut.back().y), Vector2(width, height), Vector2(0, height)])
	_draw_body_outline(canvas, texture, frame, facing, outline)
	if action == "walk" and frame == 1:
		_draw_body_outline(canvas, texture, frame, facing, WALK_TUNIC_PATCH, Vector2(-1, 8))


static func _draw_body_outline(canvas: Node2D, texture: Texture2D, frame: int, facing: float,
		outline: Array, sample_offset: Vector2 = Vector2.ZERO) -> void:
	var anchor := Vector2(FRAME_WIDTH * 0.5, texture.get_height())
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point: Vector2 in outline:
		points.append((point - anchor) * SCALE)
		uvs.append((point + Vector2(FRAME_WIDTH * frame, 0) + sample_offset) / texture.get_size())
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_ember_pose(canvas: Node2D, facing: float, bob: float) -> void:
	canvas.draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing, 1))
	canvas.draw_texture_rect(EMBER_POSE, Rect2(-EMBER_ANCHOR * EMBER_SCALE, EMBER_POSE.get_size() * EMBER_SCALE), false)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_climb(canvas: Node2D, frame: int, facing: float) -> void:
	var texture: Texture2D = FRAMES["run"]
	var source := Rect2(frame * FRAME_WIDTH, 0, FRAME_WIDTH, texture.get_height())
	var size := source.size * SCALE
	canvas.draw_set_transform(Vector2(facing * 10, -24), -facing * PI * 0.5, Vector2(facing, 1))
	canvas.draw_texture_rect_region(texture, Rect2(-size.x * 0.5, -size.y, size.x, size.y), source)
	canvas.draw_set_transform(Vector2.ZERO)
