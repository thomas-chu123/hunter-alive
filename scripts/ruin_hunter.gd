extends CharacterBody2D

signal attacked(origin: Vector2, facing: float, ranged: bool, damage: int)
signal defeated

const WALK_SPEED := 250.0
const GLIDE_SPEED := 337.0
const GRAVITY := 1530.0
const JUMP_SPEED := 525.0
const MAX_HEALTH := 6

var health := MAX_HEALTH
var facing := 1.0
var with_bow := false
var equipped_soul := ""
var knife_level := 0
var bow_level := 0
var stolen_blade := false
var gliding := false
var attack_left := 0.0
var invincible_left := 0.0
var step_phase := 0.0
var wall_holding := false
var jump_grace := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 48)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position.y = -24
	add_child(collider)


func _physics_process(delta: float) -> void:
	if health <= 0:
		return

	attack_left = maxf(attack_left - delta, 0)
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
	if jumped and (jump_grace > 0.0 or wall_holding):
		velocity.y = -JUMP_SPEED
		jump_grace = 0.0
		wall_holding = false

	gliding = (
		equipped_soul == "lizard" and Input.is_action_pressed("hunt_soul")
		and not is_on_floor() and velocity.y > 0
	)
	if gliding:
		velocity.y = minf(velocity.y, 58.0)

	var speed := GLIDE_SPEED if gliding else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction * speed, 2100.0 * delta)
	move_and_slide()
	step_phase += absf(velocity.x) * delta * 0.062
	if Input.is_action_just_pressed("hunt_switch"):
		with_bow = not with_bow
	if Input.is_action_pressed("hunt_attack") and attack_left <= 0:
		attack_left = 0.39 if with_bow else 0.29
		var damage := 1 + bow_level if with_bow else 2 + knife_level + int(stolen_blade)
		attacked.emit(position + Vector2(facing * 14, -30), facing, with_bow, damage)
	queue_redraw()


func hurt(source_x: float) -> void:
	if invincible_left > 0 or health <= 0:
		return
	health -= 1
	if health == 0:
		defeated.emit()
		return
	invincible_left = 0.9
	velocity = Vector2(signf(position.x - source_x) * 270, -240)


func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	invincible_left = 0.9
	jump_grace = 0.0
	gliding = false
	wall_holding = false


func _draw() -> void:
	if invincible_left > 0 and int(invincible_left * 16) % 2 == 0:
		return

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	var swing := sin(step_phase) * 10.0 if is_on_floor() and absf(velocity.x) > 15 else 2.0
	var ink := Color("#16272a")
	var gold := Color("#d8b888")
	var cloth := Color("#b9603e")
	var mantle := Color("#d48654")
	if gliding:
		draw_colored_polygon(
			PackedVector2Array([Vector2(-44, -34), Vector2(0, -51), Vector2(38, -30),
				Vector2(16, -24), Vector2(-3, -29), Vector2(-23, -22)]),
			Color("#8cdec4")
		)
		draw_line(Vector2(-41, -34), Vector2(0, -49), Color("#d6f7c4"), 2, true)
	else:
		var cape_width := -22.0 - minf(absf(velocity.x) / 20.0, 11.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -48), Vector2(9, -40),
			Vector2(-10, -16), Vector2(cape_width, -9), Vector2(-20, -27)]), cloth)
		draw_line(Vector2(-11, -26), Vector2(cape_width, -10), mantle, 2, true)

	draw_line(Vector2(-7, -21), Vector2(-7 - swing, -3), ink, 8, true)
	draw_line(Vector2(5, -21), Vector2(8 + swing, -3), ink, 8, true)
	draw_line(Vector2(7 + swing, -3), Vector2(13 + swing, -3), gold, 2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -45), Vector2(10, -43),
		Vector2(14, -21), Vector2(-10, -20)]), Color("#3d5149"))
	draw_line(Vector2(-8, -24), Vector2(13, -25), gold, 3, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-15, -45), Vector2(-7, -60),
		Vector2(5, -62), Vector2(14, -53), Vector2(9, -43)]), cloth)
	draw_colored_polygon(PackedVector2Array([Vector2(3, -55), Vector2(14, -52),
		Vector2(9, -44), Vector2(2, -48)]), gold)
	draw_line(Vector2(-14, -45), Vector2(7, -59), mantle, 2, true)
	draw_line(Vector2(3, -39), Vector2(17, -32), ink, 6, true)

	if with_bow:
		draw_arc(Vector2(14, -33), 16, -1.05, 1.05, 14, gold, 3, true)
		draw_line(Vector2(22, -47), Vector2(22, -19), Color("#ece0bf"), 1, true)
	elif attack_left > 0.13:
		draw_arc(Vector2(17, -31), 39, -0.88, 0.68, 20, Color("#f8e8b9"), 3, true)
		draw_line(Vector2(12, -32), Vector2(36, -42), gold, 4, true)
	else:
		draw_line(Vector2(14, -32), Vector2(27, -25), gold, 3, true)
