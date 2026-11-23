extends RefCounted

const ROOT := "res://assets/characters/hunter"
const SCALE := 2.0
const COLUMNS := 4
const MOTION_SIZE := Vector2i(448, 344)
const CLIMB_SIZE := Vector2i(448, 384)
const MOTION_ORIGIN := Vector2(224, 242)
const ATTACK_SIZE := Vector2i(560, 352)
const ATTACK_ORIGIN := Vector2(280, 254)
const MOTION_FRAMES := 4
const DYNAMIC_ATTACK_FRAMES := 16

static var _equipped_weapon := ""
static var _sheets: Dictionary[String, Texture2D] = {}


static func attack_frames(weapon: String) -> int:
	return MOTION_FRAMES if weapon in ["hunter_knife", "hunter_bow"] else DYNAMIC_ATTACK_FRAMES


static func attack_action(weapon: String, crouching: bool, step: int) -> String:
	var action := "attack"
	if weapon == "fang_dagger" and step > 1:
		action += "_%d" % step
	if crouching and weapon not in ["hunter_knife", "hunter_bow", "thorn_bow"]:
		action += "_crouch"
	return action


static func motion_size(action: String) -> Vector2i:
	return CLIMB_SIZE if action == "climb" else MOTION_SIZE


static func draw_motion(canvas: Node2D, weapon: String, action: String, frame: int, facing: float, bob: float = 0) -> void:
	_draw(canvas, weapon, action, frame, facing, motion_size(action), MOTION_ORIGIN)


static func draw_attack(canvas: Node2D, weapon: String, progress: float, facing: float,
		crouching: bool, step: int) -> void:
	var count := attack_frames(weapon)
	var frame := clampi(floori(progress * count), 0, count - 1)
	_draw(canvas, weapon, attack_action(weapon, crouching, step), frame, facing, ATTACK_SIZE, ATTACK_ORIGIN)


static func _draw(canvas: Node2D, weapon: String, action: String, frame: int, facing: float,
		cell_size: Vector2i, origin: Vector2) -> void:
	if _equipped_weapon != weapon:
		_sheets.clear()
		_equipped_weapon = weapon
	if not _sheets.has(action):
		_sheets[action] = load("%s/%s/%s.png" % [ROOT, weapon, action]) as Texture2D
	var texture := _sheets[action]
	var cell := Vector2i(frame % COLUMNS, floori(float(frame) / COLUMNS))
	var region := Rect2(Vector2(cell * cell_size), Vector2(cell_size))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	canvas.draw_texture_rect_region(texture, Rect2(-origin / SCALE, region.size / SCALE), region)
	canvas.draw_set_transform(Vector2.ZERO)
