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
const EMBER_GEM := (Vector2(251, 51) - EMBER_ANCHOR) * EMBER_SCALE

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
	var anchor := Vector2(FRAME_WIDTH * 0.5, texture.get_height())
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point: Vector2 in BLADE_POSE:
		points.append((point - anchor) * SCALE)
		uvs.append((point + Vector2(FRAME_WIDTH * 2, 0)) / texture.get_size())
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_ember_pose(canvas: Node2D, facing: float, bob: float) -> void:
	canvas.draw_set_transform(Vector2(0, bob), 0, Vector2(facing, 1))
	canvas.draw_texture_rect(EMBER_POSE, Rect2(-EMBER_ANCHOR * EMBER_SCALE, EMBER_POSE.get_size() * EMBER_SCALE), false)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_climb(canvas: Node2D, frame: int, facing: float) -> void:
	var texture: Texture2D = FRAMES["run"]
	var source := Rect2(frame * FRAME_WIDTH, 0, FRAME_WIDTH, texture.get_height())
	var size := source.size * SCALE
	canvas.draw_set_transform(Vector2(facing * 10, -24), -facing * PI * 0.5, Vector2(facing, 1))
	canvas.draw_texture_rect_region(texture, Rect2(-size.x * 0.5, -size.y, size.x, size.y), source)
	canvas.draw_set_transform(Vector2.ZERO)
