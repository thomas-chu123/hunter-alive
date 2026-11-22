extends RefCounted

const HunterAnimation := preload("res://scripts/hunter_animation.gd")
const Equipment := preload("res://scripts/ruin_equipment.gd")
const CELL := 443.0

# Grip and tip in the inventory illustration's 443-pixel reference space,
# followed by the held length from grip to tip and the resting angle.
const WEAPONS := {
	"root_blade": [Vector2(108, 328), Vector2(402, 33), 40.0, -0.75],
	"fang_dagger": [Vector2(300, 137), Vector2(120, 387), 20.0, 1.02],
	"sluice_spear": [Vector2(137, 319), Vector2(405, 30), 78.0, -0.97],
	"tide_hammer": [Vector2(152, 305), Vector2(290, 139), 39.0, -1.14],
	"thorn_bow": [Vector2(221, 199), Vector2(348, 34), 25.0, -1.09],
	"scribe_staff": [Vector2(179, 277), Vector2(358, 32), 44.0, -1.03],
	"gate_halberd": [Vector2(164, 295), Vector2(370, 20), 57.0, -1.01],
}
const RELEASE := {
	"sluice_spear": 0.36, "tide_hammer": 0.56, "root_blade": 0.42,
	"gate_halberd": 0.50, "scribe_staff": 0.52,
}
const BOW_TOP := Vector2(343, 79)
const BOW_BOTTOM := Vector2(151, 386)
const DEFAULT_RELEASE := 0.26
const EMBER_CAST_LEAN := 0.10
const MELEE_GROUND := 175.0

static var clean_bodies := {}
static var weapon_textures := {}


static func release_point(weapon: String, bow: bool) -> float:
	return float(HunterAnimation.BOW_RELEASE_FRAME) / HunterAnimation.FRAME_COUNT if bow else float(RELEASE.get(weapon, DEFAULT_RELEASE))


static func draw_held(canvas: Node2D, weapon: String, action: String, frame: int, facing: float, bob: float = 0.0) -> void:
	if weapon == "thorn_bow" and action == "idle":
		_draw_bow(canvas, 0, facing, bob)
		return
	var angle: float = WEAPONS[weapon][3]
	if action == "walk" or action == "run":
		var texture: Texture2D = HunterAnimation.FRAMES[action]
		var grip: Vector2 = HunterAnimation.STRIDE_GRIPS[action][frame]
		var at := _local(grip, texture.get_height())
		_draw_weapon(canvas, weapon, at, angle + (0.32 if action == "run" else 0.14), facing)
		HunterAnimation.draw_stride_body(canvas, action, frame, facing)
		return
	if action in ["crouch", "jump", "land", "glide", "hurt"]:
		_draw_pose(canvas, weapon, "brace", angle + 0.24, facing, bob if action == "crouch" else 0.0)
	else:
		_draw_idle_weapon(canvas, weapon, angle, facing, bob)


static func draw_attack(canvas: Node2D, weapon: String, progress: float, facing: float, crouching: bool, step: int) -> void:
	if weapon == "thorn_bow":
		_draw_bow(canvas, 0 if progress < 0.19 else (2 if progress < release_point(weapon, true) else 3), facing)
		return
	var release := release_point(weapon, false)
	var follow := progress - release
	var recovery := smoothstep(0.13, 1.0 - release, follow)
	var angle: float = WEAPONS[weapon][3]
	var pose := "brace"
	var tint := Color.TRANSPARENT
	match weapon:
		"sluice_spear":
			pose = "thrust" if follow >= 0.0 and follow < 0.24 else "brace"
			angle = -0.04 + 0.21 * (1.0 - smoothstep(0.0, release, progress)) - 0.28 * recovery
			tint = Color("#b3dfd8")
		"tide_hammer":
			pose = "raise" if follow < 0.0 else ("thrust" if follow < 0.16 else "brace")
			angle = lerpf(-2.52, -1.76, smoothstep(0.0, release, progress)) if follow < 0.0 else lerpf(0.84, -1.38, recovery)
			tint = Color("#ecc791")
		"gate_halberd":
			pose = "raise" if follow < -0.06 else ("thrust" if follow < 0.18 else "brace")
			angle = lerpf(-2.42, -0.48, smoothstep(0.0, release, progress)) if follow < 0.0 else lerpf(0.09, 0.68, recovery)
			tint = Color("#f2d396")
		"root_blade":
			pose = "raise" if follow < -0.04 else ("thrust" if follow < 0.17 else "brace")
			angle = lerpf(-2.03, -0.55, smoothstep(0.0, release, progress)) if follow < 0.0 else lerpf(-0.19, 0.76, recovery)
			tint = Color("#cfaa70")
		"fang_dagger":
			pose = "thrust" if follow >= 0.0 and follow < 0.19 else "brace"
			var strike_angle: float = [0.46, -0.59, 0.0][clampi(step - 1, 0, 2)]
			angle = lerpf(1.6, strike_angle, smoothstep(0.0, release, progress)) if follow < 0.0 else lerpf(strike_angle, 1.35, recovery)
		"scribe_staff":
			pose = "raise" if progress > 0.16 and follow < 0.0 else ("thrust" if follow >= 0.0 and follow < 0.2 else "brace")
			angle = lerpf(-1.56, -1.93, smoothstep(0.0, release, progress)) if follow < 0.0 else lerpf(-0.18, -1.45, recovery)
	var bob := 8.0 if crouching else 0.0
	_draw_pose(canvas, weapon, pose, angle, facing, bob)
	if weapon == "scribe_staff":
		var tip := _tip(pose, weapon, angle, facing, bob)
		var charge := sin(progress * PI)
		canvas.draw_circle(tip, 4.0 + charge * 9.0, Color(0.36, 0.78, 1.0, charge * 0.23), true, -1, true)
		canvas.draw_arc(tip, 5.0 + charge * 7.0, progress * TAU, progress * TAU + PI * 1.45, 16,
			Color(0.60, 0.88, 1.0, charge * 0.75), 1.0, true)
	elif tint.a > 0 and follow >= 0.0 and follow < 0.16:
		_draw_strike_trace(canvas, weapon, _tip(pose, weapon, angle, 1.0, bob), facing, tint, follow / 0.16)


static func draw_portrait(canvas: Node2D, weapon: String) -> void:
	if weapon in ["sluice_spear", "gate_halberd"]:
		_draw_idle_weapon(canvas, weapon, -1.12, 1.0, 0.0)
	elif weapon == "tide_hammer":
		_draw_pose(canvas, weapon, "idle", WEAPONS[weapon][3], 1.0, 0.0)
	elif weapon == "thorn_bow":
		_draw_bow(canvas, 0, 1.0, 0.0, true)
	elif WEAPONS.has(weapon):
		draw_held(canvas, weapon, "idle", 0, 1.0)
	elif weapon == "hunter_bow":
		HunterAnimation.draw_frame(canvas, "bow_attack", 0, 1.0)
	elif weapon == "ember_staff":
		HunterAnimation.draw_ember_pose(canvas, 1.0, 0.0)
	elif weapon == "unarmed":
		_draw_body(canvas, "idle", 1.0, 0.0)
	else:
		HunterAnimation.draw_frame(canvas, "idle", 0, 1.0)


static func _draw_idle_weapon(canvas: Node2D, weapon: String, angle: float, facing: float, bob: float) -> void:
	_draw_body(canvas, "idle", facing, bob)
	_draw_weapon(canvas, weapon, _grip("idle") + Vector2(0, bob), angle, facing)
	_draw_idle_fist(canvas, facing, bob)


static func ember_lean(progress: float) -> float:
	if progress < DEFAULT_RELEASE:
		return -EMBER_CAST_LEAN * sin(PI * progress / DEFAULT_RELEASE)
	return EMBER_CAST_LEAN * sin(PI * (progress - DEFAULT_RELEASE) / (1.0 - DEFAULT_RELEASE))


static func _tip(pose: String, weapon: String, angle: float, facing: float, bob: float) -> Vector2:
	var reach: float = WEAPONS[weapon][2]
	return (_grip(pose) + Vector2.from_angle(angle) * reach) * Vector2(facing, 1.0) + Vector2(0, bob)


static func _draw_strike_trace(canvas: Node2D, weapon: String, tip: Vector2, facing: float, tint: Color, age: float) -> void:
	var fade := 1.0 - age
	var along := Vector2(facing, 1.0)
	if weapon == "sluice_spear":
		for offset in [-5.0, 1.0, 6.0]:
			var start := tip + Vector2(-43.0 + offset, offset)
			canvas.draw_line(start * along, (tip + Vector2(11.0 * age, offset * 0.22)) * along,
				Color(tint, fade * 0.70), 1.5, true)
	elif weapon == "tide_hammer":
		canvas.draw_arc(tip * along, 5.0 + 23.0 * age, 0, TAU, 24, Color(tint, fade * 0.78), 2.0, true)
		for offset in [-1.0, -0.4, 0.3, 0.92]:
			var ray := Vector2.from_angle(offset - PI * 0.5) * (9.0 + 26.0 * age)
			canvas.draw_line((tip + ray * 0.55) * along, (tip + ray) * along, Color(tint, fade), 1.5, true)
	else:
		var center := Vector2(17.0, -38.0)
		var arc := PackedVector2Array()
		var width := 1.54 if weapon == "gate_halberd" else 1.04
		var radius := maxf(18.0, tip.distance_to(center))
		for index in range(15):
			var theta := -width + float(index) / 14.0 * (width + 0.52)
			arc.append((center + Vector2(cos(theta) * radius, sin(theta) * radius * 0.62)) * along)
		canvas.draw_polyline(arc, Color(tint, fade * 0.83), (4.5 if weapon == "gate_halberd" else 3.0) * fade + 0.4, true)


static func _draw_pose(canvas: Node2D, weapon: String, pose: String, angle: float, facing: float, bob: float) -> void:
	_draw_weapon(canvas, weapon, _grip(pose) + Vector2(0, bob), angle, facing)
	_draw_body(canvas, pose, facing, bob)


static func _draw_bow(canvas: Node2D, frame: int, facing: float, bob: float = 0.0, mirror_bow: bool = false) -> void:
	var grip := Vector2(259, 107) if frame == 0 else (Vector2(294, 57) if frame == 2 else Vector2(290, 61))
	var angle := -1.05 if frame == 0 else -1.57
	_draw_weapon(canvas, "thorn_bow", _local(grip, 178) + Vector2(0, bob), angle, facing, frame == 2, mirror_bow)
	_draw_body(canvas, "bow_%d" % frame, facing, bob)


static func _draw_weapon(canvas: Node2D, weapon: String, at: Vector2, angle: float, facing: float,
		drawn: bool = false, mirror_bow: bool = false) -> void:
	var art: Array = WEAPONS[weapon]
	var grip: Vector2 = art[0]
	var axis: Vector2 = art[1] - grip
	var scale := float(art[2]) / axis.length()
	var rotation := angle - axis.angle()
	var texture := _weapon_texture(weapon)
	var direction := Vector2(facing, 1.0)
	var transform := Transform2D(rotation * facing, direction, 0.0, at * direction)
	if mirror_bow:
		# Reflect the bow and string about their long axis through the hand.
		var string_axis := (BOW_TOP - BOW_BOTTOM).angle() + PI * 0.5
		transform *= Transform2D(string_axis, Vector2(-1.0, 1.0), 0.0, Vector2.ZERO) * Transform2D(-string_axis, Vector2.ZERO)
	canvas.draw_set_transform_matrix(transform)
	canvas.draw_texture_rect(texture, Rect2(-grip * scale, Vector2.ONE * CELL * scale), false)
	if weapon == "thorn_bow":
		var top := (BOW_TOP - grip) * scale
		var bottom := (BOW_BOTTOM - grip) * scale
		var middle := (top + bottom) * 0.5
		middle += Vector2(-15, 0).rotated(-rotation) if drawn else Vector2.ZERO
		canvas.draw_polyline(PackedVector2Array([top, middle, bottom]), Color("#d7c089"), 0.8, true)
		if drawn:
			var shaft := Vector2(38, 0).rotated(-rotation)
			canvas.draw_line(middle, middle + shaft, Color("#e2e7af"), 1.05, true)
	canvas.draw_set_transform(Vector2.ZERO)


static func _weapon_texture(weapon: String) -> Texture2D:
	if not weapon_textures.has(weapon):
		var texture := Equipment.icon(weapon)
		if weapon == "thorn_bow":
			var image := texture.get_image()
			_mask(image, [Vector2(343, 77), Vector2(353, 79), Vector2(157, 393), Vector2(147, 391)])
			texture = ImageTexture.create_from_image(image)
		weapon_textures[weapon] = texture
	return weapon_textures[weapon]


static func _grip(pose: String) -> Vector2:
	match pose:
		"raise": return _local(Vector2(165, 40), MELEE_GROUND)
		"thrust": return _local(Vector2(317, 67), MELEE_GROUND)
		"brace": return _local(Vector2(266, 98), 174)
		_: return _local(Vector2(209, 114), 182)


static func _local(point: Vector2, height: float) -> Vector2:
	return (point - Vector2(HunterAnimation.FRAME_WIDTH * 0.5, height)) * HunterAnimation.SCALE


static func _draw_body(canvas: Node2D, pose: String, facing: float, bob: float) -> void:
	if not clean_bodies.has(pose):
		clean_bodies[pose] = _make_body(pose)
	var texture: Texture2D = clean_bodies[pose]
	var size := texture.get_size() * HunterAnimation.SCALE
	var ground := MELEE_GROUND * HunterAnimation.SCALE if pose in ["raise", "thrust"] else size.y
	canvas.draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing, 1.0))
	canvas.draw_texture_rect(texture, Rect2(-size.x * 0.5, -ground, size.x, size.y), false)
	canvas.draw_set_transform(Vector2.ZERO)


static func _draw_idle_fist(canvas: Node2D, facing: float, bob: float) -> void:
	var hand := Rect2(203, 107, 13, 13)
	var texture: Texture2D = clean_bodies["idle"]
	var area := Rect2(_local(hand.position, texture.get_height()), hand.size * HunterAnimation.SCALE)
	canvas.draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing, 1.0))
	canvas.draw_texture_rect_region(texture, area, hand)
	canvas.draw_set_transform(Vector2.ZERO)


static func _make_body(pose: String) -> ImageTexture:
	var action := "knife_attack"
	var frame := 0
	match pose:
		"idle": action = "idle"
		"brace": action = "crouch"
		"thrust": frame = 2
		"bow_0", "bow_2", "bow_3":
			action = "bow_attack"
			frame = int(pose.get_slice("_", 1))
	var texture: Texture2D = HunterAnimation.FRAMES[action]
	var image := texture.get_image().get_region(Rect2i(frame * HunterAnimation.FRAME_WIDTH, 0,
		HunterAnimation.FRAME_WIDTH, texture.get_height()))
	match pose:
		"idle":
			_mask(image, [Vector2(211, 116), Vector2(219, 116), Vector2(233, 137), Vector2(220, 139), Vector2(210, 123)], Vector2i(15, -8))
		"raise":
			_mask(image, [Vector2(168, 32), Vector2(194, 14), Vector2(207, 16), Vector2(184, 45), Vector2(174, 50), Vector2(171, 43)])
		"thrust":
			_mask(image, [Vector2(324, 0), Vector2(CELL, 0), Vector2(CELL, 124), Vector2(274, 124),
				Vector2(267, 119), Vector2(266, 109), Vector2(260, 102), Vector2(260, 77), Vector2(325, 75)])
			image.fill_rect(Rect2i(0, int(MELEE_GROUND + 1), int(CELL), 11), Color.TRANSPARENT)
		"brace":
			_mask(image, [Vector2(271, 88), Vector2(303, 78), Vector2(307, 85), Vector2(286, 103), Vector2(274, 105), Vector2(273, 100)])
		"bow_0":
			_mask(image, [Vector2(254, 50), Vector2(CELL, 50), Vector2(CELL, 178), Vector2(273, 178), Vector2(252, 116), Vector2(265, 112), Vector2(266, 101), Vector2(255, 99)])
		"bow_2", "bow_3":
			_mask(image, [Vector2(253, 0), Vector2(CELL, 0), Vector2(CELL, 178), Vector2(274, 178), Vector2(245, 121), Vector2(243, 75), Vector2(295, 68), Vector2(300, 55), Vector2(254, 49)])
	return ImageTexture.create_from_image(image)


static func _mask(image: Image, outline: Array, sample_offset: Vector2i = Vector2i.ZERO) -> void:
	var polygon := PackedVector2Array(outline)
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	var pixels := Rect2i(bounds).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var source: Image = image.duplicate() if sample_offset != Vector2i.ZERO else null
	for y in range(pixels.position.y, pixels.end.y):
		for x in range(pixels.position.x, pixels.end.x):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), polygon):
				var color: Color = Color.TRANSPARENT if source == null else source.get_pixelv(Vector2i(x, y) + sample_offset)
				image.set_pixel(x, y, color)
