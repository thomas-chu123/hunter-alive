extends CharacterBody2D

signal felled(monster: Node2D)
signal disarmed(monster: Node2D)
signal launched(origin: Vector2, direction: float, attack: Dictionary)

const Bestiary := preload("res://scripts/ruin_bestiary.gd")
const Art := preload("res://scripts/ruin_sprite_art.gd")
const Effects := preload("res://scripts/ruin_enemy_effects.gd")
const Hunter := preload("res://scripts/ruin_hunter.gd")
const COLORS := {"spider": Color("#ae745d"), "lizard": Color("#77c6ad"), "treant": Color("#d5a56d")}
const SIZE := {"spider": Vector2(76, 55), "lizard": Vector2(92, 70), "treant": Vector2(110, 120),
	"bell_moth": Vector2(64, 49), "lantern_crab": Vector2(97, 60), "seal_keeper": Vector2(102, 136)}
const ART_ROWS := {"spider": 0, "lizard": 1, "treant": 2}
const ART_SCALES := {"spider": 0.30, "lizard": 0.33, "treant": 0.46}
enum State { PATROL, CHASE, WINDUP, STRIKE, RECOVER, RETURN }
enum AttackPose { IDLE = -1, ANTICIPATION, RELEASE, RECOVERY }

const GRAVITY := 1380.0
var species: String
var target: CharacterBody2D
var home := Vector2.ZERO
var health := 0
var max_health := 0
var attack_kind := ""
var attack: Dictionary
var design: Dictionary
var target_mark := Vector2.ZERO
var ground_mark_valid := false
var impact_index := 0
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
var walking := false
var second_phase := false


func configure(kind: String, at: Vector2, hunter: CharacterBody2D) -> void:
	species = kind
	position = at
	home = at
	target = hunter
	design = Bestiary.creatures[species]
	max_health = int(design.health)
	profile = design.motion
	attack = design.attack
	attack_kind = attack.kind
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
				_start_strike()
		State.STRIKE:
			strike = maxf(0, strike - delta)
			_update_strike()
			if strike <= 0:
				_start_recovery(float(attack.recovery))
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
	var reach := float(_attack_value("trigger_range"))
	var max_height := 82.0 if _attack_value("mode") == "bolt" else 64.0
	if is_on_floor() and absf(offset.x) <= reach and absf(offset.y) <= max_height and _clear_to_target():
		_begin_windup()
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


func _attack_value(key: String) -> Variant:
	if not armed and attack.has("unarmed"):
		return attack.unarmed.get(key, attack[key])
	return attack[key]


func _begin_windup(duration: float = -1.0) -> void:
	state = State.WINDUP
	windup = float(_attack_value("windup")) if duration < 0 else duration
	ground_mark_valid = false
	if _attack_value("mode") == "ground":
		var mark_x: float = target.position.x if attack.get("target_mark", false) else position.x
		var ground := _terrain_ray(Vector2(mark_x - position.x, -62), Vector2(mark_x - position.x, 90))
		ground_mark_valid = not ground.is_empty()
		if ground_mark_valid:
			target_mark = ground.position
	_move(0)


func _start_strike() -> void:
	state = State.STRIKE
	strike = float(attack.active)
	can_hit = false
	impact_index = 0
	_move(0)


func _strike_progress() -> float:
	return 1.0 - strike / float(attack.active)


func _update_strike() -> void:
	var progress := _strike_progress()
	var moments := [0.12, 0.63] if int(attack.get("hits", 1)) == 2 else [0.12]
	if impact_index < moments.size() and progress >= moments[impact_index]:
		impact_index += 1
		if _attack_value("mode") == "bolt":
			var outlet := Vector2(facing * float(attack.outlet[0]), float(attack.outlet[1]))
			if _terrain_ray(Vector2(0, outlet.y), outlet).is_empty():
				launched.emit(position + outlet, facing, attack)
		else:
			can_hit = true
	if progress >= 0.91 or (moments.size() == 2 and progress >= 0.46 and progress < 0.63):
		can_hit = false


func _attack_area() -> Rect2:
	var extent := float(_attack_value("extent"))
	match _attack_value("mode"):
		"ground":
			return Rect2(target_mark + Vector2(-extent, -24), Vector2(2 * extent, 29))
		"pollen":
			return Rect2(position + Vector2(-extent, -10), Vector2(2 * extent, 132))
		_:
			if species == "seal_keeper" and impact_index == 2:
				extent += 20.0
			var height := minf(102, float(body_hitbox().size.y) + 5)
			var x := position.x + (12.0 if facing > 0 else -extent)
			return Rect2(x, position.y - height, extent - 12.0, height + 4.0)


func _try_hit() -> void:
	var mode: String = _attack_value("mode")
	if mode == "ground" and (not ground_mark_valid or not target.is_on_floor()):
		return
	var height := Hunter.CROUCH_HEIGHT if target.crouching else Hunter.STANDING_HEIGHT
	var bounds := Rect2(target.position - Vector2(12, height), Vector2(24, height))
	if not _attack_area().intersects(bounds):
		return
	if mode != "ground" and not _clear_to_target():
		return
	if mode == "ground":
		var origin := target_mark - position - Vector2(0, 12)
		if not _terrain_ray(origin, target.position - position - Vector2(0, 12)).is_empty():
			return
	can_hit = false
	match attack_kind:
		"pollen":
			target.apply_pollen()
		"latch":
			target.attach_leech()
		"mud":
			target.apply_mud()
			target.hurt(target_mark.x, int(attack.damage), attack_kind)
		_:
			var source_x := position.x if mode != "ground" else target_mark.x
			target.hurt(source_x, int(attack.damage), attack_kind)


func _start_recovery(seconds: float) -> void:
	state = State.RECOVER
	windup = 0.0
	strike = 0.0
	can_hit = false
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
		_start_recovery(float(attack.recovery))
	if weapon_hit and armed and windup > 0:
		if species in ["lantern_crab", "thorn_archer"] and not projectile:
			return
		armed = false
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
		_start_recovery(0.75)
	if attack_kind == "shards" and not second_phase and health - damage <= max_health / 2:
		second_phase = true
		_begin_windup(0.45)
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
	var tint := Color(1.23, 1.16, 1.07) if flash > 0 else Color.WHITE
	var pose := _attack_pose()
	var unarmed := not armed and attack.has("unarmed")
	if pose == AttackPose.IDLE and unarmed and species in ["thorn_archer", "shield_heron"]:
		pose = AttackPose.RECOVERY
	var size: Vector2 = SIZE.get(species, Vector2(82, 69))
	if pose >= 0:
		Art.draw_attack(self, int(design.sprite_row), pose, facing, tint, unarmed)
	elif species == "bell_moth":
		var flap := 1.0 + sin(age * 19.0) * 0.07
		Art.draw_bell_moth(self, 0, facing, flap, tint)
	elif species in ["lantern_crab", "seal_keeper"]:
		var lean := sin(age * 14.0) * 0.035 if walking else 0.0
		Art.draw_stage_guard(self, species == "lantern_crab", facing, armed, lean, tint)
	elif ART_ROWS.has(species):
		var idle := 1 if walking and sin(age * 13.0) > 0 else 0
		if species == "treant" and not armed:
			idle = 3
		var bob := sin(age * (9.0 if walking else 3.0)) * 1.5
		Art.draw_actor(self, ART_ROWS[species], idle, ART_SCALES[species], facing, bob, tint)
		draw_set_transform(Vector2.ZERO)
	else:
		var lean := sin(age * 17.0) * 0.035 if walking else 0.0
		Art.draw_bestiary(self, int(design.idle_atlas_index), facing, lean, tint)
	if species == "seal_keeper" and armed:
		draw_arc(Vector2(0, -70), 65, 0, TAU, 48, Color(0.62, 0.71, 1.0, 0.68), 3, true)
	_draw_attack_effect(size)
	if health < max_health or species in ["lantern_crab", "seal_keeper"]:
		var bar := Rect2(-27, -size.y - 22, 54, 4)
		draw_rect(bar, Color("#172c2a"))
		bar.size.x *= float(health) / max_health
		draw_rect(bar, Color("#d2a06c"))


func _attack_pose() -> AttackPose:
	if windup > 0:
		return AttackPose.ANTICIPATION
	if strike > 0:
		var progress := _strike_progress()
		if int(attack.get("hits", 1)) == 2 and progress >= 0.46 and progress < 0.63:
			return AttackPose.ANTICIPATION
		return AttackPose.RELEASE
	return AttackPose.RECOVERY if recovery > 0 else AttackPose.IDLE


func _draw_attack_effect(size: Vector2) -> void:
	var mode: String = _attack_value("mode")
	var element: String = attack.element
	if mode == "ground" and ground_mark_valid and (windup > 0 or strike > 0):
		Effects.ground(self, target_mark - position, float(attack.extent), element,
			strike > 0, _strike_progress() if strike > 0 else age)
	elif windup > 0:
		var point := Vector2(facing * size.x * 0.28, -size.y * 0.67)
		if armed:
			point = weapon_hitbox().get_center() - position
		Effects.charge(self, point, element, age)
	elif strike > 0 and _attack_pose() == AttackPose.RELEASE:
		var progress := _strike_progress()
		if mode == "melee":
			var reach := _attack_area().size.x + 12.0
			Effects.sweep(self, size.y * 0.46, reach, facing, element, progress)
		elif mode == "pollen":
			Effects.pollen(self, progress)


func _update_moth(delta: float) -> void:
	position = home + Vector2(sin(age * 1.2) * 32.0, -63.0 + sin(age * 3.1) * 9.0)
	var offset := target.position - position
	if windup > 0:
		windup = maxf(0, windup - delta)
		if windup == 0:
			_start_strike()
	elif strike > 0:
		strike = maxf(0, strike - delta)
		_update_strike()
		if can_hit:
			_try_hit()
		if strike == 0:
			_start_recovery(float(attack.recovery))
	elif recovery > 0:
		recovery = maxf(0, recovery - delta)
	elif absf(offset.x) < float(attack.trigger_range) and absf(offset.y) < 130.0 and _clear_to_target():
		if absf(offset.x) > 8.0:
			facing = signf(offset.x)
		_begin_windup()
