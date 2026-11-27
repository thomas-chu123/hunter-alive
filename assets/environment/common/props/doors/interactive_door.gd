extends Node2D

const Hunter := preload("res://scripts/character/ruin_hunter.gd")
const HALF_WIDTH := 8.0
const LEAF_HALF_WIDTH := 24.0
const CLOSED_LEAF_SCALE := 0.125
const HEIGHT := 76.0
const REACH := 58.0
const DoorSight := preload("res://assets/environment/common/props/doors/door_sight.gd")

@export var door_name := "門"
@export var scene_exit := false
@export_enum("左開:-1", "右開:1") var opening_side: int = 1
@export var travel_time := 0.42

@onready var leaf: Sprite2D = $Leaf
@onready var collision: CollisionShape2D = $Body/Collision
@onready var occluder: LightOccluder2D = $Occluder
@onready var sight: DoorSight = $Sight

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
	if opened:
		sight.hide()
		return
	var eye := to_local(eye_world)
	var start_depth := 0.0
	if motion != null:
		# Leave clearance for the leaf while it sweeps across the doorway.
		start_depth = maxf(0.0, -signf(eye.x) * leaf.position.x + LEAF_HALF_WIDTH * leaf.scale.x)
	sight.project(eye_world, start_depth)


func _exit_tree() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	if is_instance_valid(actor):
		actor.end_door_action()
