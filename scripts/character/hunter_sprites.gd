extends RefCounted

const ROOT := "res://assets/characters/hunter"
const SCALE := 2.0
const COLUMNS := 4
const ROWS := 4
const MOTION_SIZE := Vector2i(448, 400)
const MOTION_ORIGIN := Vector2(224, 254)
const ATTACK_SIZE := Vector2i(560, 352)
const ATTACK_ORIGIN := Vector2(280, 254)
const MOTION_FRAMES := COLUMNS
const DYNAMIC_ATTACK_FRAMES := COLUMNS * ROWS
# Each motion occupies one row. The hunter bow attack uses the third row of reaction.png.
const MOTION_ATLASES := {
	"locomotion": ["idle", "walk", "run", "retreat"],
	"traversal": ["jump", "glide", "land", "climb"],
	"reaction": ["crouch", "hurt"],
}

static var _equipped_weapon := ""
static var _sheets: Dictionary[String, Texture2D] = {}


static func attack_frames(weapon: String) -> int:
	return MOTION_FRAMES if weapon == "hunter_bow" else DYNAMIC_ATTACK_FRAMES


static func attack_action(weapon: String, crouching: bool, step: int) -> String:
	var action := "attack"
	if weapon == "fang_dagger" and step > 1:
		action += "_%d" % step
	if crouching and weapon not in ["hunter_bow", "thorn_bow"]:
		action += "_crouch"
	return action


static func draw_motion(canvas: Node2D, weapon: String, action: String, frame: int, facing: float) -> void:
	for atlas: String in MOTION_ATLASES:
		var row: int = MOTION_ATLASES[atlas].find(action)
		if row >= 0:
			_draw(canvas, weapon, atlas, row * COLUMNS + frame, facing, MOTION_SIZE, MOTION_ORIGIN)
			return


static func draw_attack(canvas: Node2D, weapon: String, progress: float, facing: float,
		crouching: bool, step: int) -> void:
	var count := attack_frames(weapon)
	var frame := clampi(floori(progress * count), 0, count - 1)
	if count == MOTION_FRAMES:
		_draw(canvas, weapon, "reaction", MOTION_ATLASES.reaction.size() * COLUMNS + frame,
			facing, MOTION_SIZE, MOTION_ORIGIN)
	else:
		_draw(canvas, weapon, attack_action(weapon, crouching, step), frame, facing, ATTACK_SIZE, ATTACK_ORIGIN)


static func _draw(canvas: Node2D, weapon: String, atlas: String, frame: int, facing: float,
		cell_size: Vector2i, origin: Vector2) -> void:
	if _equipped_weapon != weapon:
		_sheets.clear()
		_equipped_weapon = weapon
	if not _sheets.has(atlas):
		_sheets[atlas] = load("%s/%s/%s.png" % [ROOT, weapon, atlas]) as Texture2D
	var texture := _sheets[atlas]
	var cell := Vector2i(frame % COLUMNS, floori(float(frame) / COLUMNS))
	var region := Rect2(Vector2(cell * cell_size), Vector2(cell_size))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	canvas.draw_texture_rect_region(texture, Rect2(-origin / SCALE, region.size / SCALE), region)
	canvas.draw_set_transform(Vector2.ZERO)
