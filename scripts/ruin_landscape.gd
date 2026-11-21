extends Node2D

const FLOOR_Y := 540.0
const PORTAL_X := 122.0 # Default scene position for the smoke test.

var time := 0.0
var portal_open := false
var cache_open := false
var effects: Node2D

@onready var shrine: Node2D = $Props/Campfire
@onready var portal: Node2D = $Props/Portal
@onready var cache: Node2D = $Props/Reliquary
@onready var cache_sprite: Sprite2D = $Props/Reliquary/Sprite


func _ready() -> void:
	effects = Node2D.new()
	effects.draw.connect(_draw_effects)
	add_child(effects)


func _process(delta: float) -> void:
	time += delta
	effects.queue_redraw()


func _draw_effects() -> void:
	_draw_portal()
	_draw_shrine()
	cache_sprite.modulate = Color("#7d9189") if cache_open else Color.WHITE
	if not cache_open:
		effects.draw_circle(to_local(cache.global_position) + Vector2(0, -22), 6 + sin(time * 3.0),
			Color(1.0, 0.75, 0.36, 0.22))
	_draw_motes()


func _draw_portal() -> void:
	var ground := to_local(portal.global_position)
	var p := ground + Vector2(0, -60)
	var glow := Color("#98ead0") if portal_open else Color("#bda370")
	if portal_open:
		for i in range(4, 0, -1):
			effects.draw_circle(p, i * 13.0, Color(glow, 0.06))
	for i in range(4):
		var y := p.y + sin(time * 1.6 + i) * 31
		effects.draw_circle(Vector2(p.x + cos(time + i * 1.4) * 19, y), 2.5, glow)


func _draw_shrine() -> void:
	var p := to_local(shrine.global_position)
	for i in range(4, 0, -1):
		effects.draw_circle(p + Vector2(0, -29), i * 13.0, Color(0.92, 0.61, 0.25, 0.045))
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
