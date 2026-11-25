extends CharacterBody2D

signal attacked(origin: Vector2, facing: float, ranged: bool, damage: int, weapon: String)
signal cast(origin: Vector2, direction: float, weapon: String)
signal damaged(source_x: float, damage: int, effect: String)
signal defeated

const Progression := preload("res://scripts/game/ruin_progression.gd")
const Armory := preload("res://scripts/game/ruin_armory.gd")
const HunterAnimation := preload("res://scripts/character/hunter_animation.gd")
const HunterSprites := preload("res://scripts/character/hunter_sprites.gd")
const WeaponArt := preload("res://scripts/character/hunter_weapon_art.gd")
const TrapArt := preload("res://scripts/trap/trap_art.gd")
const ClimbableProp := preload("res://assets/environment/common/props/traversal/climbable_prop.gd")
const RUN_SPEED := 250.0
const WALK_SPEED := 115.0
const CROUCH_SPEED := 64.0
const CLIMB_SPEED := 110.0
const KNIFE_DURATION := 0.29
const BOW_DURATION := 0.39
const ATTACK_BUFFER := 0.22
const BLADE_CHAIN_WINDOW := 0.46
const SHORT_BLADES := ["hunter_knife", "fang_dagger"]
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
const STAFF_DAMAGE := 3
const STAFF_MANA_COST := 1
const MANA_RECOVERY_INTERVAL := 0.9
const WRAPS_KNIFE_DURATION := 0.23
const POLLEN_DURATION := 2.4

var health := MAX_HEALTH
var level := 0
var item_ranks: Dictionary = {}
var armor_credit := 0
var mana := MAX_MANA
var mana_recovery_left := MANA_RECOVERY_INTERVAL
var facing := 1.0
var with_bow := false
var with_staff := false
var staff_unlocked := false
var gear: Dictionary = {}
var vest_ready := false
var pollen_left := 0.0
var leech_left := 0.0
var leech_tick := 0.0
var mud_left := 0.0
var shallow_water := false
var equipped_weapon := ""
var attack_weapon := "hunter_knife"
var unlocked_weapons: Array[String] = ["hunter_knife", "hunter_bow"]
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
var electric_hit_left := 0.0
var attack_queued := false
var attack_with_bow := false
var attack_with_staff := false
var attack_duration := KNIFE_DURATION
var blade_step := 0
var blade_chain_left := 0.0
var blade_chain_weapon := ""
var blade_recoil := 0.0
var collider: CollisionShape2D
var animation_time := 0.0
var wall_holding := false
var prop_climbing := false
var climb_jump_lock := false
var jump_grace := 0.0


func _ready() -> void:
	add_to_group("trap_hunter")
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

	if mana < MAX_MANA:
		mana_recovery_left -= delta
		if mana_recovery_left <= 0.0:
			mana += 1
			mana_recovery_left += MANA_RECOVERY_INTERVAL
	else:
		mana_recovery_left = MANA_RECOVERY_INTERVAL
	attack_left = maxf(attack_left - delta, 0)
	attack_buffer_left = maxf(attack_buffer_left - delta, 0)
	blade_chain_left = maxf(blade_chain_left - delta, 0)
	landing_left = maxf(landing_left - delta, 0)
	rise_left = maxf(rise_left - delta, 0)
	hurt_left = maxf(hurt_left - delta, 0)
	electric_hit_left = maxf(electric_hit_left - delta, 0)
	pollen_left = maxf(pollen_left - delta, 0)
	mud_left = maxf(mud_left - delta, 0)
	if leech_left > 0.0:
		leech_left = maxf(0, leech_left - delta)
		leech_tick -= delta
		if leech_tick <= 0:
			hurt(position.x - facing, 1, "leech")
			leech_tick = 1.5 if gear.get("身體") == "reed_coat" else 0.9
	var grounded := is_on_floor()
	var direction := Input.get_axis("hunt_left", "hunt_right")
	var vertical := Input.get_axis("hunt_climb_up", "hunt_crouch")
	var jumped := Input.is_action_just_pressed("hunt_jump")
	var was_prop_climbing := prop_climbing
	if is_zero_approx(vertical):
		climb_jump_lock = false
	if jumped and was_prop_climbing:
		climb_jump_lock = true
	var climb_prop: ClimbableProp
	if not jumped and not climb_jump_lock and hurt_left <= 0.0 and attack_left <= 0.0 and is_zero_approx(direction):
		if was_prop_climbing or not is_zero_approx(vertical):
			climb_prop = _nearby_climb_prop(vertical)
	_update_crouch(climb_prop == null and grounded and Input.is_action_pressed("hunt_crouch"))
	prop_climbing = climb_prop != null and not crouching
	crouch_time = crouch_time + delta if crouching else 0.0
	walking = Input.is_action_pressed("hunt_walk")
	invincible_left = maxf(invincible_left - delta, 0)
	jump_grace = 0.08 if is_on_floor() else maxf(jump_grace - delta, 0)

	wall_holding = (
		not prop_climbing and equipped_soul == "spider" and Input.is_action_pressed("hunt_soul")
		and direction != 0 and _can_grip_wall(direction)
	)
	if prop_climbing:
		var target_y := move_toward(global_position.y, climb_prop.climb_limit(vertical), CLIMB_SPEED * absf(vertical) * delta)
		var climb_step := target_y - global_position.y
		velocity.y = climb_step / delta if climb_step * vertical > 0.0 else 0.0
	elif wall_holding:
		velocity.y = -135.0
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, 950.0)

	if jumped and not crouching and (jump_grace > 0.0 or wall_holding or was_prop_climbing):
		velocity.y = -JUMP_SPEED
		jump_grace = 0.0
		wall_holding = false
		leech_left = 0.0

	gliding = (
		not prop_climbing and equipped_soul == "lizard" and Input.is_action_pressed("hunt_soul")
		and not is_on_floor() and velocity.y > 0
	)
	if gliding:
		velocity.y = minf(velocity.y, 49.3 if gear.get("身體") == "wing_cape" else 58.0)

	var on_ground := grounded and not wall_holding and not prop_climbing and velocity.y >= 0.0
	if direction != 0 and (not on_ground or attack_left <= 0.0):
		facing = signf(direction)
	if Input.is_action_just_pressed("hunt_switch") and not unlocked_weapons.is_empty():
		var slot := unlocked_weapons.find(selected_weapon())
		select_weapon(unlocked_weapons[(slot + 1) % unlocked_weapons.size()])
	if not prop_climbing:
		_start_requested_attack()

	var speed := WALK_SPEED if walking else RUN_SPEED
	if gliding:
		speed = GLIDE_SPEED
	elif crouching:
		speed = CROUCH_SPEED
	if landing_left > 0.0:
		speed *= 0.75
	if pollen_left > 0 or mud_left > 0:
		speed *= 0.64
	var current_force := 0.0
	if shallow_water:
		speed *= 1.20 if gear.get("腿部") == "eel_greaves" else 1.0
		current_force = -16.0 if gear.get("腿部") == "sluice_boots" else -32.0
	if prop_climbing:
		var offset := climb_prop.global_position.x - global_position.x
		velocity.x = clampf(offset / delta, -CLIMB_SPEED, CLIMB_SPEED)
	elif on_ground and attack_left > 0.0:
		# Ground attack sprites are planted. Keep impact recoil separate from steering.
		velocity.x = 0.0
	else:
		velocity.x = move_toward(velocity.x, direction * speed + current_force, 2100.0 * delta)
	velocity.x += blade_recoil
	var fall_speed := velocity.y
	move_and_slide()
	if not is_on_wall():
		velocity.x -= blade_recoil
	blade_recoil = move_toward(blade_recoil, 0.0, 1250.0 * delta)
	if is_on_ceiling():
		velocity.y = maxf(velocity.y, 140.0)
	if is_on_floor() and not grounded and fall_speed > 245.0:
		landing_left = LAND_DURATION * (0.5 if gear.get("腿部") == "cliff_boots" else 1.0)
	animation_time += delta
	_release_attack()
	queue_redraw()


func _nearby_climb_prop(direction: float) -> ClimbableProp:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = ClimbableProp.DETECTION_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var best: ClimbableProp
	for hit in get_world_2d().direct_space_state.intersect_point(query):
		var candidate := hit.collider as ClimbableProp
		if candidate == null:
			continue
		if best == null:
			best = candidate
			continue
		var candidate_distance := absf(candidate.global_position.x - global_position.x)
		var best_distance := absf(best.global_position.x - global_position.x)
		# When two stacked segments overlap, pick the one that extends farther along the climb.
		var extends_climb := (candidate.climb_limit(direction) - best.climb_limit(direction)) * direction > 0.0
		if candidate_distance < best_distance or (is_equal_approx(candidate_distance, best_distance) and extends_climb):
			best = candidate
	return best


func _start_requested_attack() -> void:
	var wants_attack := attack_buffer_left > 0 or Input.is_action_pressed("hunt_attack")
	if wants_attack and attack_left <= 0 and hurt_left <= 0 and (not with_staff or mana >= STAFF_MANA_COST):
		attack_buffer_left = 0.0
		attack_with_bow = with_bow
		attack_with_staff = with_staff
		attack_weapon = selected_weapon()
		attack_duration = weapon_period(attack_weapon)
		attack_left = attack_duration
		attack_queued = true


func _release_attack() -> void:
	var hit_at := attack_duration * (1.0 - WeaponArt.release_point(attack_weapon, attack_with_bow))
	if attack_queued and attack_left <= hit_at:
		attack_queued = false
		if attack_with_staff:
			mana -= STAFF_MANA_COST
			var progress := 1.0 - attack_left / attack_duration
			var focus := WeaponArt.ember_cast_tip(progress, facing, crouching) if attack_weapon == "ember_staff" else Vector2(facing * 22, -37)
			cast.emit(position + focus, facing, attack_weapon)
		else:
			var damage := weapon_damage(attack_weapon)
			var height := 21.0 if crouching else 30.0
			var origin := HunterAnimation.bow_origin(facing) if attack_with_bow else Vector2(facing * 14, -height)
			if attack_weapon in SHORT_BLADES:
				var continues := blade_chain_left > 0 and blade_chain_weapon == attack_weapon
				blade_step = blade_step % 3 + 1 if continues else 1
				blade_chain_left = BLADE_CHAIN_WINDOW
				blade_chain_weapon = attack_weapon
			attacked.emit(position + origin, facing, attack_with_bow, damage, attack_weapon)


func _can_grip_wall(direction: float) -> bool:
	if not is_on_wall_only() or get_wall_normal().x * direction >= 0.0:
		return false
	for index in range(get_slide_collision_count()):
		var contact := get_slide_collision(index)
		if contact.get_normal().x * direction < 0.0:
			var surface := contact.get_collider() as Node
			return surface != null and not surface.is_in_group("unclimbable")
	return false


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


func hurt(source_x: float, damage: int = 1, effect: String = "") -> void:
	if invincible_left > 0 or health <= 0:
		return
	if effect == "poison" and gear.get("頭部") == "sealed_cap":
		return
	if vest_ready and gear.get("身體") in ["moss_vest", "earthen_armor"]:
		vest_ready = false
		invincible_left = 0.45
		return
	if effect == "rune" and gear.get("頭部") == "ash_cowl":
		damage = maxi(1, damage - 1)
	armor_credit += damage * armor_reduction()
	damage = maxi(0, damage - floori(armor_credit / 100.0))
	armor_credit %= 100
	if damage == 0:
		invincible_left = 0.45
		return
	health = maxi(0, health - damage)
	prop_climbing = false
	damaged.emit(source_x, damage, effect)
	if health == 0:
		defeated.emit()
		return
	invincible_left = 0.9
	hurt_left = HURT_DURATION
	if (effect == "shock" and gear.get("頭部") == "copper_helm") or (effect == "shards" and gear.get("腿部") == "cinder_greaves"):
		hurt_left *= 0.5
	attack_left = 0.0
	attack_buffer_left = 0.0
	attack_queued = false
	blade_chain_left = 0.0
	blade_recoil = 0.0
	var force := 270.0
	if (effect == "spray" and gear.get("頭部") == "sealed_cap") or (effect == "ram" and gear.get("腿部") == "ram_boots"):
		force *= 0.55
	velocity = Vector2(signf(position.x - source_x) * force, -240)


func max_health(loadout: Dictionary = gear) -> int:
	return MAX_HEALTH + level + int(loadout.get("頭部") == "linen_hood")


func item_rank(id: String) -> int:
	return int(item_ranks.get(id, 1))


func armor_points(loadout: Dictionary = gear, ranks: Dictionary = item_ranks) -> int:
	var points := 0
	for id: String in loadout.values():
		points += int(ranks.get(id, 1))
	return points


func armor_reduction() -> int:
	return Progression.armor_percent(armor_points())


func rest() -> void:
	armor_credit = 0
	health = max_health()
	mana = MAX_MANA
	mana_recovery_left = MANA_RECOVERY_INTERVAL
	vest_ready = gear.get("身體") in ["moss_vest", "earthen_armor"]
	pollen_left = 0.0
	mud_left = 0.0
	leech_left = 0.0


func apply_pollen() -> void:
	pollen_left = POLLEN_DURATION * (0.5 if gear.get("頭部") == "scaleveil_hood" else 1.0)


func apply_mud() -> void:
	mud_left = 1.1 if gear.get("身體") == "silt_shell" else 2.2


func attach_leech() -> void:
	leech_left = 3.6
	leech_tick = 1.5 if gear.get("身體") == "reed_coat" else 0.9


func weapon_period(id: String, loadout: Dictionary = gear) -> float:
	var duration := KNIFE_DURATION
	if Armory.WEAPONS.has(id):
		duration = Armory.WEAPONS[id][3]
	elif id == "hunter_bow":
		duration = BOW_DURATION
	elif id == "ember_staff":
		duration = STAFF_DURATION
	if id in ["hunter_bow", "thorn_bow"] and loadout.get("手部") == "bowstring_gloves":
		duration *= 0.85
	if id in ["ember_staff", "scribe_staff"] and loadout.get("手部") == "rune_gloves":
		duration *= 0.85
	if id == "hunter_knife" and loadout.get("手部") == "hunter_wraps":
		duration = WRAPS_KNIFE_DURATION
	return duration


func weapon_damage(id: String, rank: int = 0) -> int:
	# Existing wood weapons keep their old damage curve; higher quality adds one per tier.
	var bonus := (item_rank(id) if rank <= 0 else rank) - 1
	if Armory.WEAPONS.has(id):
		return int(Armory.WEAPONS[id][2]) + bonus + (0 if id == "scribe_staff" else (bow_level if id == "thorn_bow" else knife_level))
	match id:
		"unarmed":
			return 1
		"hunter_bow":
			return 1 + bow_level + bonus
		"ember_staff":
			return STAFF_DAMAGE + bonus
		_:
			return 2 + knife_level + bonus


func select_weapon(id: String) -> void:
	if not unlocked_weapons.has(id):
		id = unlocked_weapons[0] if not unlocked_weapons.is_empty() else "unarmed"
	if selected_weapon() != id:
		blade_chain_left = 0.0
	equipped_weapon = id if Armory.WEAPONS.has(id) or id == "unarmed" else ""
	with_staff = id in ["ember_staff", "scribe_staff"]
	with_bow = id in ["hunter_bow", "thorn_bow"]


func selected_weapon() -> String:
	if not equipped_weapon.is_empty():
		return equipped_weapon
	if with_staff:
		return "ember_staff"
	return "hunter_bow" if with_bow else "hunter_knife"


func respawn(at: Vector2) -> void:
	position = at
	_update_crouch(false, true)
	landing_left = 0.0
	rise_left = 0.0
	hurt_left = 0.0
	electric_hit_left = 0.0
	attack_left = 0.0
	attack_buffer_left = 0.0
	attack_queued = false
	blade_chain_left = 0.0
	blade_recoil = 0.0
	velocity = Vector2.ZERO
	rest()
	invincible_left = 0.9
	jump_grace = 0.0
	gliding = false
	wall_holding = false
	prop_climbing = false
	climb_jump_lock = false


func show_electric_hit() -> void:
	electric_hit_left = 0.34
	queue_redraw()


func _draw() -> void:
	_draw_hunter()
	if electric_hit_left > 0.0:
		var frame := TrapArt.Frame.ARC if int(electric_hit_left * 30.0) % 2 == 0 else TrapArt.Frame.ARC_ALT
		TrapArt.paint(self, frame, collider.position, Vector2(49, 65),
			Color(1, 1, 1, clampf(electric_hit_left * 8.0, 0.0, 1.0)))


func _draw_hunter() -> void:
	if invincible_left > 0 and hurt_left <= 0 and int(invincible_left * 16) % 2 == 0:
		return

	var weapon := selected_weapon()
	if (wall_holding or prop_climbing) and hurt_left <= 0.0:
		var climb_frame := int(animation_time * 12.0) % HunterAnimation.FRAME_COUNT
		if prop_climbing and is_zero_approx(velocity.y):
			climb_frame = 0
		if weapon == "unarmed":
			HunterAnimation.draw_climb(self, climb_frame, facing)
		else:
			HunterSprites.draw_motion(self, weapon, "climb", climb_frame, facing)
		return

	if attack_left > 0.0 and hurt_left <= 0.0:
		if attack_weapon == "unarmed":
			HunterAnimation.draw_frame(self, "knife_attack", _timed_frame(attack_left, attack_duration), facing)
		else:
			var step := blade_step
			if attack_queued and attack_weapon == "fang_dagger":
				step = blade_step % 3 + 1 if blade_chain_left > 0.0 and blade_chain_weapon == attack_weapon else 1
			HunterSprites.draw_attack(self, attack_weapon, 1.0 - attack_left / attack_duration, facing, crouching, step)
		return

	var action := "idle"
	var frame := int(animation_time * 5) % HunterAnimation.FRAME_COUNT
	if hurt_left > 0:
		action = "hurt"
		frame = _timed_frame(hurt_left, HURT_DURATION)
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
	elif absf(velocity.x) > 18.0:
		if velocity.x * facing < 0.0:
			action = "retreat"
			frame = int(animation_time * 9) % HunterAnimation.FRAME_COUNT
		else:
			action = "walk" if walking else "run"
			frame = int(animation_time * (9 if walking else 14)) % HunterAnimation.FRAME_COUNT
	if weapon == "unarmed":
		if action == "retreat":
			action = "walk"
			frame = HunterAnimation.FRAME_COUNT - 1 - frame
		HunterAnimation.draw_frame(self, action, frame, facing)
	else:
		HunterSprites.draw_motion(self, weapon, action, frame, facing)


func _timed_frame(remaining: float, duration: float) -> int:
	return clampi(int((1.0 - remaining / duration) * HunterAnimation.FRAME_COUNT), 0, HunterAnimation.FRAME_COUNT - 1)
