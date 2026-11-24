extends Node2D

const FLOOR_Y := 540.0
const EquipmentChest := preload("res://assets/environment/common/props/equipment_chest.gd")

@export var shrine_flame_height := 29.0

var time := 0.0
var portal_open := false
var cache_open := false
var effects: Node2D

var campfires: Array[Node2D] = []
var portals: Array[Node2D] = []
var reliquaries: Array[Node2D] = []
var light_gates: Array[StaticBody2D] = []
var equipment_chests: Array[EquipmentChest] = []


func _ready() -> void:
	for child in get_children():
		if child is TileMapLayer and child.is_in_group("prop_tiles"):
			_collect_props(child)
	campfires.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.x < b.global_position.x or (
			a.global_position.x == b.global_position.x and a.global_position.y < b.global_position.y))

	effects = Node2D.new()
	effects.draw.connect(_draw_effects)
	add_child(effects)


func _collect_props(layer: TileMapLayer) -> void:
	# Scene tiles normally instantiate at the end of the frame. The level needs its spawn point in _ready().
	layer.update_internals()
	for prop in layer.get_children(true):
		if prop.is_in_group("campfire"):
			campfires.append(prop)
		elif prop.is_in_group("portal"):
			portals.append(prop)
		elif prop.is_in_group("reliquary"):
			reliquaries.append(prop)
		elif prop.is_in_group("light_gate"):
			light_gates.append(prop)
		elif prop is EquipmentChest:
			equipment_chests.append(prop)


func _process(delta: float) -> void:
	time += delta
	effects.queue_redraw()


func _draw_effects() -> void:
	for portal in portals:
		_draw_portal(to_local(portal.global_position))
	for campfire in campfires:
		_draw_shrine(to_local(campfire.global_position))
	for cache in reliquaries:
		cache.get_node("Sprite").modulate = Color("#7d9189") if cache_open else Color.WHITE
		if not cache_open:
			effects.draw_circle(to_local(cache.global_position) + Vector2(0, -22), 6 + sin(time * 3.0),
				Color(1.0, 0.75, 0.36, 0.22))
	_draw_motes()


func _draw_portal(ground: Vector2) -> void:
	var p := ground + Vector2(0, -60)
	var glow := Color("#98ead0") if portal_open else Color("#bda370")
	if portal_open:
		for i in range(4, 0, -1):
			effects.draw_circle(p, i * 13.0, Color(glow, 0.06))
	for i in range(4):
		var y := p.y + sin(time * 1.6 + i) * 31
		effects.draw_circle(Vector2(p.x + cos(time + i * 1.4) * 19, y), 2.5, glow)


func _draw_shrine(ground: Vector2) -> void:
	var flame := ground - Vector2(0, shrine_flame_height)
	for i in range(4, 0, -1):
		effects.draw_circle(flame, i * 13.0, Color(0.92, 0.61, 0.25, 0.045))
	for i in range(5):
		var lifetime := fposmod(time * 0.88 + i * 0.2, 1.0)
		var ember := flame + Vector2(sin(time * 2.3 + i) * 8, -22.0 - lifetime * 27.0)
		effects.draw_circle(ember, 1.5, Color(1.0, 0.73, 0.30, 1.0 - lifetime))


func _draw_motes() -> void:
	for i in range(63):
		var x := fposmod(float(i * 137) + time * (9 + i % 12), 3350.0)
		var y := 175.0 + sin(i * 4.0 + time * 0.48) * 100.0 + (i % 7) * 30.0
		var opacity := 0.12 + (sin(time * 1.7 + i) + 1.0) * 0.17
		effects.draw_circle(Vector2(x, y), 1.0 + i % 3 * 0.4, Color(0.85, 0.92, 0.68, opacity))
