extends CharacterBody2D

signal attacked(origin: Vector2, facing: float, ranged: bool, damage: int)
signal cast(origin: Vector2, direction: float)
signal defeated

const HunterAnimation := preload("res://scripts/hunter_animation.gd")
const RUN_SPEED := 250.0
const WALK_SPEED := 115.0
const CROUCH_SPEED := 64.0
const KNIFE_DURATION := 0.29
const BOW_DURATION := 0.39
const ATTACK_BUFFER := 0.22
const LAND_DURATION := 0.15
const HURT_DURATION := 0.23
const STANDING_HEIGHT := 48.0
const CROUCH_HEIGHT := 28.0
const GLIDE_SPEED := 337.0
const GRAVITY := 1530.0
const JUMP_SPEED := 525.0
const MAX_HEALTH := 6
const MAX_MANA := 4
const STAFF_DURATION := 0.54

var health := MAX_HEALTH
var mana := MAX_MANA
var facing := 1.0
var with_bow := false
var with_staff := false
var staff_unlocked := false
var gear: Dictionary = {}
var vest_ready := false
var pollen_left := 0.0
var equipped_soul := ""
var knife_level := 0
var bow_level := 0
var stolen_blade := false
var gliding := false
var attack_left := 0.0
var attack_buffer_left := 0.0
var invincible_left := 0.0
var crouching := false
var walking := false
var crouch_time := 0.0
var rise_left := 0.0
var landing_left := 0.0
var hurt_left := 0.0
var attack_queued := false
var attack_with_bow := false
var attack_with_staff := false
var attack_duration := KNIFE_DURATION
var collider: CollisionShape2D
var animation_time := 0.0
var wall_holding := false
var jump_grace := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, STANDING_HEIGHT)
	collider = CollisionShape2D.new()
	collider.shape = shape
	collider.position.y = -STANDING_HEIGHT / 2.0
	add_child(collider)


func _input(event: InputEvent) -> void:
	if is_physics_processing() and health > 0 and event.is_action_pressed("hunt_attack"):
		attack_buffer_left = ATTACK_BUFFER


func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	attack_left = maxf(attack_left - delta, 0)
	attack_buffer_left = maxf(attack_buffer_left - delta, 0)
	landing_left = maxf(landing_left - delta, 0)
	rise_left = maxf(rise_left - delta, 0)
	hurt_left = maxf(hurt_left - delta, 0)
	pollen_left = maxf(pollen_left - delta, 0)
	var grounded := is_on_floor()
	_update_crouch(grounded and Input.is_action_pressed("hunt_crouch"))
	crouch_time = crouch_time + delta if crouching else 0.0
	walking = Input.is_action_pressed("hunt_walk")
	invincible_left = maxf(invincible_left - delta, 0)
	jump_grace = 0.08 if is_on_floor() else maxf(jump_grace - delta, 0)
	var direction := Input.get_axis("hunt_left", "hunt_right")
	if direction != 0:
		facing = signf(direction)

	wall_holding = (
		equipped_soul == "spider" and Input.is_action_pressed("hunt_soul")
		and is_on_wall_only() and direction != 0
	)
	if wall_holding:
		velocity.y = -135.0
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, 950.0)

	var jumped := Input.is_action_just_pressed("hunt_jump")
	if jumped and not crouching and (jump_grace > 0.0 or wall_holding):
		velocity.y = -JUMP_SPEED
		jump_grace = 0.0
		wall_holding = false

	gliding = (
		equipped_soul == "lizard" and Input.is_action_pressed("hunt_soul")
		and not is_on_floor() and velocity.y > 0
	)
	if gliding:
		velocity.y = minf(velocity.y, 58.0)

	var speed := WALK_SPEED if walking else RUN_SPEED
	if gliding:
		speed = GLIDE_SPEED
	elif crouching:
		speed = CROUCH_SPEED
	if pollen_left > 0:
		speed *= 0.64
	velocity.x = move_toward(velocity.x, direction * speed, 2100.0 * delta)
	var fall_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not grounded and fall_speed > 245.0:
		landing_left = LAND_DURATION
	animation_time += delta
	if Input.is_action_just_pressed("hunt_switch"):
		if with_staff:
			select_weapon("hunter_knife")
		elif with_bow:
			select_weapon("ember_staff" if staff_unlocked else "hunter_knife")
		else:
			select_weapon("hunter_bow")
	var wants_attack := attack_buffer_left > 0 or Input.is_action_pressed("hunt_attack")
	if wants_attack and attack_left <= 0 and hurt_left <= 0 and (not with_staff or mana > 0):
		attack_buffer_left = 0.0
		attack_with_bow = with_bow
		attack_with_staff = with_staff
		attack_duration = KNIFE_DURATION
		if with_bow:
			attack_duration = BOW_DURATION
		elif with_staff:
			attack_duration = STAFF_DURATION
		elif gear.get("手部") == "hunter_wraps":
			attack_duration = 0.23
		attack_left = attack_duration
		attack_queued = true
	var hit_at := attack_duration * (1.0 - float(HunterAnimation.BOW_RELEASE_FRAME) / HunterAnimation.FRAME_COUNT) if attack_with_bow else attack_duration * 0.74
	if attack_queued and attack_left <= hit_at:
		attack_queued = false
		if attack_with_staff:
			mana -= 1
			cast.emit(position + Vector2(facing * 22, -37), facing)
		else:
			var damage := 1 + bow_level if attack_with_bow else 2 + knife_level + int(stolen_blade)
			var height := 21.0 if crouching else 30.0
			var origin := HunterAnimation.bow_origin(facing) if attack_with_bow else Vector2(facing * 14, -height)
			attacked.emit(position + origin, facing, attack_with_bow, damage)
	queue_redraw()


func _update_crouch(requested: bool, force_stand: bool = false) -> void:
	if requested == crouching:
		return
	var height := CROUCH_HEIGHT if requested else STANDING_HEIGHT
	if not requested and not force_stand:
		var clearance := RectangleShape2D.new()
		clearance.size = Vector2(23, STANDING_HEIGHT - CROUCH_HEIGHT)
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = clearance
		query.transform = Transform2D(0.0, global_position - Vector2(0, (STANDING_HEIGHT + CROUCH_HEIGHT) / 2.0))
		query.collision_mask = collision_mask
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return
	var shape := collider.shape as RectangleShape2D
	shape.size.y = height
	collider.position.y = -height / 2.0
	crouching = requested
	if not requested and not force_stand:
		rise_left = 0.08


func hurt(source_x: float) -> void:
	if invincible_left > 0 or health <= 0:
		return
	if vest_ready and gear.get("身體") == "moss_vest":
		vest_ready = false
		invincible_left = 0.45
		return
	health -= 1
	if health == 0:
		defeated.emit()
		return
	invincible_left = 0.9
	hurt_left = HURT_DURATION
	attack_left = 0.0
	attack_buffer_left = 0.0
	attack_queued = false
	velocity = Vector2(signf(position.x - source_x) * 270, -240)


func max_health() -> int:
	return MAX_HEALTH + int(gear.get("頭部") == "linen_hood")


func rest() -> void:
	health = max_health()
	mana = MAX_MANA
	vest_ready = gear.get("身體") == "moss_vest"
	pollen_left = 0.0


func apply_pollen() -> void:
	pollen_left = 1.2 if gear.get("頭部") == "scaleveil_hood" else 2.4


func select_weapon(id: String) -> void:
	with_staff = id == "ember_staff" and staff_unlocked
	with_bow = id == "hunter_bow"


func selected_weapon() -> String:
	if with_staff:
		return "ember_staff"
	return "hunter_bow" if with_bow else "hunter_knife"


func respawn(at: Vector2) -> void:
	position = at
	_update_crouch(false, true)
	landing_left = 0.0
	rise_left = 0.0
	hurt_left = 0.0
	attack_left = 0.0
	attack_buffer_left = 0.0
	attack_queued = false
	velocity = Vector2.ZERO
	rest()
	invincible_left = 0.9
	jump_grace = 0.0
	gliding = false
	wall_holding = false


func _draw() -> void:
	if invincible_left > 0 and hurt_left <= 0 and int(invincible_left * 16) % 2 == 0:
		return

	var action := "idle"
	var frame := int(animation_time * 5) % HunterAnimation.FRAME_COUNT
	if hurt_left > 0:
		action = "hurt"
		frame = _timed_frame(hurt_left, HURT_DURATION)
	elif attack_left > 0:
		if not attack_with_staff:
			action = "bow_attack" if attack_with_bow else "knife_attack"
		frame = _timed_frame(attack_left, attack_duration)
	elif gliding:
		action = "glide"
		frame = int(animation_time * 9) % HunterAnimation.FRAME_COUNT
	elif not is_on_floor():
		action = "jump"
		if velocity.y < -385:
			frame = 0
		elif velocity.y < -85:
			frame = 1
		elif velocity.y < 135:
			frame = 2
		else:
			frame = 3
	elif crouching:
		action = "crouch"
		frame = 0 if crouch_time < 0.08 else (2 if absf(velocity.x) > 12 else 1)
	elif rise_left > 0:
		action = "crouch"
		frame = 3
	elif landing_left > 0:
		action = "land"
		frame = _timed_frame(landing_left, LAND_DURATION)
	elif absf(velocity.x) > 18:
		action = "walk" if walking else "run"
		frame = int(animation_time * (9 if walking else 14)) % HunterAnimation.FRAME_COUNT
	HunterAnimation.draw_frame(self, action, frame, facing)
	if with_staff or (attack_with_staff and attack_left > 0):
		var grip := Vector2(facing * 11, -24)
		var tip := grip + Vector2(facing * 12, -22)
		draw_line(grip + Vector2(-facing * 5, 17), tip, Color("#93583c"), 3, true)
		draw_circle(tip, 4, Color("#ffc779"))
		if attack_with_staff and attack_left > 0:
			draw_circle(tip, 10, Color(1.0, 0.50, 0.16, 0.28))


func _timed_frame(remaining: float, duration: float) -> int:
	return clampi(int((1.0 - remaining / duration) * HunterAnimation.FRAME_COUNT), 0, HunterAnimation.FRAME_COUNT - 1)
