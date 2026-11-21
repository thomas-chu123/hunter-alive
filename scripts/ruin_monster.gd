extends CharacterBody2D

signal felled(monster: Node2D)
signal disarmed(monster: Node2D)
signal launched(origin: Vector2, direction: float, effect: String)

const Bestiary := preload("res://scripts/ruin_bestiary.gd")
const Art := preload("res://scripts/ruin_sprite_art.gd")
const COLORS := {"spider": Color("#ae745d"), "lizard": Color("#77c6ad"), "treant": Color("#d5a56d")}
const HP := {"spider": 5, "lizard": 6, "treant": 20, "bell_moth": 6, "lantern_crab": 9, "seal_keeper": 26}
const SIZE := {"spider": Vector2(76, 55), "lizard": Vector2(92, 70), "treant": Vector2(110, 120),
	"bell_moth": Vector2(64, 49), "lantern_crab": Vector2(97, 60), "seal_keeper": Vector2(102, 136)}
const ART_ROWS := {"spider": 0, "lizard": 1, "treant": 2}
const ART_SCALES := {"spider": 0.30, "lizard": 0.33, "treant": 0.46}
enum State { PATROL, CHASE, WINDUP, STRIKE, RECOVER, RETURN }
enum MothPose { HOVER, WINDUP, POLLEN, RECOVER }

const GRAVITY := 1380.0
const PROFILES := {
	"spider": {"speed": 148.0, "sight": 390.0, "leash": 575.0, "jump": 545.0,
		"reach": 112.0, "tell": 0.32, "strike": 0.46, "recover": 0.47},
	"lizard": {"speed": 126.0, "sight": 445.0, "leash": 660.0, "jump": 615.0,
		"reach": 188.0, "tell": 0.43, "strike": 0.59, "recover": 0.67},
	"treant": {"speed": 96.0, "sight": 480.0, "leash": 510.0, "jump": 0.0,
		"reach": 148.0, "tell": 0.78, "strike": 0.34, "recover": 0.92},
	"bell_moth": {"tell": 0.95, "strike": 0.58, "recover": 1.1},
	"lantern_crab": {"speed": 84.0, "sight": 390.0, "leash": 435.0, "jump": 0.0,
		"reach": 132.0, "tell": 0.94, "strike": 0.48, "recover": 1.05},
	"seal_keeper": {"speed": 103.0, "sight": 520.0, "leash": 650.0, "jump": 0.0,
		"reach": 165.0, "tell": 0.87, "strike": 0.74, "recover": 0.97},
}

var species: String
var target: CharacterBody2D
var home := Vector2.ZERO
var health := 0
var max_health := 0
var attack_kind := ""
var target_mark := 0.0
var armed := false
var facing := -1.0
var age := 0.0
var flash := 0.0
var recovery := 0.0
var windup := 0.0
var strike := 0.0
var can_hit := false
var profile: Dictionary
var state := State.PATROL
var jump_delay := 0.0
var lost_sight := 0.0
var patrol_dir := -1.0
var dive_lift := 0.0
var walking := false
var second_phase := false
var second_sweep := false


func configure(kind: String, at: Vector2, hunter: CharacterBody2D) -> void:
	species = kind
	position = at
	home = at
	target = hunter
	if Bestiary.CREATURES.has(species):
		var design: Array = Bestiary.CREATURES[species]
		max_health = design[1]
		attack_kind = design[7]
		profile = Bestiary.profile(species)
	else:
		max_health = HP[species]
		profile = PROFILES[species]
	health = max_health
	armed = species in ["treant", "lantern_crab", "thorn_archer", "shield_heron"]


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := RectangleShape2D.new()
	# Keep the movement collider near the feet; combat uses the full sprite hitbox.
	shape.size = Vector2(38, 58) if species in ["treant", "seal_keeper"] else Vector2(28, 29)
	var feet := CollisionShape2D.new()
	feet.shape = shape
	feet.position.y = -shape.size.y / 2.0
	add_child(feet)


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	age += delta
	flash = maxf(flash - delta, 0)
	if species == "bell_moth":
		_update_moth(delta)
		queue_redraw()
		return
	jump_delay = maxf(jump_delay - delta, 0)
	velocity.y = minf(velocity.y + GRAVITY * delta, 850.0)

	var offset := target.position - position
	var visible := absf(offset.x) < float(profile.sight) and absf(offset.y) < 255.0
	lost_sight = 0.0 if visible else lost_sight + delta
	match state:
		State.PATROL:
			if visible:
				state = State.CHASE
			else:
				if absf(position.x - home.x) >= 61 or _wall_ahead(patrol_dir) or not _floor_ahead(patrol_dir):
					patrol_dir = -patrol_dir
				_move(patrol_dir * 48.0)
		State.CHASE:
			_chase(offset)
		State.WINDUP:
			_move(0)
			windup = maxf(0, windup - delta)
			if windup <= 0:
				_start_strike(offset)
		State.STRIKE:
			strike = maxf(0, strike - delta)
			_strike(delta)
			if strike <= 0:
				_start_recovery(float(profile.recover))
		State.RECOVER:
			_move(0)
			recovery = maxf(0, recovery - delta)
			if recovery <= 0 and is_on_floor():
				state = State.CHASE
		State.RETURN:
			_return_home()

	var before_x := position.x
	move_and_slide()
	walking = absf(position.x - before_x) > 0.25
	if state == State.STRIKE and can_hit:
		_try_hit()
	if position.y > home.y + 250.0:
		position = home
		velocity = Vector2.ZERO
		state = State.PATROL
		strike = 0.0
		windup = 0.0
	queue_redraw()


func _chase(offset: Vector2) -> void:
	if absf(position.x - home.x) > profile.leash or lost_sight > 1.65:
		state = State.RETURN
		_move(0)
		return
	if absf(offset.x) > 8.0:
		facing = signf(offset.x)
	var reach := 86.0 if species == "treant" and not armed else float(profile.reach)
	var max_height := 92.0 if species == "lizard" else 64.0
	if is_on_floor() and absf(offset.x) <= reach and absf(offset.y) <= max_height and _clear_to_target():
		state = State.WINDUP
		windup = float(profile.tell)
		target_mark = target.position.x
		if species == "treant" and not armed:
			windup = 0.45
		_move(0)
	else:
		_navigate(facing, float(profile.speed), offset.y < -35.0 and absf(offset.x) < 175.0,
			offset.y > 35.0)


func _return_home() -> void:
	var offset := home - position
	if absf(offset.x) < 17.0 and is_on_floor():
		state = State.PATROL
		_move(0)
		return
	var direction := signf(offset.x) if absf(offset.x) > 10 else facing
	_navigate(direction, float(profile.speed) * 0.85, offset.y < -35.0, offset.y > 35.0)


func _navigate(direction: float, speed: float, climb: bool, descend: bool) -> void:
	if not is_on_floor():
		_move(direction * speed)
		return
	var wall := _wall_ahead(direction)
	var edge := not _floor_ahead(direction)
	var jump_speed: float = profile.jump
	# Only jump a gap if a nearby landing is in reach. The west chasm stays a boundary.
	var crosses_gap := edge and not _terrain_ray(Vector2(direction * 45, -8), Vector2(direction * 150, 70)).is_empty()
	var safe_drop := edge and descend and jump_speed > 0 and not _terrain_ray(
		Vector2(direction * 38, -6), Vector2(direction * 38, 210)).is_empty()
	if jump_speed > 0 and jump_delay <= 0 and (wall or climb or (crosses_gap and not safe_drop)):
		velocity.y = -jump_speed
		jump_delay = 0.35
		_move(direction * speed)
	else:
		_move(0 if wall or (edge and not safe_drop) else direction * speed)


func _move(speed: float) -> void:
	velocity.x = speed
	if absf(speed) > 1:
		facing = signf(speed)


func _floor_ahead(direction: float) -> bool:
	return not _terrain_ray(Vector2(direction * 24, -7), Vector2(direction * 24, 31)).is_empty()


func _wall_ahead(direction: float) -> bool:
	return not _terrain_ray(Vector2(0, -18), Vector2(direction * 28, -18)).is_empty()


func _clear_to_target() -> bool:
	return _terrain_ray(Vector2(0, -29), target.position - position - Vector2(0, 24)).is_empty()


func _terrain_ray(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(global_position + from, global_position + to, 1)
	return get_world_2d().direct_space_state.intersect_ray(query)


func _start_strike(offset: Vector2) -> void:
	state = State.STRIKE
	strike = float(profile.strike)
	can_hit = true
	match species:
		"spider":
			_move(facing * 300.0)
			velocity.y = -253.0 if offset.y > -25.0 else -425.0
		"lizard":
			dive_lift = 0.16
			_move(facing * 159.0)
			velocity.y = -430.0
		"treant":
			_move(facing * (92.0 if armed else 231.0))
		"lantern_crab":
			_move(facing * 182.0)
		"seal_keeper":
			second_sweep = false
			_move(facing * 135.0)
		_:
			_start_bestiary_attack()


func _strike(delta: float) -> void:
	if (species == "seal_keeper" or attack_kind == "double") and not second_sweep and strike < 0.36:
		second_sweep = true
		can_hit = true
		if species == "dust_hare" and absf(target_mark - position.x) > 5.0:
			facing = signf(target_mark - position.x)
		_move(facing * 260.0)
		if attack_kind == "double":
			velocity.y = -270.0
	if attack_kind == "ram" and _wall_ahead(facing):
		_start_recovery(1.5)
		strike = 0.0
	if species == "lizard" and dive_lift > 0:
		dive_lift -= delta
		if dive_lift <= 0:
			velocity.y = 320.0
			_move(facing * 346.0)
	if is_on_floor() and not _floor_ahead(facing):
		_move(0)


func _try_hit() -> void:
	var offset := target.position - position
	if attack_kind == "rune":
		if absf(target.position.x - target_mark) < 57.0 and target.is_on_floor():
			target.hurt(target_mark + 1, 2, "rune")
			can_hit = false
		return
	var reach := 128.0 if armed else (85.0 if species == "treant" else 47.0)
	if species == "seal_keeper":
		reach = 147.0 if second_sweep else 122.0
	elif species == "lantern_crab":
		reach = 91.0
	if not attack_kind.is_empty():
		reach = float(profile.reach)
		if attack_kind in ["shock", "mud", "shards"] and not target.is_on_floor():
			return
	if (facing * offset.x >= -25.0 or attack_kind in ["shock", "mud", "shards"]) and absf(offset.x) <= reach and absf(offset.y) < 78.0 and _clear_to_target():
		can_hit = false
		if attack_kind == "latch":
			target.attach_leech()
		elif attack_kind == "mud":
			target.apply_mud()
			target.hurt(position.x, 1, attack_kind)
		else:
			target.hurt(position.x, 1, attack_kind)


func _start_recovery(seconds: float) -> void:
	state = State.RECOVER
	recovery = seconds
	_move(0)


func body_hitbox() -> Rect2:
	var size: Vector2 = SIZE.get(species, Vector2(82, 69))
	return Rect2(position - Vector2(size.x / 2.0, size.y), size)


func arrow_hitbox(arrow_y: float) -> Rect2:
	if species == "spider" and arrow_y < position.y - 40.0:
		# Above the legs, only the narrower abdomen reaches the level of a standing shot.
		return Rect2(position + Vector2(-20.0 - facing * 7.0, -53.0), Vector2(40, 16))
	return body_hitbox()


func weapon_hitbox() -> Rect2:
	if species == "lantern_crab":
		return Rect2(position + Vector2(facing * 58 - 14, -49), Vector2(28, 41))
	if species == "thorn_archer":
		return Rect2(position + Vector2(facing * 39 - 18, -66), Vector2(36, 45))
	if species == "shield_heron":
		return Rect2(position + Vector2(-facing * 35 - 18, -65), Vector2(36, 48))
	if species == "seal_keeper":
		return Rect2(position + Vector2(facing * 55 - 20, -62), Vector2(40, 43))
	return Rect2(position + Vector2(facing * 81 - 24, -71), Vector2(48, 56))


func receive_hit(damage: int, weapon_hit: bool, projectile: bool = false, source_weapon: String = "", source_direction: float = 0.0) -> void:
	if health <= 0:
		return
	flash = 0.15
	if (species == "bell_moth" and projectile or attack_kind == "rune") and windup > 0:
		windup = 0.0
		recovery = profile.recover
		state = State.RECOVER
	if weapon_hit and armed and windup > 0:
		if species in ["lantern_crab", "thorn_archer"] and not projectile:
			return
		armed = false
		windup = 0.0
		_start_recovery(0.50)
		disarmed.emit(self)
		return
	if attack_kind in ["shell", "roll", "burrow"] and state != State.RECOVER:
		if source_weapon == "tide_hammer" and attack_kind == "shell":
			_start_recovery(1.25)
		else:
			return
	if attack_kind == "shield" and armed and source_direction * facing < 0:
		return
	if attack_kind == "spray" and windup > 0 and source_direction * facing > 0:
		windup = 0.0
		_start_recovery(0.75)
	if attack_kind == "shards" and not second_phase and health - damage <= max_health / 2:
		second_phase = true
		target_mark = position.x
		state = State.WINDUP
		windup = 0.45
	if species == "seal_keeper":
		if armed:
			return
		if not second_phase and health - damage <= 13:
			health = 13
			second_phase = true
			armed = true
			_start_recovery(0.6)
			return
	if species == "lantern_crab" and armed:
		health = maxi(1, health - damage)
		return
	health = maxi(0, health - damage)
	if health == 0:
		felled.emit(self)
		queue_free()


func _draw() -> void:
	if species == "bell_moth":
		_draw_moth()
		return
	if species in ["lantern_crab", "seal_keeper"]:
		_draw_stage_guard()
		return
	if not attack_kind.is_empty():
		_draw_bestiary()
		return
	var pose := 1 if walking and sin(age * 13.0) > 0 else 0
	var torso_motion := sin(age * (9.0 if walking else 3.0)) * 1.5
	if windup > 0:
		pose = 2
		torso_motion = 0
	if strike > 0:
		pose = 3 if species != "treant" or not armed else 1
		if species == "lizard" and dive_lift > 0.0:
			pose = 2
		torso_motion = 0
	if species == "treant" and not armed:
		pose = 3
	var tint := Color(1.25, 1.16, 1.07) if flash > 0 else Color.WHITE
	Art.draw_actor(self, ART_ROWS[species], pose, ART_SCALES[species], facing, torso_motion, tint)
	draw_set_transform(Vector2.ZERO)
	if windup > 0 and armed:
		var grip := weapon_hitbox().get_center() - position + Vector2(0, 12)
		draw_circle(grip, 9, Color(1, 0.74, 0.29, 0.32))
		draw_circle(grip, 3, Color("#ffeac3"))
	elif windup > 0:
		var height := -155.0 if species == "treant" else -94.0
		draw_line(Vector2(0, height - 9), Vector2(0, height + 1), Color("#ffd184"), 3, true)
		draw_circle(Vector2(0, height + 6), 2, Color("#ffd184"))
	if health < int(HP[species]):
		var height := -161.0 if species == "treant" else -90.0
		var bar := Rect2(-24, height, 48, 4)
		draw_rect(bar, Color("#172c2a"))
		bar.size.x *= float(health) / int(HP[species])
		draw_rect(bar, COLORS[species])


func _update_moth(delta: float) -> void:
	position = home + Vector2(sin(age * 1.2) * 32.0, -63.0 + sin(age * 3.1) * 9.0)
	var offset := target.position - position
	if windup > 0:
		windup = maxf(0, windup - delta)
		if windup == 0:
			strike = profile.strike
			can_hit = true
	elif strike > 0:
		strike = maxf(0, strike - delta)
		if can_hit and absf(offset.x) < 82.0 and offset.y >= -5.0 and offset.y < 130.0 and _clear_to_target():
			target.apply_pollen()
			can_hit = false
		if strike == 0:
			recovery = profile.recover
	elif recovery > 0:
		recovery = maxf(0, recovery - delta)
	elif absf(offset.x) < 150.0 and absf(offset.y) < 130.0 and _clear_to_target():
		if absf(offset.x) > 8.0:
			facing = signf(offset.x)
		windup = profile.tell


func _moth_pose() -> MothPose:
	if windup > 0:
		return MothPose.WINDUP
	if strike > 0:
		return MothPose.POLLEN
	if recovery > 0 or flash > 0:
		return MothPose.RECOVER
	return MothPose.HOVER


func _draw_moth() -> void:
	var pose := _moth_pose()
	var flap := 1.0 + sin(age * 19.0) * (0.07 if pose == MothPose.HOVER else 0.035)
	var tint := Color(1.25, 1.16, 1.07) if flash > 0 else Color.WHITE
	Art.draw_bell_moth(self, pose, facing, flap, tint)
	if windup > 0:
		var pulse := 0.16 + (sin(age * 14.0) + 1.0) * 0.09
		draw_circle(Vector2(0, -22), 14, Color(1.0, 0.76, 0.28, pulse))
	if strike > 0:
		var progress := 1.0 - strike / float(profile.strike)
		for i in range(12):
			var at := Vector2(sin(i * 4.9) * (18.0 + 56.0 * progress), i * 7.0 - 10.0 + progress * 34.0)
			draw_circle(at, 4.0 + i % 3, Color(0.93, 0.77, 0.48, 0.75 * (1.0 - progress)))


func _draw_stage_guard() -> void:
	var crab := species == "lantern_crab"
	var lean := sin(age * 14.0) * 0.035 if walking else 0.0
	if windup > 0:
		lean = -0.10
	elif strike > 0:
		lean = 0.21 if second_sweep else 0.12
	var tint := Color(1.22, 1.13, 1.05) if flash > 0 else Color.WHITE
	Art.draw_stage_guard(self, crab, facing, armed, lean, tint)
	if armed and not crab:
		draw_arc(Vector2(0, -70), 65, 0.0, TAU, 48, Color(0.62, 0.71, 1.0, 0.68), 3.0, true)
	if windup > 0:
		var point := weapon_hitbox().get_center() - position
		draw_circle(point, 13 + sin(age * 14.0) * 2, Color(1, 0.72, 0.27, 0.22))
		draw_circle(point, 4, Color("#ffeac3"))
	elif strike > 0:
		var radius := 94.0 if crab else (145.0 if second_sweep else 120.0)
		var angle := 0.0 if facing > 0 else PI
		draw_arc(Vector2(0, -20), radius, angle - 0.29, angle + 0.29, 18, Color(1, 0.73, 0.35, 0.73), 3.0, true)
	var bar := Rect2(-32, -77 if crab else -174, 64, 5)
	draw_rect(bar, Color("#172c2a"))
	bar.size.x *= float(health) / int(HP[species])
	draw_rect(bar, Color("#daa260") if crab else Color("#bb9ce2"))


func _start_bestiary_attack() -> void:
	second_sweep = false
	match attack_kind:
		"roll", "ram", "shield":
			_move(facing * (340.0 if attack_kind == "ram" else 260.0))
		"double", "leap":
			if species == "dust_hare":
				can_hit = false
				_move(-facing * 95.0)
				velocity.y = -150.0
			else:
				_move(facing * 235.0)
				velocity.y = -365.0 if attack_kind == "leap" else -265.0
		"burrow":
			_move(facing * 315.0)
			velocity.y = -180.0
		"latch":
			_move(facing * 205.0)
			velocity.y = -170.0
		"arrow", "shell", "spray":
			_move(0)
			can_hit = false
			launched.emit(position + Vector2(facing * 25, -32), facing, attack_kind)
		_:
			_move(0)


func _draw_bestiary() -> void:
	var lean := 0.0
	if windup > 0:
		lean = -0.14
	elif strike > 0:
		lean = 0.18
	elif attack_kind == "roll" and recovery > 0:
		lean = 0.78
	elif walking:
		lean = sin(age * 17.0) * 0.035
	var tint := Color(1.23, 1.16, 1.07) if flash > 0 else Color.WHITE
	Art.draw_bestiary(self, Bestiary.CREATURES[species][0], facing, lean, tint)
	if windup > 0 and attack_kind == "rune":
		draw_circle(Vector2(target_mark - position.x, 0), 54, Color(1.0, 0.41, 0.19, 0.25))
	elif windup > 0 and attack_kind == "burrow":
		draw_circle(Vector2(facing * 34, -2), 27, Color(0.66, 0.42, 0.22, 0.58))
	elif windup > 0:
		var aim := weapon_hitbox().get_center() - position if armed else Vector2(0, -56)
		draw_circle(aim, 8, Color(1.0, 0.68, 0.28, 0.45))
		draw_circle(aim, 3, Color("#ffe7b3"))
	if strike > 0 and attack_kind in ["shock", "mud", "shards", "rune"]:
		var center := Vector2(target_mark - position.x, 0) if attack_kind == "rune" else Vector2(0, -4)
		var radius := 54.0 if attack_kind == "rune" else float(profile.reach)
		draw_line(center - Vector2(radius, 0), center + Vector2(radius, 0), Color(1.0, 0.64, 0.30, 0.66), 4.0, true)
	if health < max_health:
		draw_rect(Rect2(-23, -75, 46, 4), Color("#172c2a"))
		draw_rect(Rect2(-23, -75, 46.0 * health / max_health, 4), Color("#d2a06c"))
