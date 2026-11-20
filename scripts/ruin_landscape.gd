extends Node2D

const MOSS_STONE := preload("res://assets/environment/ruins/moss_stone.png")
const CRACKED_SANDSTONE := preload("res://assets/environment/ruins/cracked_sandstone.png")
const ROOT_STONE := preload("res://assets/environment/ruins/root_stone.png")
const CARVED_STONE := preload("res://assets/environment/ruins/carved_stone.png")
const MOSS_LEDGE := preload("res://assets/environment/ruins/moss_ledge.png")
const ROOT_LEDGE := preload("res://assets/environment/ruins/root_ledge.png")
const BROKEN_COLUMN := preload("res://assets/environment/ruins/broken_column.png")
const FERN := preload("res://assets/environment/ruins/fern.png")
const BRAZIER := preload("res://assets/environment/ruins/brazier.png")
const STONE_GATE := preload("res://assets/environment/ruins/stone_gate.png")
const RELIQUARY := preload("res://assets/environment/ruins/reliquary.png")

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
var effects: Node2D


func _ready() -> void:
	effects = Node2D.new()
	effects.draw.connect(_draw_effects)
	add_child(effects)


func _process(delta: float) -> void:
	time += delta
	effects.queue_redraw()


func _draw() -> void:
	for x: int in [246, 791, 1130, 1519, 1792, 2498, 2702, 3074]:
		var height := 120.0 + float(x % 71)
		_draw_prop(self, BROKEN_COLUMN, Vector2(x, FLOOR_Y), height, Color("#93aaa1"))

	var eaves := PackedVector2Array([
		Vector2(2005, 368), Vector2(2439, 368),
		Vector2(2412, 489), Vector2(2032, 489),
	])
	var shadow := Color(0.06, 0.11, 0.13, 0.30)
	draw_polygon(eaves, PackedColorArray([shadow, shadow, Color.TRANSPARENT, Color.TRANSPARENT]))
	for bounds: Rect2 in STONES:
		_draw_ground(bounds)

	for x: int in [301, 734, 1390, 1660, 1970, 2453, 2777, 3210]:
		var height := 34.0 + float(x % 19)
		_draw_prop(self, FERN, Vector2(x, FLOOR_Y + height * 0.34), height, Color("#9cac7e"))
	_draw_prop(self, FERN, Vector2(2411, OVERLOOK.y + 12), 36.0, Color("#b1bf89"))


func _draw_ground(bounds: Rect2) -> void:
	if bounds.size.x <= 40:
		draw_texture_rect(BROKEN_COLUMN, bounds, false, Color("#abb6a4"))
		return

	if bounds.size.y <= 30:
		var ledge := ROOT_LEDGE if int(bounds.position.x) % 3 == 0 else MOSS_LEDGE
		var count := ceili(bounds.size.x / 148.0)
		var width := bounds.size.x / count
		for index in range(count):
			var at := bounds.position + Vector2(width * index, -1)
			var overlap := 3.0 if index < count - 1 else 0.0
			draw_texture_rect(ledge, Rect2(at, Vector2(width + overlap, maxf(26, bounds.size.y + 7))),
				false, Color("#ced5b5"))
		return

	draw_rect(bounds, Color("#1d2b2b"))
	var columns := ceili(bounds.size.x / 123.0)
	var rows := ceili(bounds.size.y / 62.0)
	var width := bounds.size.x / columns
	var height := bounds.size.y / rows
	for row in range(rows):
		for column in range(columns):
			var at := bounds.position + Vector2(column * width, row * height)
			var tile := _stone_variant(at.x, column + row * 3)
			var shade := Color("#ccd6b4").darkened(row * 0.19)
			draw_texture_rect(tile, Rect2(at, Vector2(width, height)), false, shade)


func _stone_variant(x: float, index: int) -> Texture2D:
	if x > 2490:
		return CARVED_STONE if index % 3 == 0 else ROOT_STONE
	if x > 1950 and x < 2460:
		return ROOT_STONE if index % 3 != 0 else MOSS_STONE
	if x < 315:
		return CARVED_STONE if index % 2 == 0 else MOSS_STONE
	return CRACKED_SANDSTONE if index % 5 == 3 else MOSS_STONE


func _draw_prop(canvas: Node2D, texture: Texture2D, ground: Vector2,
		height: float, tint: Color = Color.WHITE) -> void:
	var width := height * texture.get_width() / texture.get_height()
	canvas.draw_texture_rect(texture, Rect2(ground - Vector2(width * 0.5, height),
		Vector2(width, height)), false, tint)


func _draw_effects() -> void:
	_draw_portal()
	_draw_shrine()
	_draw_prop(effects, RELIQUARY, OVERLOOK, 31.0,
		Color("#7d9189") if cache_open else Color.WHITE)
	if not cache_open:
		effects.draw_circle(OVERLOOK + Vector2(0, -22), 6 + sin(time * 3.0),
			Color(1.0, 0.75, 0.36, 0.22))
	_draw_motes()


func _draw_portal() -> void:
	var ground := Vector2(PORTAL_X, FLOOR_Y)
	var p := ground + Vector2(0, -60)
	var glow := Color("#98ead0") if portal_open else Color("#bda370")
	if portal_open:
		for i in range(4, 0, -1):
			effects.draw_circle(p, i * 13.0, Color(glow, 0.06))
	_draw_prop(effects, STONE_GATE, ground, 136.0)
	for i in range(4):
		var y := p.y + sin(time * 1.6 + i) * 31
		effects.draw_circle(Vector2(p.x + cos(time + i * 1.4) * 19, y), 2.5, glow)


func _draw_shrine() -> void:
	var p := Vector2(SHRINE_X, FLOOR_Y)
	for i in range(4, 0, -1):
		effects.draw_circle(p + Vector2(0, -29), i * 13.0, Color(0.92, 0.61, 0.25, 0.045))
	_draw_prop(effects, BRAZIER, p, 57.0)
	for i in range(5):
		var lifetime := fposmod(time * 0.88 + i * 0.2, 1.0)
		var ember := p + Vector2(sin(time * 2.3 + i) * 8, -51.0 - lifetime * 27.0)
		effects.draw_circle(ember, 1.5, Color(1.0, 0.73, 0.30, 1.0 - lifetime))


func _draw_motes() -> void:
	for i in range(63):
		var x := fposmod(float(i * 137) + time * (9 + i % 12), 3350.0)
		var y := 175.0 + sin(i * 4.0 + time * 0.48) * 100.0 + (i % 7) * 30.0
		var opacity := 0.12 + (sin(time * 1.7 + i) + 1.0) * 0.17
		effects.draw_circle(Vector2(x, y), 1.0 + i % 3 * 0.4, Color(0.85, 0.92, 0.68, opacity))
