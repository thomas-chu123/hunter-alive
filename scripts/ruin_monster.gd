extends CharacterBody2D

signal felled(monster: Node2D)
signal disarmed(monster: Node2D)
signal launched(origin: Vector2, direction: float, attack: Dictionary)

const Bestiary := preload("res://scripts/ruin_bestiary.gd")
const Art := preload("res://scripts/ruin_sprite_art.gd")
const EnemyAudio := preload("res://scripts/ruin_enemy_audio.gd")
const Effects := preload("res://scripts/ruin_enemy_effects.gd")
const Hunter := preload("res://scripts/ruin_hunter.gd")
const SIZE := {"spider": Vector2(76, 55), "lizard": Vector2(92, 70), "treant": Vector2(110, 120),
	"bell_moth": Vector2(64, 49), "lantern_crab": Vector2(97, 60), "seal_keeper": Vector2(102, 136)}
const ART_ROWS := {"spider": 0, "lizard": 1, "treant": 2}
const ART_SCALES := {"spider": 0.30, "lizard": 0.33, "treant": 0.46}
enum State { PATROL, NOTICE, CHASE, WINDUP, STRIKE, RECOVER, RETURN, STAGGER }
enum AttackPose { IDLE = -1, ANTICIPATION, RELEASE, RECOVERY }

const GRAVITY := 1380.0
const NOTICE_TIME := 0.13
const LOST_SIGHT_TIME := 0.62
const BLOCKED_TIME := 0.42
const REACQUIRE_DELAY := 0.80
const CHASE_HEIGHT := 230.0
const STEP_TIME := 0.065

var species: String
var target: CharacterBody2D
var home := Vector2.ZERO
var health := 0
var max_health := 0
var attack_kind := ""
var attack: Dictionary
var design: Dictionary
var animation: Dictionary
var sound: Dictionary
var step_voice: AudioStreamPlayer2D
var attack_voice: AudioStreamPlayer2D
var step_progress := 0.0
var step_pitch := 0.96
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
var blocked_time := 0.0
var notice_left := 0.0
var reacquire_left := 0.0
var barrier_dir := 0.0
var barrier_x := 0.0
var patrol_center := 0.0
var requested_speed := 0.0
var gait_distance := 0.0
var visual_turn := -1.0
var gait_weight := 0.0
var windup_duration := 0.0
var recovery_duration := 0.0
var recoil := 0.0
var hit_reaction: Dictionary
var hit_left := 0.0
var hit_direction := 0.0
var hover_recoil := 0.0
var stagger_left := 0.0
var stagger_direction := 0.0
var stagger_speed := 0.0
var patrol_dir := -1.0
var walking := false
var second_phase := false


func configure(kind: String, at: Vector2, hunter: CharacterBody2D) -> void:
	species = kind
	position = at
	home = at
	patrol_center = at.x
	target = hunter
	design = Bestiary.creatures[species]
	animation = design.get("animation", {})
	sound = design.sound
	hit_reaction = design.hit_reaction
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
	shape.size = Vector2(float(profile.collider_width), float(profile.collider_height))
	var feet := CollisionShape2D.new()
	feet.shape = shape
	feet.position.y = -shape.size.y / 2.0
	add_child(feet)
	step_voice = EnemyAudio.voice(float(sound.get("step_gain_db", -11.0)))
	attack_voice = EnemyAudio.voice(-3.0)
	add_child(step_voice)
	add_child(attack_voice)


func _exit_tree() -> void:
	if is_instance_valid(step_voice):
		step_voice.stop()
	if is_instance_valid(attack_voice):
		attack_voice.stop()


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	age += delta
	flash = maxf(flash - delta, 0)
	hit_left = maxf(hit_left - delta, 0.0)
	reacquire_left = maxf(reacquire_left - delta, 0)
	recoil = move_toward(recoil, 0.0, delta * 38.0)
	if species == "bell_moth":
		_update_moth(delta)
		if state != State.STAGGER and _attack_pose() == AttackPose.IDLE:
			_step_sound(delta, float(sound.flap_period))
		_update_motion_art(delta, 0.0)
		queue_redraw()
		return
	jump_delay = maxf(jump_delay - delta, 0)
	velocity.y = minf(velocity.y + GRAVITY * delta, 850.0)
	var offset := target.position - position
	var visible := absf(offset.x) <= float(profile.sight) and absf(offset.y) <= CHASE_HEIGHT and _clear_to_target()
	lost_sight = 0.0 if visible else lost_sight + delta
	requested_speed = 0.0
	if state in [State.NOTICE, State.CHASE] and (not _inside_leash(target.position) or not _inside_leash(position)):
		_begin_return()
	match state:
		State.PATROL:
			if visible and _can_engage():
				state = State.NOTICE
				notice_left = NOTICE_TIME
				facing = signf(offset.x) if absf(offset.x) > 8.0 else facing
			else:
				_patrol()
		State.NOTICE:
			notice_left -= delta
			if notice_left <= 0.0:
				state = State.CHASE
		State.CHASE:
			if lost_sight > LOST_SIGHT_TIME:
				_begin_return()
			else:
				_chase(offset)
		State.WINDUP:
			windup = maxf(0, windup - delta)
			if windup <= 0:
				_start_strike()
		State.STRIKE:
			strike = maxf(0, strike - delta)
			_update_strike()
			if strike <= 0:
				_start_recovery(float(attack.recovery))
		State.RECOVER:
			recovery = maxf(0, recovery - delta)
			if recovery <= 0 and is_on_floor():
				if _inside_leash(target.position) and lost_sight <= LOST_SIGHT_TIME:
					state = State.CHASE
				else:
					_begin_return()
		State.RETURN:
			_return_home()
		State.STAGGER:
			_update_stagger(delta, visible)

	var before := position
	velocity.x = move_toward(velocity.x, requested_speed, float(profile.acceleration) * delta)
	var budget := float(profile.leash)
	# Clip chase steering to the territory edge, including the last movement step.
	velocity.x = clampf(velocity.x, minf(0.0, (home.x - budget - position.x) / delta),
		maxf(0.0, (home.x + budget - position.x) / delta))
	move_and_slide()
	var travel := absf(position.x - before.x)
	_update_motion_art(delta, travel)
	if walking:
		_step_sound(travel, float(sound.spacing))
	if state in [State.CHASE, State.RETURN]:
		_check_progress(delta, travel)
	if state == State.STRIKE and can_hit:
		_try_hit()
	if position.y > home.y + 250.0:
		position = home
		velocity = Vector2.ZERO
		patrol_center = home.x
		state = State.PATROL
		strike = 0.0
		windup = 0.0
		recovery = 0.0
		stagger_left = 0.0
		can_hit = false
	queue_redraw()


func _inside_leash(point: Vector2) -> bool:
	return absf(point.x - home.x) <= float(profile.leash) and absf(point.y - home.y) <= CHASE_HEIGHT


func _can_engage() -> bool:
	if reacquire_left > 0.0 or not _inside_leash(target.position):
		return false
	if barrier_dir != 0.0 and (target.position.x - barrier_x) * barrier_dir > 0.0:
		return false
	barrier_dir = 0.0
	return true


func _patrol() -> void:
	if not is_on_floor():
		return
	var radius := float(profile.patrol_radius)
	if (position.x - patrol_center) * patrol_dir >= radius or not _can_walk(patrol_dir):
		patrol_dir = -patrol_dir
	if (position.x - patrol_center) * patrol_dir < radius and _can_walk(patrol_dir):
		_move(patrol_dir * 45.0)


func _chase(offset: Vector2) -> void:
	if absf(offset.x) > 8.0:
		facing = signf(offset.x)
	var reach := float(_attack_value("trigger_range"))
	var height := 82.0 if _attack_value("mode") == "bolt" else 64.0
	if is_on_floor() and absf(offset.x) <= reach and absf(offset.y) <= height and _clear_to_target():
		_begin_windup()
	else:
		_navigate(facing, float(profile.speed), offset.y < -35.0 and absf(offset.x) < 175.0)


func _begin_return() -> void:
	state = State.RETURN
	blocked_time = 0.0
	reacquire_left = REACQUIRE_DELAY
	_move(0)


func _return_home() -> void:
	var offset := home - position
	if absf(offset.x) < 17.0 and absf(offset.y) < 30.0 and is_on_floor():
		_resume_patrol(home.x)
		return
	var direction := signf(offset.x) if absf(offset.x) > 9.0 else patrol_dir
	_navigate(direction, float(profile.speed) * 0.85, offset.y < -35.0,
		offset.y > 35.0)


func _resume_patrol(center: float) -> void:
	var max_offset := float(profile.leash) - float(profile.patrol_radius) - 8.0
	patrol_center = clampf(center, home.x - max_offset, home.x + max_offset)
	state = State.PATROL
	reacquire_left = REACQUIRE_DELAY
	_move(0)


func _check_progress(delta: float, travel: float) -> void:
	if not is_on_floor() or travel >= 0.32:
		blocked_time = 0.0
		return
	blocked_time += delta
	if blocked_time < BLOCKED_TIME:
		return
	if state == State.RETURN:
		# A terrain change can close the route back; patrol the reachable floor.
		_resume_patrol(position.x)
	else:
		barrier_dir = facing
		barrier_x = position.x + barrier_dir * (float(profile.collider_width) * 0.5 + 21.0)
		_begin_return()


func _navigate(direction: float, speed: float, climb: bool, descend: bool = false) -> void:
	if not is_on_floor():
		_move(direction * speed)
		return
	var walkable := _can_walk(direction)
	if (not walkable or climb) and jump_delay <= 0.0 and float(profile.jump) > 0.0:
		jump_delay = 0.22
		if _find_landing(direction, speed, climb and walkable):
			velocity.y = -float(profile.jump)
			jump_delay = 0.35
			_move(direction * speed, true)
			return
	if walkable or (descend and _can_drop(direction)):
		_move(direction * speed)


func _can_walk(direction: float) -> bool:
	var half_width := float(profile.collider_width) * 0.5
	var ahead := Vector2(direction * 13.0, 0.0)
	if test_move(global_transform, ahead):
		return false
	var step := direction * (half_width + 16.0)
	return not _terrain_ray(Vector2(step, -8.0), Vector2(step, 23.0)).is_empty()


func _can_drop(direction: float) -> bool:
	if float(profile.jump) <= 0.0 or test_move(global_transform, Vector2(direction * 16.0, 0)):
		return false
	var step := direction * (float(profile.collider_width) * 0.5 + 12.0)
	return not _terrain_ray(Vector2(step, -8.0), Vector2(step, 84.0)).is_empty()


func _find_landing(direction: float, speed: float, higher_only: bool) -> bool:
	var jump := float(profile.jump)
	var landing := KinematicCollision2D.new()
	var origin := global_transform
	var previous := Vector2.ZERO
	var vx := direction * speed
	var lowest := 44.0
	var step_count := ceili((2.0 * jump / GRAVITY + 0.12) / STEP_TIME)
	for index in range(1, step_count + 1):
		var time := index * STEP_TIME
		var next := Vector2(vx * time, (GRAVITY * 0.5 * time - jump) * time)
		if absf(position.x + next.x - home.x) > float(profile.leash) or next.y > lowest:
			return false
		if test_move(origin.translated(previous), next - previous, landing):
			var endpoint := previous + landing.get_travel()
			var distance := absf(endpoint.x)
			return next.y > previous.y and landing.get_normal().y < -0.7 and distance > 37.0 and (
				not higher_only or endpoint.y < -20.0)
		previous = next
	return false


func _move(speed: float, launch: bool = false) -> void:
	requested_speed = speed
	if absf(speed) > 1:
		facing = signf(speed)
	if launch:
		velocity.x = speed


func _update_motion_art(delta: float, travel: float) -> void:
	walking = state != State.STAGGER and travel > 0.15 and is_on_floor()
	gait_weight = move_toward(gait_weight, 1.0 if walking else 0.0, delta * 8.0)
	if walking:
		gait_distance += travel
	var turning_rate := 21.0 if state in [State.WINDUP, State.STRIKE] else 13.0
	visual_turn = move_toward(visual_turn, facing, turning_rate * delta)


func _sprite_facing() -> float:
	return signf(visual_turn) * maxf(absf(visual_turn), 0.55) if not is_zero_approx(visual_turn) else facing * 0.55


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
	windup_duration = float(_attack_value("windup")) if duration < 0 else duration
	windup = windup_duration
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
				_attack_sound()
		else:
			can_hit = true
			_attack_sound()
	if progress >= 0.91 or (moments.size() == 2 and progress >= 0.46 and progress < 0.63):
		can_hit = false


func _step_sound(distance: float, interval: float) -> void:
	step_progress += distance
	if step_progress < interval:
		return
	step_progress = fposmod(step_progress, interval)
	if position.distance_to(target.position) < EnemyAudio.AUDIBLE_DISTANCE:
		step_pitch = 2.0 - step_pitch
		EnemyAudio.play(step_voice, EnemyAudio.STEPS[sound.step], step_pitch)


func _attack_sound() -> void:
	if position.distance_to(target.position) >= EnemyAudio.AUDIBLE_DISTANCE:
		return
	var key: String = sound.attack if armed else sound.get("unarmed_attack", sound.attack)
	EnemyAudio.play(attack_voice, EnemyAudio.ATTACKS[key], 1.0)


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
	recovery_duration = seconds
	recovery = seconds
	_move(0)


func _flinch(direction: float) -> void:
	hit_direction = signf(direction)
	hit_left = float(hit_reaction.duration)
	recoil = hit_direction * 3.0


func _start_stagger(direction: float) -> void:
	state = State.STAGGER
	windup = 0.0
	strike = 0.0
	can_hit = false
	stagger_left = float(hit_reaction.duration)
	stagger_direction = signf(direction)
	stagger_speed = float(hit_reaction.speed)
	blocked_time = 0.0
	velocity.x = 0.0


func _update_stagger(delta: float, visible: bool) -> void:
	stagger_left = maxf(stagger_left - delta, 0.0)
	if stagger_left <= 0.0:
		velocity.x = 0.0
		if recovery > 0.0:
			state = State.RECOVER
		elif visible and _inside_leash(target.position):
			state = State.CHASE
		else:
			_begin_return()
		return
	var resistance := float(hit_reaction.speed) * 0.65 / float(hit_reaction.duration)
	stagger_speed = move_toward(stagger_speed, 0.0, resistance * delta)
	if species == "bell_moth":
		var motion := Vector2(stagger_speed * stagger_direction * delta, 0.0)
		if not test_move(global_transform, motion):
			hover_recoil = clampf(hover_recoil + motion.x, -34.0, 34.0)
		return
	if is_on_floor() and not _can_walk(stagger_direction):
		stagger_speed = 0.0
	requested_speed = stagger_speed * stagger_direction
	velocity.x = requested_speed


func apply_equipment_push(direction: float, force: float) -> void:
	if state == State.STAGGER and direction * stagger_direction > 0.0:
		stagger_speed = maxf(stagger_speed, float(hit_reaction.speed) + force)
	else:
		velocity.x += direction * force


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
	var direction := source_direction
	if is_zero_approx(direction):
		direction = signf(position.x - target.position.x)
		if is_zero_approx(direction):
			direction = -facing

	if weapon_hit and armed and windup > 0:
		if species in ["lantern_crab", "thorn_archer"] and not projectile:
			return
		armed = false
		_start_recovery(0.50)
		_flinch(direction)
		disarmed.emit(self)
		return
	if attack_kind in ["shell", "roll", "burrow"] and recovery <= 0.0 and state != State.RECOVER:
		if source_weapon == "tide_hammer" and attack_kind == "shell":
			_start_recovery(1.25)
		else:
			return
	if attack_kind == "shield" and armed and source_direction * facing < 0:
		return
	if species == "seal_keeper" and armed:
		return

	var before := health
	var minimum := 1 if species == "lantern_crab" and armed else 0
	var triggers_seal := species == "seal_keeper" and not second_phase and health - damage <= 13
	if triggers_seal:
		minimum = 13
	health = maxi(minimum, health - damage)
	if health >= before and not triggers_seal:
		return
	if health == 0:
		felled.emit(self)
		queue_free()
		return
	_flinch(direction)

	# Encounter-specific interruptions take priority over general stagger.
	if triggers_seal:
		second_phase = true
		armed = true
		_start_recovery(0.6)
	elif attack_kind == "shards" and not second_phase and health <= max_health / 2.0:
		second_phase = true
		_begin_windup(0.45)
	elif windup > 0 and ((species == "bell_moth" and projectile) or attack_kind == "rune"):
		_start_recovery(float(attack.recovery))
	elif attack_kind == "spray" and windup > 0 and source_direction * facing > 0:
		_start_recovery(0.75)
	elif not projectile and state not in [State.STRIKE, State.STAGGER] and (
			windup <= 0.0 or hit_reaction.interrupt_windup):
		_start_stagger(direction)


func _draw() -> void:
	var tint := Color(1.23, 1.16, 1.07) if flash > 0 else Color.WHITE
	var pose := _attack_pose()
	var unarmed := not armed and attack.has("unarmed")
	var motion_facing := _sprite_facing()
	var size: Vector2 = SIZE.get(species, Vector2(82, 69))
	var stride := float(animation.get("stride", 68.0))
	var rhythm := gait_distance * TAU / stride
	var stretch := 1.0 + sin(age * 3.5) * 0.014 + sin(rhythm * 2.0) * 0.026 * gait_weight
	var lean := cos(rhythm) * 0.043 * gait_weight
	var walk_row: int = animation.get("unarmed_walk" if unarmed else "walk", -1)
	var transition_row: int = animation.get("unarmed_transition" if unarmed else "transition", -1)
	var phase := _transition_frame() if transition_row >= 0 else -1
	if state == State.NOTICE:
		stretch += 0.065 * sin(notice_left / NOTICE_TIME * PI)
		lean -= 0.06
	var hit := pow(clampf(hit_left / float(hit_reaction.duration), 0.0, 1.0), 1.4)
	var squash := hit * float(hit_reaction.squash)
	var hit_lean := hit_direction * signf(motion_facing) * squash * 0.9
	if state == State.STAGGER or (pose == AttackPose.IDLE and hit > 0.0):
		Art.draw_attack(self, int(design.sprite_row), AttackPose.RECOVERY, motion_facing, tint, unarmed,
			1.0 - squash, hit_lean, recoil)
	elif pose >= 0:
		if strike > 0.0:
			motion_facing = facing
			var swing := sin(_strike_progress() * PI)
			stretch = 1.0 + swing * 0.035
			lean = swing * 0.035
		elif recovery > 0.0:
			lean = 0.05 * clampf(recovery / maxf(recovery_duration, 0.02), 0.0, 1.0)
		stretch *= 1.0 - squash
		lean += hit_direction * signf(motion_facing) * squash * 0.9
		if phase >= 0:
			Art.draw_transition(self, transition_row, phase, motion_facing, tint, stretch, lean, recoil)
		else:
			Art.draw_attack(self, int(design.sprite_row), pose, motion_facing, tint, unarmed, stretch, lean, recoil)
	elif walk_row >= 0 and gait_weight > 0.24:
		Art.draw_walk(self, walk_row, floori(fposmod(gait_distance, stride) / stride * 4.0),
			motion_facing, tint, stretch, lean, recoil)
	elif species == "bell_moth":
		var flap := 1.0 + sin(age * 19.0) * 0.08
		Art.draw_bell_moth(self, 0, motion_facing, flap, tint)
	elif species in ["lantern_crab", "seal_keeper"]:
		Art.draw_stage_guard(self, species == "lantern_crab", motion_facing, armed, lean, tint)
	elif ART_ROWS.has(species):
		var idle := 3 if species == "treant" and not armed else 0
		Art.draw_actor(self, ART_ROWS[species], idle, ART_SCALES[species], motion_facing, (1.0 - stretch) * size.y, tint)
		draw_set_transform(Vector2.ZERO)
	elif unarmed and species in ["thorn_archer", "shield_heron"]:
		Art.draw_attack(self, int(design.sprite_row), AttackPose.RECOVERY, motion_facing,
			tint, unarmed, stretch, lean, recoil)
	else:
		Art.draw_bestiary(self, int(design.idle_atlas_index), motion_facing, lean, tint, stretch, recoil)
	if species == "seal_keeper" and armed:
		draw_arc(Vector2(0, -70), 65, 0, TAU, 48, Color(0.62, 0.71, 1.0, 0.68), 3, true)
	_draw_attack_effect(size)
	if health < max_health or species in ["lantern_crab", "seal_keeper"]:
		var bar := Rect2(-27, -size.y - 22, 54, 4)
		draw_rect(bar, Color("#172c2a"))
		bar.size.x *= float(health) / max_health
		draw_rect(bar, Color("#d2a06c"))


func _transition_frame() -> int:
	if windup > 0 and windup_duration > 0 and windup / windup_duration > 0.44:
		return 0
	if strike > 0.0:
		var progress := _strike_progress()
		if progress >= 0.32 and progress < 0.46:
			return 1
		if int(attack.get("hits", 1)) == 1 and progress >= 0.46:
			return 1
		if int(attack.get("hits", 1)) == 2 and progress >= 0.82:
			return 1
	return -1


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
	var base := home + Vector2(sin(age * 1.2) * float(profile.patrol_radius), -63.0 + sin(age * 3.1) * 9.0)
	if state == State.STAGGER:
		_update_stagger(delta, _inside_leash(target.position))
		position = base + Vector2(hover_recoil, 0.0)
		return
	hover_recoil = move_toward(hover_recoil, 0.0, delta * 56.0)
	position = base + Vector2(hover_recoil, 0.0)
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
	elif _inside_leash(target.position) and absf(offset.x) < float(attack.trigger_range) and absf(offset.y) < 130.0 and _clear_to_target():
		if absf(offset.x) > 8.0:
			facing = signf(offset.x)
		_begin_windup()
