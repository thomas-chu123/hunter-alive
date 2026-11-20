extends Node2D

const FLOOR_Y := 540.0
const STONES := [
	Rect2(40, 540, 272, 230),
	Rect2(720, 540, 2610, 230),
	Rect2(1075, 476, 137, 18),
	Rect2(1435, 449, 118, 18),
	Rect2(1740, 473, 145, 18),
	Rect2(1887, 412, 119, 18),
	Rect2(2005, 348, 434, 30),
	Rect2(2370, 496, 140, 20),
	Rect2(2500, 438, 124, 18),
	Rect2(3135, 465, 145, 75),
	Rect2(3290, 250, 40, 290),
	Rect2(20, 350, 20, 190),
]
const SHRINE_X := 885.0
const PORTAL_X := 122.0
const OVERLOOK := Vector2(2270, 348)

var time := 0.0
var portal_open := false
var cache_open := false
var rng := RandomNumberGenerator.new()
var effects: Node2D


func _ready() -> void:
	effects = Node2D.new()
	effects.draw.connect(_draw_effects)
	add_child(effects)


func _process(delta: float) -> void:
	time += delta
	effects.queue_redraw()


func _draw() -> void:
	rng.seed = 1622
	for x: int in [245, 773, 1095, 1525, 1752, 2140, 2425, 2680, 3070]:
		_draw_column(float(x))
	for bounds: Rect2 in STONES:
		_draw_ground(bounds)

	for x: int in [720, 734, 761, 782, 294, 311]:
		var length := rng.randf_range(50, 146)
		draw_polyline(PackedVector2Array([Vector2(x, FLOOR_Y), Vector2(x + 6, FLOOR_Y + length * 0.5),
			Vector2(x - 4, FLOOR_Y + length)]), Color("#294b40"), 2, true)

	draw_rect(Rect2(2005, 378, 434, 162), Color(0.06, 0.11, 0.13, 0.29))


func _draw_effects() -> void:
	_draw_portal()
	_draw_shrine()
	var lid := Color("#80988b") if cache_open else Color("#d5bb84")
	effects.draw_rect(Rect2(OVERLOOK + Vector2(-17, -21), Vector2(34, 21)), Color("#324240"))
	effects.draw_line(OVERLOOK + Vector2(-18, -22), OVERLOOK + Vector2(18, -22), lid, 3, true)
	_draw_motes()


func _draw_ground(rect: Rect2) -> void:
	draw_rect(rect, Color("#243637"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, minf(14, rect.size.y))), Color("#4e6460"))
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color("#8b9b6e"), 2, true)
	for row in range(int(ceilf(minf(rect.size.y, 140) / 24.0))):
		var offset := 31.0 if row % 2 else 0.0
		var y := rect.position.y + 12.0 + 24.0 * row
		if y >= rect.end.y:
			break
		for col in range(int(ceilf(rect.size.x / 62.0))):
			var x := rect.position.x + col * 62.0 - offset
			var left := maxf(rect.position.x, x + 1)
			var right := minf(rect.end.x, x + 61)
			var bottom := minf(rect.end.y, y + 21)
			if right <= left:
				continue
			var tone := rng.randf_range(0.0, 0.22)
			var pebble := Color("#203235").lerp(Color("#68827a"), tone)
			draw_colored_polygon(PackedVector2Array([Vector2(left, y + 3),
				Vector2(right - 2, y), Vector2(right, bottom - 2), Vector2(left + 1, bottom)]), pebble)

	for index in range(int(rect.size.x / 11.0)):
		var point := rect.position + Vector2(index * 11.0 + rng.randf_range(0, 8), 0)
		var height := rng.randf_range(2, 13)
		var moss := Color("#617d5a").lerp(Color("#a0ab73"), rng.randf())
		draw_colored_polygon(PackedVector2Array([point - Vector2(4, -2),
			point + Vector2(rng.randf_range(-7, 7), -height), point + Vector2(6, 1)]), moss)


func _draw_column(x: float) -> void:
	var top := FLOOR_Y - rng.randf_range(130, 265)
	var color := Color(0.20, 0.33, 0.34, 0.7)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 45, FLOOR_Y), Vector2(x - 27, top + 20),
		Vector2(x + 12, top), Vector2(x + 31, FLOOR_Y)]), color)
	for i in range(4):
		draw_line(Vector2(x - 20 + i * 11, top + 24), Vector2(x - 34 + i * 17, FLOOR_Y),
			color.lightened(0.14), 2, true)
	draw_rect(Rect2(x - 48, FLOOR_Y - 22, 84, 22), color)
	draw_rect(Rect2(x - 52, FLOOR_Y - 9, 94, 9), color.lightened(0.16))
	draw_polyline(PackedVector2Array([Vector2(x + 18, top + 6), Vector2(x + 29, top + 49),
		Vector2(x + 21, top + 107)]), Color("#62734d"), 3, true)


func _draw_portal() -> void:
	var p := Vector2(PORTAL_X, FLOOR_Y - 48)
	var ellipse := PackedVector2Array()
	for i in range(31):
		var angle := PI + PI * i / 30.0
		ellipse.append(p + Vector2(cos(angle) * 46, sin(angle) * 63))
	var glow := Color("#98ead0") if portal_open else Color("#bda370")
	var dark := Color("#293d3e")
	effects.draw_rect(Rect2(p.x - 53, p.y - 1, 14, 49), dark)
	effects.draw_rect(Rect2(p.x + 39, p.y - 1, 14, 49), dark)
	effects.draw_polyline(ellipse, dark, 16, true)
	effects.draw_polyline(ellipse, glow.darkened(0.36), 2, true)
	for i in range(4):
		var y := p.y + sin(time * 1.6 + i) * 31
		effects.draw_circle(Vector2(p.x + cos(time + i * 1.4) * 19, y), 2.5, glow)


func _draw_shrine() -> void:
	var p := Vector2(SHRINE_X, FLOOR_Y)
	effects.draw_colored_polygon(PackedVector2Array([p + Vector2(-30, 0), p + Vector2(-18, -14),
		p + Vector2(17, -14), p + Vector2(30, 0)]), Color("#4a4f42"))
	effects.draw_rect(Rect2(p + Vector2(-17, -30), Vector2(34, 16)), Color("#384949"))
	for i in range(4, 0, -1):
		effects.draw_circle(p + Vector2(0, -30), i * 13.0, Color(0.92, 0.61, 0.25, 0.035))
	var flicker := sin(time * 9.0) * 4.0
	effects.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -30), p + Vector2(-12, -41),
		p + Vector2(flicker, -56), p + Vector2(10, -38), p + Vector2(6, -30)]), Color("#f2a44e"))
	effects.draw_circle(p + Vector2(0, -35), 4, Color("#ffe4a0"))


func _draw_motes() -> void:
	for i in range(63):
		var x := fposmod(float(i * 137) + time * (9 + i % 12), 3350.0)
		var y := 175.0 + sin(i * 4.0 + time * 0.48) * 100.0 + (i % 7) * 30.0
		var opacity := 0.12 + (sin(time * 1.7 + i) + 1.0) * 0.17
		effects.draw_circle(Vector2(x, y), 1.0 + i % 3 * 0.4, Color(0.85, 0.92, 0.68, opacity))
