extends RefCounted

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")

const COLORS := {
	"metal": Color("#ffe7ab"), "wood": Color("#c6eb83"), "water": Color("#81e6ff"),
	"fire": Color("#ff8352"), "earth": Color("#e6aa73"),
}


static func element_color(element: String) -> Color:
	return COLORS.get(element, COLORS.metal)


static func charge(canvas: Node2D, at: Vector2, element: String, progress: float, heavy: bool = false) -> void:
	var color := element_color(element)
	var power := smoothstep(0.0, 1.0, progress)
	var radius := lerpf(8.0, 16.0 if heavy else 12.0, power)
	_halo(canvas, at, radius * 2.4, color, 0.4 + power * 0.5)
	canvas.draw_arc(at, radius * 1.8, -PI / 2.0, -PI / 2.0 + maxf(0.02, progress) * TAU,
		32, Color(color, 0.75), 2.0, true)
	canvas.draw_arc(at, radius, 0, TAU, 24, Color(color.lightened(0.35), 0.9), 2.5, true)

	var mote_count := 10 if heavy else 6
	for i in range(mote_count):
		var angle := float(i) * TAU / mote_count + progress * 1.8
		var ray := Vector2.from_angle(angle)
		var distance := lerpf(radius * 3.2, radius * 1.15, power) + float(i % 3) * 4.0
		var point := at + ray * distance
		canvas.draw_line(point, point + ray * (6.0 + power * 5.0), Color(color, 0.65), 2.0, true)
	_flare(canvas, at, radius * (1.35 if heavy else 1.05), -0.2, color, 0.4 + power * 0.6)


static func sweep(canvas: Node2D, height: float, reach: float, facing: float,
		element: String, progress: float, heavy: bool = false, kind: String = "") -> void:
	var color := element_color(element)
	var fade := 1.0 - smoothstep(0.12, 1.0, progress)
	var spread := 1.0 - pow(1.0 - progress, 2.4)
	var pivot := Vector2(0, -height)
	var middle := (0.0 if facing > 0 else PI) + facing * lerpf(-0.20, 0.20, spread)
	var half_arc := 0.90 if heavy else 0.66
	var radius := reach * lerpf(0.78, 1.12, spread)
	var width := (32.0 if heavy else 22.0) * lerpf(1.0, 0.35, spread)

	# Keep a dark edge under the luminous blade so it reads on bright scenery, too.
	_crescent(canvas, pivot, middle, half_arc, radius, width * 1.5, Color(color.darkened(0.65), fade * 0.72))
	_crescent(canvas, pivot, middle, half_arc, radius, width, Color(color, fade * 0.92))
	_crescent(canvas, pivot, middle, half_arc * 0.9, radius + width * 0.17, width * 0.28,
		Color(Color.WHITE.lerp(color, 0.2), fade))

	var is_claw := kind in ["ram", "slam", "crush", "claw", "swipe", "bite"]
	for i in range(2 if heavy or is_claw else 1):
		_crescent(canvas, pivot, middle - facing * (0.12 + i * 0.13), half_arc * 0.82,
			radius - width * (0.65 + i * 0.42), width * 0.26, Color(color.lightened(0.22), fade * 0.72))

	for i in range(14 if heavy else 9):
		var angle := middle + lerpf(-half_arc, half_arc, float(i) / (13.0 if heavy else 8.0))
		var ray := Vector2.from_angle(angle)
		var tip := pivot + ray * (radius + spread * (12.0 + float(i % 4) * 8.0))
		canvas.draw_line(tip - ray * (5.0 + fade * 11.0), tip, Color(color.lightened(0.58), fade),
			1.0 + fade * 2.0, true)

	var flash := 1.0 - smoothstep(0.0, 0.43, progress)
	var center := pivot + Vector2.from_angle(middle) * radius
	if heavy:
		canvas.draw_arc(center, 10.0 + spread * 33.0, middle - 1.15, middle + 1.15, 24,
			Color(color.lightened(0.5), fade * 0.8), 3.5, true)
	_halo(canvas, center, 54.0 if heavy else 36.0, color, flash)
	_flare(canvas, center, 47.0 if heavy else 30.0, facing * 0.28, color, flash)


static func _crescent(canvas: Node2D, pivot: Vector2, middle: float, half_arc: float,
		radius: float, width: float, tint: Color) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in range(25):
		var t := float(i) / 24.0
		var ray := Vector2.from_angle(middle + lerpf(-half_arc, half_arc, t))
		var thickness := minf(radius * 0.75, width * 0.5) * sin(t * PI)
		outer.append(pivot + ray * (radius + thickness))
		if i > 0 and i < 24:
			inner.append(pivot + ray * (radius - thickness))
	inner.reverse()
	outer.append_array(inner)
	canvas.draw_colored_polygon(outer, tint)


static func bolt(canvas: Node2D, at: Vector2, direction: float, element: String,
		kind: String, radius: float, distance: float, age: float) -> void:
	var color := element_color(element)
	var size := maxf(radius, 8.0)
	var heading := Vector2(direction, 0.0)
	var length := minf(distance, 48.0 + size * 3.0)
	var tail := at - heading * length
	_halo(canvas, at, size * 2.55, color, 0.88)

	if length > 0.0:
		var shoulder := at - heading * minf(size, length * 0.35)
		canvas.draw_colored_polygon(PackedVector2Array([at + heading * size,
			shoulder + Vector2.UP * size, tail, shoulder + Vector2.DOWN * size]), Color(color, 0.64))
		canvas.draw_line(tail, at, Color(color.lightened(0.62), 0.88), size * 0.37, true)
		for i in range(8):
			var t := float(i + 1) / 9.0
			var point := at - heading * length * t
			point.y += sin(age * 27.0 + t * 12.0) * size * t
			canvas.draw_circle(point, lerpf(3.7, 1.2, t), Color(color, 0.94 - t * 0.55), true, -1, true)

	match element:
		"earth":
			canvas.draw_colored_polygon(PackedVector2Array([at + heading * size, at + Vector2.UP * size,
				at - heading * size, at + Vector2.DOWN * size * 0.85]), color.darkened(0.24))
		"wood":
			for side in [-1.0, 1.0]:
				canvas.draw_line(at + heading * size, at - heading * size + Vector2(0.0, side * size * 0.72),
					color.lightened(0.27), 3.0, true)
		"water":
			canvas.draw_arc(at, size * 0.76, 0.0, TAU, 20, Color(color, 0.76), 3.5, true)
	if kind == "spray":
		for side in [-1.0, 1.0]:
			var point := at - heading * minf(length, size * 1.7) + Vector2(0.0, side * size * 1.1)
			canvas.draw_circle(point, size * 0.40, color.lightened(0.35), true, -1, true)

	var forward_angle := 0.0 if direction > 0 else PI
	canvas.draw_arc(at, size * 1.12, forward_angle - 1.18, forward_angle + 1.18, 20,
		Color(color.lightened(0.53), 0.96), 3.0, true)
	_flare(canvas, at + heading * size * 0.26, size * 1.42, 0.0, color, 0.94)


static func _halo(canvas: Node2D, at: Vector2, radius: float, tint: Color, strength: float) -> void:
	for i in range(4, 0, -1):
		canvas.draw_circle(at, radius * float(i) / 4.0, Color(tint, strength * 0.10), true, -1, true)


static func _flare(canvas: Node2D, at: Vector2, size: float, angle: float, tint: Color, strength: float) -> void:
	if strength <= 0.0:
		return
	var axis := Vector2.from_angle(angle) * size
	var cross := axis.orthogonal()
	canvas.draw_colored_polygon(PackedVector2Array([at - axis, at - axis * 0.13 - cross * 0.13,
		at - cross * 0.56, at + axis * 0.13 - cross * 0.13, at + axis,
		at + axis * 0.13 + cross * 0.13, at + cross * 0.56, at - axis * 0.13 + cross * 0.13]),
		Color(tint.lightened(0.45), strength * 0.85))
	canvas.draw_line(at - axis * 0.64, at + axis * 0.64, Color(Color.WHITE, strength), 2.5, true)
	canvas.draw_circle(at, size * 0.17, Color(Color.WHITE, strength), true, -1, true)


static func ground(canvas: Node2D, at: Vector2, radius: float, element: String,
		active: bool, progress: float, texture: Texture2D, effect: Dictionary, heavy: bool = true) -> void:
	if active and texture != null:
		_draw_ground_sprite(canvas, at, radius, progress, texture, effect)

	var color := element_color(element)
	var alpha_fade := 1.0 - smoothstep(0.22, 1.0, progress) if active else 1.0
	var ink := Color(color, alpha_fade * (0.85 if active else 0.35 + progress * 0.52))
	var ground_line := at - Vector2(0, 2)
	var left := ground_line - Vector2(radius, 0.0)
	var right := ground_line + Vector2(radius, 0.0)

	canvas.draw_line(left, right, Color(color.darkened(0.40), ink.a * 0.45), 13.0, true)
	canvas.draw_line(left, right, ink, 5.0 if heavy else 3.0, true)
	if not active:
		for edge in [left, right]:
			canvas.draw_line(edge + Vector2.UP * 23.0, edge, ink, 3.0, true)
		canvas.draw_line(ground_line.lerp(left, progress), ground_line.lerp(right, progress),
			Color(color.lightened(0.48), 0.88), 2.5, true)
		return

	var spread := 1.0 - pow(1.0 - progress, 2.5)
	var flash := 1.0 - smoothstep(0.0, 0.40, progress)
	_halo(canvas, ground_line, minf(radius, 64.0), color, flash)
	_flare(canvas, ground_line, radius * 0.76, 0.0, color, flash)
	canvas.draw_line(left, right, Color(color.lightened(0.75), flash), 4.0, true)

	for side in [-1.0, 1.0]:
		var wave_pt := ground_line + Vector2(side * radius * lerpf(0.18, 1.15, spread), 0.0)
		canvas.draw_arc(wave_pt, 16.0 + 19.0 * spread, -PI * 0.86, -PI * 0.14, 20,
			Color(color, alpha_fade * 0.78), 7.0 * alpha_fade + 1.0, true)
		canvas.draw_arc(wave_pt, 16.0 + 19.0 * spread, -PI * 0.78, -PI * 0.22, 20,
			Color(color.lightened(0.7), alpha_fade), 2.5, true)

	# 2. Jagged earth rock spikes erupting from ground
	var spike_count := 9
	for i in range(spike_count):
		var frac := float(i) / float(spike_count - 1)
		var spike_x := lerpf(-radius * 0.9, radius * 0.9, frac)
		var root := ground_line + Vector2(spike_x, 0)
		var max_h := (22.0 + sin(frac * PI) * 26.0) * (0.7 + sin(progress * PI) * 0.5)
		var half_w := 6.0 + sin(frac * PI) * 4.0

		var spike_poly := PackedVector2Array([
			root + Vector2(-half_w, 0),
			root + Vector2(sin(float(i) * 1.7) * 3.0, -max_h),
			root + Vector2(half_w, 0)
		])
		canvas.draw_colored_polygon(spike_poly, ink)
		canvas.draw_polyline(spike_poly, Color("#ffffff", alpha_fade * 0.6), 1.5, true)

	# 3. Flying debris motes
	for debris_i in range(8):
		var d_angle := -PI * 0.85 + float(debris_i) * (PI * 0.7 / 7.0)
		var d_dist := (28.0 + float(debris_i % 3) * 23.0) * spread
		var d_pos := ground_line + Vector2.from_angle(d_angle) * d_dist
		canvas.draw_circle(d_pos, 2.5 * alpha_fade, Color(color.lightened(0.3), alpha_fade * 0.85))


static func _draw_ground_sprite(canvas: Node2D, at: Vector2, radius: float, progress: float,
		texture: Texture2D, effect: Dictionary) -> void:
	var frame_count := int(effect.frames)
	var columns := int(effect.columns)
	var frame := clampi(floori(progress * frame_count), 0, frame_count - 1)
	var cell := Vector2(frame % columns, floori(float(frame) / columns)) * Bestiary.vector(effect.cell)
	var frame_region := Bestiary.rectangle(effect.frame)
	var source := Rect2(frame_region.position + cell, frame_region.size)
	var width := radius * 2.0
	var growth := lerpf(0.68, 1.0, smoothstep(0.0, 0.23, progress))
	var height := width * frame_region.size.y / frame_region.size.x * growth
	var tint := Color(1.0, 1.0, 1.0, 1.0 - smoothstep(0.73, 1.0, progress))
	canvas.draw_texture_rect_region(texture, Rect2(at.x - radius, at.y - height, width, height), source, tint)


static func pollen(canvas: Node2D, extent: float, progress: float) -> void:
	var color: Color = COLORS.wood
	var fade := 1.0 - smoothstep(0.14, 1.0, progress)
	var spread := 1.0 - pow(1.0 - progress, 3.0)
	_flare(canvas, Vector2(0, 12), 38.0, PI * 0.5, color, 1.0 - smoothstep(0.0, 0.42, progress))
	for i in range(22):
		var depth := float(i) / 21.0
		var at := Vector2(sin(i * 4.9) * extent * spread * lerpf(0.25, 1.0, depth), (12.0 + depth * 108.0) * spread)
		_halo(canvas, at, 9.0 + i % 4, color, fade * 0.58)
		canvas.draw_circle(at, 2.5 + i % 3, Color(color.lightened(0.5), fade * 0.86), true, -1, true)
