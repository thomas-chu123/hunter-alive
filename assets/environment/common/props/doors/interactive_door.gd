extends Node2D

const Hunter := preload("res://scripts/character/ruin_hunter.gd")
const HALF_WIDTH := 8.0
const LEAF_HALF_WIDTH := 24.0
const CLOSED_LEAF_SCALE := 0.125
const HEIGHT := 76.0
const REACH := 58.0
const SIGHT_DISTANCE := 4096.0

@export var door_name := "門"
@export var scene_exit := false
@export_enum("左開:-1", "右開:1") var opening_side: int = 1
@export var travel_time := 0.42

@onready var leaf: Sprite2D = $Leaf
@onready var collision: CollisionShape2D = $Body/Collision
@onready var occluder: LightOccluder2D = $Occluder
@onready var sight: Polygon2D = $Sight

var opened := false
var motion: Tween
var actor: Hunter


func _ready() -> void:
	leaf.flip_h = opening_side < 0
	$Frame.flip_h = leaf.flip_h


func can_reach(hunter: Hunter) -> bool:
	var offset := to_local(hunter.global_position)
	return absf(offset.x) <= REACH and absf(offset.y) <= 30.0


func toggle(hunter: Hunter, doorway_clear: Callable) -> Tween:
	if motion != null or hunter.door_action or (opened and not doorway_clear.call(self)):
		return null
	var opening := not opened
	var direction := -signf(to_local(hunter.global_position).x)
	actor = hunter
	hunter.begin_door_action(direction, opening)
	motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	motion.tween_method(_pose.bind(hunter, opening), 0.0, 1.0, travel_time)
	motion.tween_callback(_finish_motion.bind(hunter, opening, doorway_clear))
	return motion


func _pose(progress: float, hunter: Hunter, opening: bool) -> void:
	if is_instance_valid(hunter):
		hunter.set_door_action_progress(progress)
	_set_leaf(smoothstep(0.12, 0.9, progress) if opening else 1.0 - smoothstep(0.12, 0.9, progress))


func _set_leaf(amount: float) -> void:
	leaf.scale.x = lerpf(CLOSED_LEAF_SCALE, 0.88, amount)
	leaf.position.x = opening_side * LEAF_HALF_WIDTH * leaf.scale.x * amount


func _finish_motion(hunter: Hunter, opening: bool, doorway_clear: Callable) -> void:
	if is_instance_valid(hunter):
		hunter.end_door_action()
	actor = null
	if not opening and not doorway_clear.call(self):
		motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		motion.tween_method(_set_leaf, 0.0, 1.0, travel_time)
		motion.tween_callback(func() -> void: motion = null)
		return
	opened = opening
	collision.set_deferred("disabled", opened)
	occluder.visible = not opened
	if opened:
		sight.hide()
	motion = null


func update_sight(eye_world: Vector2) -> void:
	var eye := to_local(eye_world)
	sight.visible = not opened and absf(eye.x) > HALF_WIDTH
	if not sight.visible:
		return
	var away := -signf(eye.x)
	var edge := away * HALF_WIDTH
	var top := Vector2(edge, -HEIGHT)
	var bottom := Vector2(edge, 0)
	# Keep the post and moving leaf visible in front of their own sight mask.
	var visible_edge := maxf(HALF_WIDTH, away * leaf.position.x + LEAF_HALF_WIDTH * leaf.scale.x)
	var start := (away * visible_edge - eye.x) / (edge - eye.x)
	var finish := (away * SIGHT_DISTANCE - eye.x) / (edge - eye.x)
	sight.polygon = PackedVector2Array([
		eye.lerp(top, start), eye.lerp(bottom, start),
		eye.lerp(bottom, finish), eye.lerp(top, finish),
	])


func _exit_tree() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	if is_instance_valid(actor):
		actor.end_door_action()
