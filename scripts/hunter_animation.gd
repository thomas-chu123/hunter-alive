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
const FRAME_WIDTH := 443
const FRAME_COUNT := 4
const SCALE := 0.38


static func draw_frame(canvas: Node2D, action: String, frame: int, facing: float) -> void:
	var texture: Texture2D = FRAMES[action]
	var source := Rect2(frame * FRAME_WIDTH, 0, FRAME_WIDTH, texture.get_height())
	var size := source.size * SCALE
	canvas.draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	canvas.draw_texture_rect_region(texture, Rect2(-size.x * 0.5, -size.y, size.x, size.y), source)
	canvas.draw_set_transform(Vector2.ZERO)
