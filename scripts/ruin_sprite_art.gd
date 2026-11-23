extends RefCounted

const CRAB := preload("res://assets/monster/lantern_crab/idle.png")
const LANTERN_REGION := Rect2(1366, 423, 240, 325)

const POSES := {
	"spider": {
		"idle": preload("res://assets/monster/spider/idle.png"),
		"attack": preload("res://assets/monster/spider/attack.png"),
		"walk": preload("res://assets/monster/spider/walk.png"),
	},
	"lizard": {
		"idle": preload("res://assets/monster/lizard/idle.png"),
		"attack": preload("res://assets/monster/lizard/attack.png"),
		"walk": preload("res://assets/monster/lizard/walk.png"),
	},
	"treant": {
		"idle": preload("res://assets/monster/treant/idle.png"),
		"idle_unarmed": preload("res://assets/monster/treant/idle_unarmed.png"),
		"attack": preload("res://assets/monster/treant/attack.png"),
		"attack_transition": preload("res://assets/monster/treant/attack_transition.png"),
		"attack_transition_unarmed": preload("res://assets/monster/treant/attack_transition_unarmed.png"),
		"attack_unarmed": preload("res://assets/monster/treant/attack_unarmed.png"),
		"walk": preload("res://assets/monster/treant/walk.png"),
		"walk_unarmed": preload("res://assets/monster/treant/walk_unarmed.png"),
	},
	"bell_moth": {
		"idle": preload("res://assets/monster/bell_moth/idle.png"),
		"attack": preload("res://assets/monster/bell_moth/attack.png"),
	},
	"lantern_crab": {
		"idle": CRAB,
		"attack": preload("res://assets/monster/lantern_crab/attack.png"),
		"attack_transition": preload("res://assets/monster/lantern_crab/attack_transition.png"),
		"attack_unarmed": preload("res://assets/monster/lantern_crab/attack_unarmed.png"),
		"walk": preload("res://assets/monster/lantern_crab/walk.png"),
		"walk_unarmed": preload("res://assets/monster/lantern_crab/walk_unarmed.png"),
	},
	"seal_keeper": {
		"idle": preload("res://assets/monster/seal_keeper/idle.png"),
		"attack": preload("res://assets/monster/seal_keeper/attack.png"),
		"attack_transition": preload("res://assets/monster/seal_keeper/attack_transition.png"),
		"walk": preload("res://assets/monster/seal_keeper/walk.png"),
	},
	"shale_beetle": {
		"idle": preload("res://assets/monster/shale_beetle/idle.tres"),
		"attack": preload("res://assets/monster/shale_beetle/attack.png"),
	},
	"dust_hare": {
		"idle": preload("res://assets/monster/dust_hare/idle.tres"),
		"attack": preload("res://assets/monster/dust_hare/attack.png"),
	},
	"mirror_eel": {
		"idle": preload("res://assets/monster/mirror_eel/idle.tres"),
		"attack": preload("res://assets/monster/mirror_eel/attack.png"),
	},
	"root_mole": {
		"idle": preload("res://assets/monster/root_mole/idle.tres"),
		"attack": preload("res://assets/monster/root_mole/attack.png"),
	},
	"reed_leech": {
		"idle": preload("res://assets/monster/reed_leech/idle.tres"),
		"attack": preload("res://assets/monster/reed_leech/attack.png"),
	},
	"silt_ray": {
		"idle": preload("res://assets/monster/silt_ray/idle.tres"),
		"attack": preload("res://assets/monster/silt_ray/attack.png"),
	},
	"sluice_snail": {
		"idle": preload("res://assets/monster/sluice_snail/idle.tres"),
		"attack": preload("res://assets/monster/sluice_snail/attack.png"),
	},
	"tide_salamander": {
		"idle": preload("res://assets/monster/tide_salamander/idle.tres"),
		"attack": preload("res://assets/monster/tide_salamander/attack.png"),
	},
	"thorn_archer": {
		"idle": preload("res://assets/monster/thorn_archer/idle.tres"),
		"attack": preload("res://assets/monster/thorn_archer/attack.png"),
		"attack_unarmed": preload("res://assets/monster/thorn_archer/attack_unarmed.png"),
	},
	"shield_heron": {
		"idle": preload("res://assets/monster/shield_heron/idle.tres"),
		"attack": preload("res://assets/monster/shield_heron/attack.png"),
		"attack_unarmed": preload("res://assets/monster/shield_heron/attack_unarmed.png"),
	},
	"key_jackal": {
		"idle": preload("res://assets/monster/key_jackal/idle.tres"),
		"attack": preload("res://assets/monster/key_jackal/attack.png"),
	},
	"ash_scribe": {
		"idle": preload("res://assets/monster/ash_scribe/idle.tres"),
		"attack": preload("res://assets/monster/ash_scribe/attack.png"),
	},
	"shard_warden": {
		"idle": preload("res://assets/monster/shard_warden/idle.tres"),
		"attack": preload("res://assets/monster/shard_warden/attack.png"),
		"walk": preload("res://assets/monster/shard_warden/walk.png"),
	},
	"copper_cicada": {
		"idle": preload("res://assets/monster/copper_cicada/idle.tres"),
		"attack": preload("res://assets/monster/copper_cicada/attack.png"),
	},
	"burial_ram": {
		"idle": preload("res://assets/monster/burial_ram/idle.tres"),
		"attack": preload("res://assets/monster/burial_ram/attack.png"),
	},
}

const IDLE_ANCHORS := {"spider": 146.0, "lizard": 158.0, "treant": 121.0}
const UNARMED_TREANT_ANCHOR := 145.0
const MOTH_CELL := 627.0
# Abdomen position within each cell, kept aligned with the in-game warning glow.
const MOTH_ABDOMEN := [Vector2(305, 365), Vector2(307, 372),
	Vector2(334, 383), Vector2(298, 373)]
const MOTION_CELL := Vector2(224, 224)
const MOTION_ANCHOR := Vector2(112, 197)


static func draw_ground_idle(canvas: Node2D, species: String, unarmed: bool, scale: float,
		facing: float, torso_motion: float, tint: Color = Color.WHITE) -> void:
	var key := "idle_unarmed" if unarmed else "idle"
	var texture: Texture2D = POSES[species][key]
	var anchor: float = UNARMED_TREANT_ANCHOR if unarmed else IDLE_ANCHORS[species]
	var width := float(texture.get_width())
	var height := float(texture.get_height())
	var source := Rect2(Vector2.ZERO, texture.get_size())
	var dest := Rect2(-anchor * scale, -height * scale, width * scale, height * scale)
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
	canvas.draw_texture_rect_region(POSES["bell_moth"].idle, dest, source, tint)
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
		var texture: Texture2D = POSES["seal_keeper"].idle
		var source := Rect2(Vector2.ZERO, texture.get_size())
		var scale := 0.128
		var feet := Vector2(594, 1307)
		canvas.draw_texture_rect_region(texture, Rect2(-feet * scale, source.size * scale), source, tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_bestiary_idle(canvas: Node2D, species: String, facing: float, lean: float, tint: Color,
		stretch: float = 1.0, recoil: float = 0.0) -> void:
	var sprite: AtlasTexture = POSES[species].idle
	var size := Vector2(103, 103)
	canvas.draw_set_transform(Vector2(recoil, 0), lean * signf(facing), Vector2(facing, stretch))
	canvas.draw_texture_rect_region(sprite.atlas, Rect2(Vector2(-size.x * 0.5, -size.y * 0.88), size), sprite.region, tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_motion_frame(canvas: Node2D, sheet: Texture2D, frame: int, facing: float,
		tint: Color, stretch: float, lean: float, recoil: float) -> void:
	var source := Rect2(Vector2(frame, 0) * MOTION_CELL, MOTION_CELL)
	var dest := Rect2(-MOTION_ANCHOR * 0.8, MOTION_CELL * 0.8)
	canvas.draw_set_transform(Vector2(recoil, 0), lean * signf(facing), Vector2(facing, stretch))
	canvas.draw_texture_rect_region(sheet, dest, source, tint)
	canvas.draw_set_transform(Vector2.ZERO)
