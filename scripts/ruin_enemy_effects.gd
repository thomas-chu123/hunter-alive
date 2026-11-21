extends RefCounted

const COLORS := {
	"metal": Color("#ffe7ab"), "wood": Color("#c6eb83"), "water": Color("#81e6ff"),
	"fire": Color("#ff8352"), "earth": Color("#e6aa73"),
}


static func charge(canvas: Node2D, at: Vector2, element: String, age: float) -> void:
	var color: Color = COLORS[element]
	var radius := 6.0 + (sin(age * 18.0) + 1.0) * 2.0
	canvas.draw_arc(at, radius, 0, TAU, 20, Color(color, 0.75), 2, true)
	canvas.draw_circle(at, 3, color)


static func sweep(canvas: Node2D, height: float, reach: float, facing: float,
		element: String, progress: float) -> void:
	var color: Color = COLORS[element]
	var middle := 0.0 if facing > 0 else PI
	var alpha := 0.48 + sin(progress * PI) * 0.44
	var pivot := Vector2(0, -height)
	var span := 0.5 if element == "metal" else 0.32
	canvas.draw_arc(pivot, reach, middle - span, middle + span, 24, Color(color, alpha), 3, true)
	canvas.draw_arc(pivot, reach * 0.83, middle - span, middle + span, 20, Color(color, alpha * 0.45), 2, true)
	if element == "wood" or element == "earth":
		for i in range(3):
			var angle := middle + (i - 1) * span * 0.55
			var edge := pivot + Vector2.from_angle(angle) * reach
			canvas.draw_line(edge, edge - Vector2.from_angle(angle + 0.46) * 16, color, 2, true)


static func bolt(canvas: Node2D, at: Vector2, direction: float, element: String,
		kind: String, radius: float) -> void:
	var color: Color = COLORS[element]
	var trail := Vector2(direction, 0)
	match element:
		"fire":
			canvas.draw_colored_polygon(PackedVector2Array([at + trail * radius, at + Vector2(0, -radius),
				at - trail * radius * 2.6, at + Vector2(0, radius)]), Color(color, 0.66))
			canvas.draw_circle(at, radius * 0.52, Color("#ffeca7"))
		"water":
			canvas.draw_line(at - trail * radius * 2.2, at, Color(color, 0.46), radius, true)
			canvas.draw_circle(at, radius * 0.74, Color(color, 0.78))
			canvas.draw_arc(at, radius, -1.2, 1.2, 18, color.lightened(0.5), 2, true)
			if kind == "spray":
				canvas.draw_circle(at - trail * 20 + Vector2(0, -12), 4, color)
				canvas.draw_circle(at - trail * 25 + Vector2(0, 10), 4, color)
		"wood":
			canvas.draw_line(at - trail * 31, at + trail * 6, color, 3, true)
			for y in [-1, 1]:
				canvas.draw_line(at + trail * 6, at - trail * 4 + Vector2(0, y * 5), color, 2, true)
				canvas.draw_line(at - trail * 17, at - trail * 30 + Vector2(0, y * 6), color, 2, true)
		"earth":
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-radius, -2),
				at + Vector2(-4, -radius), at + Vector2(9, -9), at + Vector2(radius, 4),
				at + Vector2(4, radius), at + Vector2(-9, 8)]), color)
			canvas.draw_line(at - Vector2(7, 0), at + Vector2(3, 7), color.darkened(0.45), 3, true)


static func ground(canvas: Node2D, at: Vector2, radius: float, element: String,
		active: bool, progress: float) -> void:
	var color: Color = COLORS[element]
	var ink := Color(color, 0.68 if active else 0.28 + absf(sin(progress * 11.0)) * 0.44)
	var floor := at - Vector2(0, 2)
	canvas.draw_line(floor - Vector2(radius, 0), floor + Vector2(radius, 0), ink, 3, true)
	for x in [-radius, radius]:
		canvas.draw_line(floor + Vector2(x, -10), floor + Vector2(x, 2), color, 2, true)
	if not active:
		return
	canvas.draw_rect(Rect2(at + Vector2(-radius, -24), Vector2(2 * radius, 24)), Color(color, 0.16))
	for i in range(7):
		var root := floor + Vector2(radius * (i - 3) * 0.30, 0)
		var height := (7.0 + i % 3 * 6.0) * (0.7 + sin(progress * PI) * 0.45)
		match element:
			"fire":
				canvas.draw_colored_polygon(PackedVector2Array([root + Vector2(-8, 0), root + Vector2(-3, -height),
					root + Vector2(1, -height * 0.77), root + Vector2(8, -height * 1.35), root + Vector2(10, 0)]), ink)
			"metal":
				canvas.draw_arc(root, 8 + height * 0.55, PI, TAU, 16, ink, 2, true)
			"earth":
				canvas.draw_colored_polygon(PackedVector2Array([root + Vector2(-9, 0),
					root + Vector2(3, -height), root + Vector2(9, 0)]), ink)


static func pollen(canvas: Node2D, progress: float) -> void:
	var color: Color = COLORS.wood
	for i in range(14):
		var at := Vector2(sin(i * 4.9) * (16.0 + 66.0 * progress), i * 7.5 + progress * 23.0)
		canvas.draw_circle(at, 2.5 + i % 3, Color(color, 0.82 * (1.0 - progress)))
