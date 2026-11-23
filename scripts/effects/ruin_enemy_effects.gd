extends RefCounted

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")

const COLORS := {
	"metal": Color("#ffe7ab"), "wood": Color("#c6eb83"), "water": Color("#81e6ff"),
	"fire": Color("#ff8352"), "earth": Color("#e6aa73"),
}


static func charge(canvas: Node2D, at: Vector2, element: String, age: float, heavy: bool = false) -> void:
	var color: Color = COLORS.get(element, Color("#ffe7ab"))
	var base_radius := 9.0 if heavy else 6.0
	var radius := base_radius + (sin(age * 22.0) + 1.0) * (3.5 if heavy else 2.0)

	# Inward converging danger motes (warning of incoming heavy strike)
	for i in range(8 if heavy else 4):
		var mote_prog := fposmod(age * 2.8 + float(i) * 0.25, 1.0)
		var mote_dist := (1.0 - mote_prog) * (38.0 if heavy else 22.0)
		var angle := float(i) * (TAU / (8.0 if heavy else 4.0)) + age * 1.5
		var pos := at + Vector2.from_angle(angle) * mote_dist
		canvas.draw_circle(pos, 1.8 * (1.0 - mote_prog), Color(color, (1.0 - mote_prog) * 0.8))

	# Outer glowing danger rings
	canvas.draw_arc(at, radius, 0, TAU, 24, Color(color, 0.85), 2.5 if heavy else 2.0, true)
	canvas.draw_arc(at, radius * 1.5, 0, TAU, 20, Color(color, 0.35), 1.5, true)
	canvas.draw_circle(at, (5.0 if heavy else 3.5), Color.WHITE.lerp(color, 0.4))

	# Danger starburst cross flare for heavy windup
	if heavy:
		var flare_len := 16.0 + sin(age * 28.0) * 4.0
		for dir_angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			var tip := at + Vector2.from_angle(dir_angle) * flare_len
			canvas.draw_line(at, tip, Color("#ffffff", 0.9), 1.8, true)


static func sweep(canvas: Node2D, height: float, reach: float, facing: float,
		element: String, progress: float, heavy: bool = false, kind: String = "") -> void:
	var color: Color = COLORS.get(element, Color("#ffe7ab"))
	var middle := 0.0 if facing > 0 else PI
	var alpha := 0.65 + sin(progress * PI) * 0.35
	var pivot := Vector2(0, -height)
	var span := 0.65 if heavy else (0.50 if element == "metal" else 0.36)
	var outer_reach := reach * (1.35 if heavy else 1.0)

	# Main sweep arc polygon (crescent blade wave)
	var outer_arc := PackedVector2Array()
	var inner_arc := PackedVector2Array()
	var segments := 20 if heavy else 14
	var sweep_start := middle - span
	var sweep_end := middle + span
	for i in range(segments):
		var frac := float(i) / float(segments - 1)
		var current_angle := lerpf(sweep_start, sweep_end, frac)
		var bell := sin(frac * PI)
		var thick := (18.0 if heavy else 9.0) * bell * (1.0 - progress * 0.6)
		var dir_vec := Vector2.from_angle(current_angle)
		outer_arc.append(pivot + dir_vec * (outer_reach + thick * 0.5))
		if i > 0 and i < segments - 1:
			inner_arc.append(pivot + dir_vec * (outer_reach - thick * 0.5))

	inner_arc.reverse()
	outer_arc.append_array(inner_arc)
	canvas.draw_colored_polygon(outer_arc, Color(color, alpha * (0.65 if heavy else 0.45)))

	# Sharp cutting edge
	var edge_lines := PackedVector2Array()
	for i in range(segments):
		var frac := float(i) / float(segments - 1)
		var current_angle := lerpf(sweep_start, sweep_end, frac)
		edge_lines.append(pivot + Vector2.from_angle(current_angle) * outer_reach)
	canvas.draw_polyline(edge_lines, Color("#ffffff", alpha * 0.95), (3.0 if heavy else 2.0), true)

	# Triple beast claw lacerations for heavy or beast-like attacks
	var is_claw := heavy or kind in ["ram", "slam", "crush", "claw", "swipe", "bite"]
	if is_claw:
		for claw_idx in [-1, 1]:
			var claw_reach := outer_reach + float(claw_idx) * (14.0 if heavy else 9.0)
			var claw_arc := PackedVector2Array()
			for i in range(12):
				var frac := float(i) / 11.0
				var current_angle := lerpf(sweep_start + 0.1 * claw_idx, sweep_end + 0.1 * claw_idx, frac)
				claw_arc.append(pivot + Vector2.from_angle(current_angle) * claw_reach)
			canvas.draw_polyline(claw_arc, Color(color, alpha * 0.75), 1.8, true)

		# Flying impact energy motes along the swing
		for spark_i in range(5):
			var spark_prog := fposmod(progress * 1.8 + float(spark_i) * 0.22, 1.0)
			var spark_ang := lerpf(sweep_start, sweep_end, spark_prog)
			var spark_pos := pivot + Vector2.from_angle(spark_ang) * (outer_reach + float(spark_i % 3) * 6.0)
			canvas.draw_circle(spark_pos, 2.2 * (1.0 - progress), Color(1.0, 0.95, 0.75, alpha * 0.9))


static func bolt(canvas: Node2D, at: Vector2, direction: float, element: String,
		kind: String, radius: float) -> void:
	var color: Color = COLORS.get(element, Color("#ffe7ab"))
	var trail := Vector2(direction, 0)
	match element:
		"fire":
			canvas.draw_colored_polygon(PackedVector2Array([at + trail * radius * 1.3, at + Vector2(0, -radius * 1.2),
				at - trail * radius * 3.2, at + Vector2(0, radius * 1.2)]), Color(color, 0.75))
			canvas.draw_circle(at, radius * 0.65, Color("#ffffff"))
			canvas.draw_arc(at, radius * 1.1, 0, TAU, 16, Color(1.0, 0.7, 0.2, 0.8), 2.0, true)
		"water":
			canvas.draw_line(at - trail * radius * 2.5, at, Color(color, 0.55), radius * 1.2, true)
			canvas.draw_circle(at, radius * 0.8, Color(color, 0.85))
			canvas.draw_arc(at, radius * 1.1, -1.2, 1.2, 18, color.lightened(0.6), 2.5, true)
			if kind == "spray":
				canvas.draw_circle(at - trail * 22 + Vector2(0, -14), 5, color)
				canvas.draw_circle(at - trail * 28 + Vector2(0, 12), 5, color)
		"wood":
			canvas.draw_line(at - trail * 35, at + trail * 8, color, 3.5, true)
			for y in [-1, 1]:
				canvas.draw_line(at + trail * 8, at - trail * 5 + Vector2(0, y * 6), color, 2.5, true)
				canvas.draw_line(at - trail * 19, at - trail * 33 + Vector2(0, y * 7), color, 2.5, true)
		"earth":
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-radius, -3),
				at + Vector2(-5, -radius), at + Vector2(10, -10), at + Vector2(radius * 1.2, 5),
				at + Vector2(5, radius * 1.1), at + Vector2(-10, 9)]), color)
			canvas.draw_line(at - Vector2(8, 0), at + Vector2(4, 8), color.darkened(0.5), 3.5, true)


static func ground(canvas: Node2D, at: Vector2, radius: float, element: String,
		active: bool, progress: float, texture: Texture2D, effect: Dictionary, heavy: bool = true) -> void:
	if active and texture != null:
		_draw_ground_sprite(canvas, at, radius, progress, texture, effect)

	var color: Color = COLORS.get(element, Color("#e6aa73"))
	var ink := Color(color, 0.85 if active else 0.35 + absf(sin(progress * 11.0)) * 0.45)
	var ground_line := at - Vector2(0, 2)

	# Fissure line on the ground
	canvas.draw_line(ground_line - Vector2(radius * 1.2, 0), ground_line + Vector2(radius * 1.2, 0), ink, 4.0 if heavy else 3.0, true)

	if not active:
		# Telegraph warning zone before smash
		for x in [-radius, radius]:
			canvas.draw_line(ground_line + Vector2(x, -14), ground_line + Vector2(x, 2), color, 2.5, true)
		return

	# ACTIVE HEAVY GROUND SMASH: Dual shockwaves, Jagged rock spikes & flying debris
	var shock_dist := radius * (0.3 + 0.9 * sin(progress * PI * 0.5))
	var alpha_fade := 1.0 - progress

	# 1. Dual expanding ground shockwave arcs
	for side in [-1.0, 1.0]:
		var wave_pt := ground_line + Vector2(side * shock_dist, 0)
		canvas.draw_arc(wave_pt, 18.0 * (1.0 - alpha_fade * 0.3), -PI * 0.8, -PI * 0.2, 16, Color(color, alpha_fade * 0.8), 3.0, true)
		canvas.draw_line(wave_pt + Vector2(0, -12), wave_pt + Vector2(0, 2), Color("#ffffff", alpha_fade * 0.9), 2.0, true)

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
		var d_dist := (18.0 + float(debris_i % 3) * 14.0) * sin(progress * PI)
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


static func pollen(canvas: Node2D, progress: float) -> void:
	var color: Color = COLORS.wood
	for i in range(18):
		var at := Vector2(sin(i * 4.9) * (18.0 + 75.0 * progress), i * 7.5 + progress * 26.0)
		canvas.draw_circle(at, 3.0 + i % 3, Color(color, 0.85 * (1.0 - progress)))
