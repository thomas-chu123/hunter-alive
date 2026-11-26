extends CharacterBody2D

signal felled(monster: Node2D)
signal disarmed(monster: Node2D)
signal launched(origin: Vector2, direction: float, attack: Dictionary)
signal phase_changed

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const Art := preload("res://scripts/character/ruin_sprite_art.gd")
const EnemyAudio := preload("res://scripts/sound/ruin_enemy_audio.gd")
const Effects := preload("res://scripts/effects/ruin_enemy_effects.gd")
const Hunter := preload("res://scripts/character/ruin_hunter.gd")
const HIT_FLASH := preload("res://scripts/effects/ruin_hit_flash.gdshader")
enum State { PATROL, NOTICE, CHASE, WINDUP, STRIKE, RECOVER, RETURN, STAGGER }
enum AttackPose { IDLE = -1, ANTICIPATION, RELEASE, RECOVERY }
enum HitResult { BLOCKED, DAMAGED, DISARMED }

var species: String
var target: CharacterBody2D
var home := Vector2.ZERO
var health := 0
var max_health := 0
var boss_scale := 1.0
var level := 1
var soul_reward: Array
var attack_kind := ""
var attack: Dictionary
var design: Dictionary
var combat: Dictionary
var appearance: Dictionary
var sprites: Dictionary
var motion_rules: Dictionary = Bestiary.rules.motion
var combat_rules: Dictionary = Bestiary.rules.combat
var hover: Dictionary
var body_size: Vector2
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
var blade_flash_left := 0.0
var actor_art: Node2D
var flash_material: ShaderMaterial
var recovery := 0.0
var windup := 0.0
var strike := 0.0
var can_hit := false
var profile: Dictionary
var state := State.PATROL
var jump_delay := 0.0
var perception := Blackboard.new()
var hover_patrol_time := 0.0
var lost_sight := 0.0
var blocked_time := 0.0
var notice_left := 0.0
var reacquire_left := 0.0
var barrier_dir := 0.0
var barrier_x := 0.0
var patrol_center := 0.0
var requested_speed := 0.0
var gait_distance := 0.0
var gait_phase := 0.0
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
var foot_dust: Array[Dictionary] = []
var bob_y := 0.0
var stretch_y := 1.0
var stretch_x := 1.0
var sprint_lean := 0.0


func configure(kind: String, at: Vector2, hunter: CharacterBody2D) -> void:
	species = kind
	position = at
	home = at
	patrol_center = at.x
	target = hunter
	design = Bestiary.creatures[species]
	combat = design.get("combat", {})
	appearance = design.art
	sprites = Art.load_poses(appearance)
	body_size = Bestiary.vector(appearance.get("body_size", Bestiary.rules.art.body_size))
	animation = design.get("animation", {})
	sound = design.sound
	hit_reaction = design.hit_reaction
	max_health = int(design.health)
	level = int(design.level)
	soul_reward = design.soul_reward
	motion_rules = Bestiary.rules.motion.merged(design.get("motion_rules", {}), true)
	profile = design.motion
	hover = profile.get("hover", {})
	attack = design.attack
	attack_kind = attack.kind
	health = max_health
	armed = combat.get("starts_armed", false)


func promote_to_boss(size_multiplier: float, level_bonus: int, health_multiplier: float) -> void:
	boss_scale = size_multiplier
	level += level_bonus
	max_health = ceili(max_health * health_multiplier)
	health = max_health
	# Preserve the shield transition at the same fraction of the expanded health pool.
	var phase: Dictionary = combat.get("phase", {})
	if phase.has("hp"):
		combat = combat.duplicate(true)
		combat.phase.hp = ceili(float(phase.hp) * health_multiplier)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := RectangleShape2D.new()
	# Keep the movement collider near the feet; combat uses the full sprite hitbox.
	shape.size = Vector2(float(profile.collider_width), float(profile.collider_height)) * boss_scale
	var feet := CollisionShape2D.new()
	feet.shape = shape
	feet.position.y = -shape.size.y / 2.0
	add_child(feet)
	actor_art = Node2D.new()
	actor_art.scale = Vector2.ONE * boss_scale
	actor_art.show_behind_parent = true
	actor_art.draw.connect(_draw_actor)
	add_child(actor_art)
	flash_material = ShaderMaterial.new()
	flash_material.shader = HIT_FLASH
	step_voice = EnemyAudio.voice(float(sound.get("step_gain_db", EnemyAudio.mix.step_gain_db)))
	attack_voice = EnemyAudio.voice(EnemyAudio.mix.attack_gain_db)
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
	if blade_flash_left > 0.0:
		blade_flash_left = maxf(blade_flash_left - delta, 0.0)
		if blade_flash_left == 0.0:
			actor_art.material = null
	actor_art.queue_redraw()
	hit_left = maxf(hit_left - delta, 0.0)
	reacquire_left = maxf(reacquire_left - delta, 0)
	recoil = move_toward(recoil, 0.0, delta * 38.0)
	if not hover.is_empty():
		var previous_x := position.x
		_update_hover(delta)
		if state != State.STAGGER and _attack_pose() == AttackPose.IDLE:
			var travel_x := position.x - previous_x
			if absf(travel_x) > delta * 12.0:
				facing = signf(travel_x)
			_step_sound(delta, float(sound.flap_period))
		_update_motion_art(delta, 0.0)
		queue_redraw()
		return
	jump_delay = maxf(jump_delay - delta, 0)
	velocity.y = minf(velocity.y + float(motion_rules.gravity) * delta, float(motion_rules.fall_speed))
	var offset := target.position - position
	var target_in_sight := absf(offset.x) <= float(profile.sight) and absf(offset.y) <= float(motion_rules.chase_height) and _clear_to_target()
	if target_in_sight:
		perception.set_var(&"last_seen", target.position)
	lost_sight = 0.0 if target_in_sight else lost_sight + delta
	requested_speed = 0.0
	if state in [State.NOTICE, State.CHASE] and ((target_in_sight and not _inside_leash(target.position)) or not _inside_leash(position)):
		_begin_return()
	match state:
		State.PATROL:
			if target_in_sight and _can_engage():
				state = State.NOTICE
				notice_left = float(motion_rules.notice_time)
				facing = signf(offset.x) if absf(offset.x) > 8.0 else facing
			else:
				_patrol()
		State.NOTICE:
			notice_left -= delta
			if notice_left <= 0.0:
				state = State.CHASE
		State.CHASE:
			if lost_sight > float(motion_rules.lost_sight_time):
				_begin_return()
			elif target_in_sight:
				_chase(offset)
			else:
				var last_seen: Vector2 = perception.get_var(&"last_seen", position)
				var remaining := last_seen - position
				if absf(remaining.x) > 8.0:
					_navigate(signf(remaining.x), float(profile.speed), remaining.y < -35.0)
				else:
					_begin_return()
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
				if _inside_leash(target.position) and lost_sight <= float(motion_rules.lost_sight_time):
					state = State.CHASE
				else:
					_begin_return()
		State.RETURN:
			_return_home()
		State.STAGGER:
			_update_stagger(delta, target_in_sight)

	for idx in range(foot_dust.size() - 1, -1, -1):
		foot_dust[idx].age += delta
		foot_dust[idx].offset += foot_dust[idx].vel * delta
		if foot_dust[idx].age >= foot_dust[idx].duration:
			foot_dust.remove_at(idx)

	var before := position
	var rhythm_step := gait_phase * TAU
	var stride_pulse := 1.0 + cos(rhythm_step) * 0.10 * gait_weight
	velocity.x = move_toward(velocity.x, requested_speed * stride_pulse, float(profile.acceleration) * delta)
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
	if position.y > home.y + float(motion_rules.fall_reset_depth):
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
	return absf(point.x - home.x) <= float(profile.leash) and absf(point.y - home.y) <= float(motion_rules.chase_height)


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
		_move(patrol_dir * float(motion_rules.patrol_speed))


func _chase(offset: Vector2) -> void:
	if absf(offset.x) > 8.0:
		facing = signf(offset.x)
	var reach := float(_attack_value("trigger_range"))
	var height: float = motion_rules.bolt_attack_height if _attack_value("mode") == "bolt" else motion_rules.melee_attack_height
	if is_on_floor() and absf(offset.x) <= reach and absf(offset.y) <= height:
		_begin_windup()
	else:
		_navigate(facing, float(profile.speed), offset.y < -35.0 and absf(offset.x) < 175.0)


func _begin_return() -> void:
	state = State.RETURN
	blocked_time = 0.0
	reacquire_left = float(motion_rules.reacquire_delay)
	_move(0)


func _return_home() -> void:
	var offset := home - position
	if absf(offset.x) < 17.0 and absf(offset.y) < 30.0 and is_on_floor():
		_resume_patrol(home.x)
		return
	var direction := signf(offset.x) if absf(offset.x) > 9.0 else patrol_dir
	_navigate(direction, float(profile.speed) * float(motion_rules.return_speed_multiplier), offset.y < -35.0,
		offset.y > 35.0)


func _resume_patrol(center: float) -> void:
	var max_offset := float(profile.leash) - float(profile.patrol_radius) - 8.0
	patrol_center = clampf(center, home.x - max_offset, home.x + max_offset)
	state = State.PATROL
	reacquire_left = float(motion_rules.reacquire_delay)
	_move(0)


func _check_progress(delta: float, travel: float) -> void:
	if not is_on_floor() or travel >= 0.32:
		blocked_time = 0.0
		return
	blocked_time += delta
	if blocked_time < float(motion_rules.blocked_time):
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
		jump_delay = float(motion_rules.jump_retry_delay)
		if _find_landing(direction, speed, climb and walkable):
			velocity.y = -float(profile.jump)
			jump_delay = float(motion_rules.jump_cooldown)
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
	var step_count := ceili((2.0 * jump / float(motion_rules.gravity) + 0.12) / float(motion_rules.landing_probe_step))
	for index in range(1, step_count + 1):
		var time := index * float(motion_rules.landing_probe_step)
		var next := Vector2(vx * time, (float(motion_rules.gravity) * 0.5 * time - jump) * time)
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
		gait_phase = fposmod(gait_phase + travel / _gait_stride(), 1.0)
	var turning_rate := 21.0 if state in [State.WINDUP, State.STRIKE] else 13.0
	visual_turn = move_toward(visual_turn, facing, turning_rate * delta)


func _sprite_facing() -> float:
	var s := signf(visual_turn)
	if s == 0.0:
		s = facing
	var mag := clampf(pow(absf(visual_turn), 0.72), 0.08, 1.0)
	return s * mag


func _locomotion_cell() -> Vector2i:
	var count := Art.ACTION_COLUMNS
	var turn := 1.0 - absf(visual_turn)
	if turn > 0.08:
		return Vector2i(mini(floori(turn * count), count - 1), Art.Locomotion.TURN)
	if not hover.is_empty():
		var flap := age * float(appearance.flap_rate) / TAU
		var dashing := absf(cos(hover_patrol_time * float(hover.horizontal_rate))) > 0.72
		return Vector2i(floori(flap * count) % count, Art.Locomotion.RUN if dashing else Art.Locomotion.WALK)
	if not walking:
		if not is_on_floor() and absf(velocity.x) > 20.0:
			return Vector2i(2, Art.Locomotion.RUN)
		return Vector2i(floori(age * 3.0) % count, Art.Locomotion.IDLE)

	var frame := floori(gait_phase * count)
	return Vector2i(frame, Art.Locomotion.RUN if _running_gait() else Art.Locomotion.WALK)


func _running_gait() -> bool:
	var desired := absf(requested_speed)
	return state in [State.CHASE, State.RETURN] and desired > float(motion_rules.patrol_speed) and absf(velocity.x) > minf(52.0, desired * 0.7)


func _gait_stride() -> float:
	var stride := float(animation.get("stride", 68.0))
	var running := sprites.has("action") and _running_gait()
	return stride * 1.24 if running else stride


func _clear_to_target() -> bool:
	return _terrain_ray(Vector2(0, -29), target.position - position - Vector2(0, 24)).is_empty()


func _terrain_ray(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(global_position + from, global_position + to, 1)
	return get_world_2d().direct_space_state.intersect_ray(query)


func _attack_value(key: String) -> Variant:
	var value: Variant = attack[key]
	if not armed and attack.has("unarmed"):
		value = attack.unarmed.get(key, value)
	if key == "trigger_range" or key == "extent":
		return float(value) * boss_scale
	return value


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
	var moments: Array = combat_rules.strike_moments
	var hit_count := mini(int(attack.get("hits", 1)), moments.size())
	if impact_index < hit_count and progress >= float(moments[impact_index]):
		impact_index += 1
		if _attack_value("mode") == "bolt":
			var outlet := Vector2(facing * float(attack.outlet[0]), float(attack.outlet[1]))
			if _terrain_ray(Vector2(0, outlet.y), outlet).is_empty():
				launched.emit(position + outlet, facing, attack)
				_attack_sound()
		else:
			can_hit = true
			_attack_sound()
	if progress >= float(combat_rules.strike_cutoff) or _between_double_hits(progress):
		can_hit = false


func _step_sound(distance: float, interval: float) -> void:
	step_progress += distance
	if step_progress < interval:
		return
	step_progress = fposmod(step_progress, interval)
	if is_on_floor() and gait_weight > 0.2:
		_spawn_footstep_dust()
	if position.distance_to(target.position) < EnemyAudio.AUDIBLE_DISTANCE:
		step_pitch = 2.0 - step_pitch
		EnemyAudio.play(step_voice, EnemyAudio.STEPS[sound.step], step_pitch)


func _spawn_footstep_dust() -> void:
	for i in range(3):
		var d_dir := -facing + randf_range(-0.35, 0.35)
		foot_dust.append({
			"offset": Vector2(randf_range(-10.0, 10.0), randf_range(-1.0, 2.0)),
			"vel": Vector2(d_dir * randf_range(22.0, 48.0), -randf_range(8.0, 22.0)),
			"radius": randf_range(2.2, 4.0),
			"age": 0.0,
			"duration": randf_range(0.22, 0.35)
		})


func _attack_sound() -> void:
	if position.distance_to(target.position) >= EnemyAudio.AUDIBLE_DISTANCE:
		return
	var key: String = sound.attack if armed else sound.get("unarmed_attack", sound.attack)
	var is_heavy: bool = key == "heavy" or int(attack.get("damage", 1)) >= 2 or attack_kind in ["ram", "slam", "crush", "hammer"] or _attack_value("mode") == "ground"
	EnemyAudio.play_attack(attack_voice, key, is_heavy)


func _attack_area() -> Rect2:
	var extent := float(_attack_value("extent"))
	match _attack_value("mode"):
		"ground":
			return Rect2(target_mark + Vector2(-extent, -24), Vector2(2 * extent, 29))
		"pollen":
			return Rect2(position + Vector2(-extent, -10), Vector2(2 * extent, 132))
		_:
			if impact_index == 2:
				extent += float(attack.get("second_hit_extent_bonus", 0.0))
			var height := minf(102 * boss_scale, float(body_hitbox().size.y) + 5)
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
	match attack.get("hit_effect", ""):
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


func _update_stagger(delta: float, target_in_sight: bool) -> void:
	stagger_left = maxf(stagger_left - delta, 0.0)
	if stagger_left <= 0.0:
		velocity.x = 0.0
		if recovery > 0.0:
			state = State.RECOVER
		elif target_in_sight and _inside_leash(target.position):
			state = State.CHASE
		else:
			_begin_return()
		return
	var resistance := float(hit_reaction.speed) * 0.65 / float(hit_reaction.duration)
	stagger_speed = move_toward(stagger_speed, 0.0, resistance * delta)
	if not hover.is_empty():
		var motion := Vector2(stagger_speed * stagger_direction * delta, 0.0)
		if not test_move(global_transform, motion):
			hover_recoil = clampf(hover_recoil + motion.x, -float(hover.recoil_limit), float(hover.recoil_limit))
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
	var size := body_size * boss_scale
	return Rect2(position - Vector2(size.x / 2.0, size.y), size)


func arrow_hitbox(arrow_y: float) -> Rect2:
	var upper: Dictionary = combat.get("arrow_upper_body", {})
	if not upper.is_empty() and arrow_y < position.y - float(upper.above) * boss_scale:
		return _configured_hitbox(upper)
	return body_hitbox()


func weapon_hitbox() -> Rect2:
	return _configured_hitbox(combat.get("weapon_hitbox", combat_rules.weapon_hitbox))


func _configured_hitbox(config: Dictionary) -> Rect2:
	var bounds := Bestiary.rectangle(config.rect)
	bounds.position = position + (bounds.position + Vector2(facing * float(config.facing_offset), 0.0)) * boss_scale
	bounds.size *= boss_scale
	return bounds


func receive_hit(damage: int, weapon_hit: bool, projectile: bool = false, source_weapon: String = "", source_direction: float = 0.0) -> HitResult:
	if health <= 0:
		return HitResult.BLOCKED
	flash = 0.15
	var direction := source_direction
	if is_zero_approx(direction):
		direction = signf(position.x - target.position.x)
		if is_zero_approx(direction):
			direction = -facing

	if weapon_hit and armed and windup > 0:
		if combat.get("disarm_projectile_only", false) and not projectile:
			return HitResult.BLOCKED
		armed = false
		_start_recovery(float(combat_rules.disarm_recovery))
		_flinch(direction)
		disarmed.emit(self)
		return HitResult.DISARMED
	var guard: String = combat.get("guard", "")
	if guard == "closed" and recovery <= 0.0 and state != State.RECOVER:
		var breaker: Dictionary = combat.get("guard_break", {})
		if not breaker.is_empty() and source_weapon == breaker.weapon:
			_start_recovery(float(breaker.recovery))
		else:
			return HitResult.BLOCKED
	if armed and (guard == "seal" or (guard == "front_shield" and source_direction * facing < 0)):
		return HitResult.BLOCKED

	var before := health
	var phase: Dictionary = combat.get("phase", {})
	var threshold: float = phase.get("hp", max_health * float(phase.get("health_fraction", 0.0)))
	var enters_phase := not phase.is_empty() and not second_phase and health - damage <= threshold
	var raises_shield: bool = enters_phase and phase.get("raise_shield", false)
	health = maxi(int(threshold) if raises_shield else 0, health - damage)
	if health >= before and not raises_shield:
		return HitResult.BLOCKED
	if health == 0:
		felled.emit(self)
		queue_free()
		return HitResult.DAMAGED
	_flinch(direction)

	# Phase changes and configured interruptions take priority over general stagger.
	if enters_phase:
		second_phase = true
		if raises_shield:
			armed = true
			_start_recovery(float(phase.recovery))
		else:
			_begin_windup(float(phase.windup))
		phase_changed.emit()
	elif windup > 0 and _interrupts_windup(projectile, source_direction):
		_start_recovery(float(combat.get("windup_interrupt_recovery", attack.recovery)))
	elif not projectile and state not in [State.STRIKE, State.STAGGER] and (
			windup <= 0.0 or hit_reaction.interrupt_windup):
		_start_stagger(direction)
	return HitResult.DAMAGED


func _interrupts_windup(projectile: bool, source_direction: float) -> bool:
	match combat.get("windup_interrupt", ""):
		"any": return true
		"projectile": return projectile
		"rear": return source_direction * facing > 0
	return false


func flash_blade_hit() -> void:
	flash = 0.0
	blade_flash_left = 0.048
	actor_art.material = flash_material
	actor_art.queue_redraw()


func _draw_actor() -> void:
	var tint := Color(1.23, 1.16, 1.07) if flash > 0 else Color.WHITE
	var pose := _attack_pose()
	var unarmed := not armed and attack.has("unarmed")
	var action_sheet: Texture2D = sprites.get("action_unarmed" if unarmed else "action")
	# Action atlases have painted turns. Keep their combat poses full-width when turning into an attack.
	var motion_facing := facing if action_sheet != null else _sprite_facing()
	var size := body_size
	var rhythm := gait_phase * TAU

	# Procedural Locomotion: Vertical Bobbing & Bounce
	bob_y = -absf(sin(rhythm)) * 5.2 * gait_weight

	# Procedural Locomotion: Squash & Stretch with volume conservation
	var idle_breathe := sin(age * 2.8) * 0.022 * (1.0 - gait_weight * 0.8)
	var walk_squash := cos(rhythm * 2.0) * 0.055 * gait_weight
	var turn_stretch := (1.0 - absf(visual_turn)) * 0.12 if action_sheet == null else 0.0
	stretch_y = 1.0 + idle_breathe + walk_squash + turn_stretch

	# Procedural Locomotion: Velocity-based Forward Lean & Stride Sway
	var max_speed := maxf(float(profile.get("speed", 100.0)), 1.0)
	var speed_ratio := clampf(velocity.x / max_speed, -1.2, 1.2)
	sprint_lean = speed_ratio * 0.11 * gait_weight
	var stride_sway := cos(rhythm) * 0.045 * gait_weight
	var lean := sprint_lean + stride_sway

	var attack_atlas := "attack_unarmed" if unarmed else "attack"
	var transition_atlas := "attack_transition_unarmed" if unarmed else "attack_transition"
	var phase := _transition_frame() if sprites.has(transition_atlas) else -1

	if state == State.NOTICE:
		stretch_y += 0.065 * sin(notice_left / float(motion_rules.notice_time) * PI)
		lean -= 0.06

	var hit := pow(clampf(hit_left / float(hit_reaction.duration), 0.0, 1.0), 1.4)
	var squash := hit * float(hit_reaction.squash)
	var hit_lean := hit_direction * signf(motion_facing) * squash * 0.9

	stretch_y *= (1.0 - squash)
	stretch_x = 1.0 / maxf(stretch_y, 0.55)

	if state == State.STAGGER or (pose == AttackPose.IDLE and hit > 0.0):
		_draw_combat_frame(attack_atlas, AttackPose.RECOVERY, motion_facing, tint, hit_lean)
	elif pose >= 0:
		if strike > 0.0:
			motion_facing = facing
			var swing := sin(_strike_progress() * PI)
			stretch_y = (1.0 + swing * 0.035) * (1.0 - squash)
			stretch_x = 1.0 / maxf(stretch_y, 0.55)
			lean = swing * 0.035
		elif recovery > 0.0:
			lean = 0.05 * clampf(recovery / maxf(recovery_duration, 0.02), 0.0, 1.0)
		lean += hit_direction * signf(motion_facing) * squash * 0.9
		_draw_combat_frame(transition_atlas if phase >= 0 else attack_atlas,
			phase if phase >= 0 else pose, motion_facing, tint, lean)
	elif action_sheet != null:
		var cell := _locomotion_cell()
		var direction := facing if is_zero_approx(visual_turn) else signf(visual_turn)
		Art.draw_locomotion(actor_art, action_sheet, cell, direction, tint, float(appearance.get("y_offset", 0.0)))
	elif gait_weight > 0.24:
		Art.draw_motion_frame(actor_art, sprites.walk, floori(gait_phase * 4.0),
			motion_facing, tint, stretch_y, lean, recoil, bob_y, stretch_x)
	else:
		Art.draw_ground_idle(actor_art, sprites.idle, appearance, motion_facing,
			(1.0 - stretch_y) * size.y, tint, bob_y, stretch_x)


func _draw_combat_frame(atlas: String, frame: int, motion_facing: float, tint: Color, lean: float) -> void:
	Art.draw_motion_frame(actor_art, sprites[atlas], frame, motion_facing, tint,
		stretch_y, lean, recoil, bob_y, stretch_x, Art.combat_frame_layout(appearance))


func _draw() -> void:
	# Draw footstep dust puffs on ground
	for dust: Dictionary in foot_dust:
		var d_prog: float = dust.age / dust.duration
		var d_fade := pow(1.0 - d_prog, 1.6)
		var d_pos: Vector2 = dust.offset
		var d_r: float = dust.radius * (1.0 + d_prog * 0.6)
		draw_circle(d_pos, d_r, Color(0.82, 0.76, 0.68, d_fade * 0.40))

	var size := body_size
	if armed and appearance.has("shield_aura"):
		var aura: Dictionary = appearance.shield_aura
		var color: Array = aura.color
		draw_arc(Bestiary.vector(aura.center) * boss_scale, float(aura.radius) * boss_scale, 0, TAU, 48,
			Color(color[0], color[1], color[2], color[3]), 3, true)
	_draw_attack_effect(size)
	if boss_scale == 1.0 and (absf(target.position.x - position.x) < 310.0 or health < max_health):
		var caption := "Lv.%d  %d/%d" % [level, health, max_health]
		var typeface := ThemeDB.fallback_font
		var caption_width := typeface.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var label_at := Vector2(-caption_width * 0.5, -size.y - 26.0)
		draw_string_outline(typeface, label_at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color("#142522"))
		draw_string(typeface, label_at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ecd9a8"))
		var bar := Rect2(-27, -size.y - 22, 54, 4)
		draw_rect(bar, Color("#172c2a"))
		bar.size.x *= float(health) / max_health
		draw_rect(bar, Color("#d2a06c"))


func _transition_frame() -> int:
	if windup > 0 and windup_duration > 0 and windup / windup_duration > float(combat_rules.transition_windup_ratio):
		return 0
	if strike > 0.0:
		var progress := _strike_progress()
		if progress >= float(combat_rules.transition_release_start) and progress < float(combat_rules.double_windup_at):
			return 1
		if int(attack.get("hits", 1)) == 1 and progress >= float(combat_rules.double_windup_at):
			return 1
		if int(attack.get("hits", 1)) == 2 and progress >= float(combat_rules.double_recovery_at):
			return 1
	return -1


func _attack_pose() -> AttackPose:
	if windup > 0:
		return AttackPose.ANTICIPATION
	if strike > 0:
		var progress := _strike_progress()
		if _between_double_hits(progress):
			return AttackPose.ANTICIPATION
		return AttackPose.RELEASE
	return AttackPose.RECOVERY if recovery > 0 else AttackPose.IDLE


func _between_double_hits(progress: float) -> bool:
	return int(attack.get("hits", 1)) == 2 and progress >= float(combat_rules.double_windup_at) and (
		progress < float(combat_rules.strike_moments[1]))


func _draw_attack_effect(size: Vector2) -> void:
	var mode: String = _attack_value("mode")
	var element: String = attack.element
	var key: String = sound.attack if armed else sound.get("unarmed_attack", sound.attack)
	var is_heavy: bool = key == "heavy" or int(attack.get("damage", 1)) >= 2 or attack_kind in ["ram", "slam", "crush", "hammer"] or mode == "ground"
	var progress := _strike_progress() if strike > 0.0 else 0.0
	var charge := 1.0 - windup / windup_duration if windup > 0.0 else 1.0
	if mode == "ground" and ground_mark_valid and (windup > 0 or strike > 0):
		var released := strike > 0.0 and impact_index > 0
		Effects.ground(self, target_mark - position, float(_attack_value("extent")), element,
			released, _release_vfx_progress(progress) if released else charge)
	elif windup > 0.0 or (strike > 0.0 and _between_double_hits(progress)):
		var point := Vector2(facing * size.x * 0.28, -size.y * 0.67)
		if mode == "bolt":
			point = Vector2(facing * float(attack.outlet[0]), float(attack.outlet[1]))
		elif armed:
			point = weapon_hitbox().get_center() - position
		if windup <= 0.0:
			charge = inverse_lerp(float(combat_rules.double_windup_at), float(combat_rules.strike_moments[1]), progress)
		Effects.charge(self, point, element, charge, is_heavy or mode == "bolt")
	elif strike > 0 and impact_index > 0:
		var release := _release_vfx_progress(progress)
		if mode == "melee":
			var reach := _attack_area().size.x + 12.0
			Effects.sweep(self, size.y * 0.46, reach, facing, element, release, is_heavy, attack_kind)
		elif mode == "pollen":
			Effects.pollen(self, float(attack.extent), release)


func _release_vfx_progress(progress: float) -> float:
	var start := float(combat_rules.strike_moments[impact_index - 1])
	var end := float(combat_rules.double_windup_at) if impact_index == 1 and int(attack.get("hits", 1)) == 2 else 1.0
	return clampf(inverse_lerp(start, end, progress), 0.0, 1.0)


func _update_hover(delta: float) -> void:
	if windup <= 0.0 and strike <= 0.0:
		hover_patrol_time += delta
	var base := home + Vector2(sin(hover_patrol_time * float(hover.horizontal_rate)) * float(profile.patrol_radius),
		-float(hover.height) + sin(age * float(hover.bob_rate)) * float(hover.bob_height))
	if state == State.STAGGER:
		_update_stagger(delta, _inside_leash(target.position))
		position = base + Vector2(hover_recoil, 0.0)
		return
	hover_recoil = move_toward(hover_recoil, 0.0, delta * float(hover.recoil_decay))
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
	elif _inside_leash(target.position) and absf(offset.x) < float(_attack_value("trigger_range")) and absf(offset.y) < float(hover.attack_height) and _clear_to_target():
		if absf(offset.x) > 8.0:
			facing = signf(offset.x)
		_begin_windup()
