extends Node2D

signal boulder_rolled(center: Vector2, radius: float)
signal sound_played(cue: StringName)

const Hunter := preload("res://scripts/character/ruin_hunter.gd")
const Art := preload("res://scripts/trap/trap_art.gd")
const Frame := Art.Frame
const Config := preload("res://scripts/game/config_table.gd")
static var settings := Config.read("traps/traps")
static var audio_settings := Config.read("audio/sound")
static var SOUNDS := Config.resources(audio_settings.trap_clips)
const HUNTER_GROUP := &"trap_hunter"
const PORTAL_GROUP := &"trap_destination"
const TERRAIN_MASK := 1
static var BOULDER_RADIUS: float = settings.boulder.radius
static var FIRE_SIZE := Config.vector(settings.fireball.size)
static var PORTAL_SIZE := Config.vector(settings.portal_size)
static var POISON_DURATION: float = settings.poison_duration
static var BLAST_DURATION: float = settings.fireball.blast_duration

enum Kind {
	CEILING_SPIKES, WALL_SPIKES, PENDULUM, LAVA,
	FIREBALL, EXPLODING_FIREBALL, POISON, BOULDER,
	PORTAL_A, PORTAL_B, RANDOM_PORTAL, RANDOM_LANDING, ELECTRIC,
}

@export var kind: Kind
@export_enum("Left:-1", "Right:1") var direction := 1
@export var cycle_profile := ""
## Zero inherits the cycle from traps.json.
@export_range(0.0, 12.0, 0.1, "suffix:s") var cycle_seconds := 0.0

var _hunter: Hunter
var _sound: AudioStreamPlayer2D
var _rolling_sound: AudioStreamWAV
var _boulder: CharacterBody2D
var _boulder_fall_speed := 0.0
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _next_cycle := 0.0
var _phase := INF
var _projectile_age := INF
var _projectile_position := Vector2.ZERO
var _blast_age := INF
var _blast_position := Vector2.ZERO
var _portal_occupied := false


func _ready() -> void:
	if cycle_seconds <= 0:
		cycle_seconds = settings.cycle_seconds.get(cycle_profile, settings.default_cycle_seconds)
	$Preview.hide()
	if kind in [Kind.PORTAL_B, Kind.RANDOM_LANDING]:
		add_to_group(PORTAL_GROUP)
	_next_cycle = _period()
	if kind not in [Kind.PORTAL_B, Kind.RANDOM_LANDING]:
		_sound = AudioStreamPlayer2D.new()
		_sound.volume_db = audio_settings.trap_voice.gain_db
		_sound.max_distance = audio_settings.trap_voice.distance
		_sound.attenuation = audio_settings.trap_voice.attenuation
		add_child(_sound)
	if kind == Kind.BOULDER:
		_rolling_sound = SOUNDS[&"roll"].duplicate()
		_rolling_sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_rolling_sound.loop_end = roundi(_rolling_sound.get_length() * _rolling_sound.mix_rate)
	if kind == Kind.RANDOM_PORTAL:
		_rng.randomize()
	if kind == Kind.RANDOM_LANDING:
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_hunter):
		_hunter = get_tree().get_first_node_in_group(HUNTER_GROUP) as Hunter
	var running := is_instance_valid(_hunter) and _hunter.is_physics_processing()
	if _sound and _sound.stream_paused == running:
		_sound.stream_paused = not running
	if not running:
		return

	var previous_phase := _phase
	var previous_time := _time
	_time += delta
	_phase += delta
	if _time + 0.00001 >= _next_cycle and kind in [
			Kind.CEILING_SPIKES, Kind.WALL_SPIKES, Kind.LAVA, Kind.FIREBALL,
			Kind.EXPLODING_FIREBALL, Kind.POISON, Kind.BOULDER]:
		_phase = maxf(_time - _next_cycle, 0.0)
		_next_cycle += _period()
		previous_phase = -delta
		_activate()

	match kind:
		Kind.CEILING_SPIKES:
			if previous_phase < settings.ceiling_spikes.drop_seconds and _phase >= settings.ceiling_spikes.drop_seconds:
				_play(&"spikes", _ceiling_teeth())
			if _ceiling_extension() > 0.35:
				_hurt_box(_ceiling_teeth(), Vector2(62, 23 * _ceiling_extension()))
		Kind.WALL_SPIKES:
			if _wall_extension() > 0.12:
				_hurt_box(_wall_teeth(), Vector2(43 * _wall_extension(), 41))
		Kind.PENDULUM:
			var wind_period := _period() / 2.0
			if floori(previous_time / wind_period) != floori(_time / wind_period):
				_play(&"swing", _mace_position())
			_hurt_circle(_mace_position(), settings.pendulum.hit_radius)
		Kind.LAVA:
			_hurt_box(Vector2(0, -5), Vector2(91, 18), "lava")
			if _geyser_height() > 8:
				_hurt_box(Vector2(0, -_geyser_height() / 2.0), Vector2(28, _geyser_height()), "lava")
		Kind.FIREBALL, Kind.EXPLODING_FIREBALL:
			_update_fireball(delta)
		Kind.POISON:
			if _cloud_opacity() > 0.16:
				_hurt_box(_cloud_center(), _cloud_size() * Vector2(0.76, 0.78), "poison")
		Kind.BOULDER:
			_update_boulder(delta)
		Kind.PORTAL_A, Kind.RANDOM_PORTAL:
			_update_portal()
		Kind.ELECTRIC:
			if _hurt_box(Vector2(0, -22), Vector2(63, 42), "shock"):
				_hunter.show_electric_hit()
				_play(&"shock", to_local(_hunter.global_position))
	queue_redraw()


func _period() -> float:
	return cycle_seconds


func _activate() -> void:
	match kind:
		Kind.WALL_SPIKES:
			_play(&"spikes")
		Kind.LAVA:
			_play(&"blast")
		Kind.FIREBALL, Kind.EXPLODING_FIREBALL:
			_projectile_age = 0.0
			_projectile_position = Vector2(direction * 22, 0)
			_play(&"fireball", _projectile_position)
		Kind.POISON:
			_play(&"poison")
		Kind.BOULDER:
			_stop_boulder()
			_boulder = CharacterBody2D.new()
			_boulder.collision_layer = 0
			_boulder.collision_mask = TERRAIN_MASK
			_boulder.position.x = direction * 18
			var collider := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = BOULDER_RADIUS
			collider.shape = circle
			_boulder.add_child(collider)
			add_child(_boulder)
			_boulder_fall_speed = 0.0
			_projectile_age = 0.0
			_play(&"roll", _boulder.position)


func _update_fireball(delta: float) -> void:
	if _blast_age < BLAST_DURATION:
		_blast_age += delta
		if _blast_age < BLAST_DURATION:
			_hurt_circle(_blast_position, settings.fireball.blast_radius, "lava")
	if _projectile_age == INF:
		return

	_projectile_age += delta
	var next := _projectile_position + Vector2(direction * float(settings.fireball.speed) * delta, 0)
	var tip := Vector2(direction * FIRE_SIZE.x / 2.0, 0)
	var ray := PhysicsRayQueryParameters2D.create(to_global(_projectile_position),
		to_global(next + tip), TERRAIN_MASK)
	ray.hit_from_inside = true
	var wall := get_world_2d().direct_space_state.intersect_ray(ray)
	if not wall.is_empty():
		next = to_local(wall.position) - tip
	_projectile_position = next
	var touches_hunter := _touches_box(_projectile_position, FIRE_SIZE)
	var lifetime: float = settings.fireball.exploding_lifetime if kind == Kind.EXPLODING_FIREBALL else settings.fireball.lifetime
	if touches_hunter or not wall.is_empty() or _projectile_age >= lifetime:
		_projectile_age = INF
		if kind == Kind.EXPLODING_FIREBALL:
			_blast_position = _projectile_position
			_blast_age = 0.0
			_play(&"blast", _blast_position)
			_hurt_circle(_blast_position, settings.fireball.blast_radius, "lava")
		elif touches_hunter:
			_hurt(_projectile_position, "lava")


func _update_boulder(delta: float) -> void:
	if not is_instance_valid(_boulder):
		return
	_projectile_age += delta
	_boulder_fall_speed = minf(_boulder_fall_speed + float(settings.boulder.gravity) * delta, settings.boulder.max_fall_speed)
	if _boulder.move_and_collide(Vector2(0, _boulder_fall_speed * delta)):
		_boulder_fall_speed = 0.0
	var wall := _boulder.move_and_collide(Vector2(direction * float(settings.boulder.speed) * delta, 0))
	_sound.position = _boulder.position
	_hurt_circle(_boulder.position, BOULDER_RADIUS)
	boulder_rolled.emit(_boulder.global_position, BOULDER_RADIUS)
	if wall or _projectile_age >= float(settings.boulder.lifetime):
		_stop_boulder()


func _stop_boulder() -> void:
	if is_instance_valid(_boulder):
		_boulder.queue_free()
		_boulder = null
		_sound.stop()


func _update_portal() -> void:
	var overlaps := _touches_box(Vector2(0, -36), Vector2(34, 70))
	var entered := overlaps and not _portal_occupied
	_portal_occupied = overlaps
	if not entered:
		return
	var destination_kind := Kind.PORTAL_B if kind == Kind.PORTAL_A else Kind.RANDOM_LANDING
	var destinations: Array[Vector2] = []
	for node in get_tree().get_nodes_in_group(PORTAL_GROUP):
		var tile := node as Node2D
		if tile.get_parent() == get_parent() and tile.get("kind") == destination_kind:
			var destination := tile.global_position
			if _can_land(destination):
				destinations.append(destination)
	if destinations.is_empty():
		return
	var arrival := destinations[0]
	if kind == Kind.RANDOM_PORTAL:
		arrival = destinations[_rng.randi_range(0, destinations.size() - 1)]
	else:
		for destination in destinations:
			if global_position.distance_squared_to(destination) < global_position.distance_squared_to(arrival):
				arrival = destination
	_hunter.global_position = arrival - Vector2(0, 1)
	_hunter.reset_physics_interpolation()
	_hunter.velocity = Vector2.ZERO
	var camera := _hunter.get_viewport().get_camera_2d()
	if camera and _hunter.is_ancestor_of(camera):
		camera.reset_smoothing()
	# Play at the arrival point so the sound follows long teleports.
	_play(&"portal", to_local(arrival))


func _can_land(destination: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _hunter.collider.shape
	query.transform = _hunter.collider.global_transform
	query.transform.origin += destination - _hunter.global_position - Vector2(0, 1)
	query.collision_mask = TERRAIN_MASK
	var space := get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var floor_ray := PhysicsRayQueryParameters2D.create(destination - Vector2(0, 1),
		destination + Vector2(0, 6), TERRAIN_MASK)
	var floor_hit := space.intersect_ray(floor_ray)
	return not floor_hit.is_empty() and floor_hit.normal.y < -0.7


func _hunter_bounds() -> Rect2:
	var collider := _hunter.collider
	var shape := collider.shape as RectangleShape2D
	var in_trap := global_transform.affine_inverse() * collider.global_transform
	return in_trap * Rect2(-shape.size / 2.0, shape.size)


func _touches_box(center: Vector2, size: Vector2) -> bool:
	return _hunter_bounds().intersects(Rect2(center - size / 2.0, size))


func _hurt_box(center: Vector2, size: Vector2, effect := "") -> bool:
	return _touches_box(center, size) and _hurt(center, effect)


func _hurt_circle(center: Vector2, radius: float, effect := "") -> bool:
	var bounds := _hunter_bounds()
	return center.distance_squared_to(center.clamp(bounds.position, bounds.end)) < radius * radius and _hurt(center, effect)


func _hurt(center: Vector2, effect: String) -> bool:
	var health := _hunter.health
	var parent := _hunter.get_parent() as Node2D
	var source := to_global(center)
	var source_x := parent.to_local(source).x if parent else source.x
	_hunter.hurt(source_x, settings.damage, effect)
	return _hunter.health < health


func _play(cue: StringName, at := Vector2.ZERO) -> void:
	_sound.position = at
	_sound.stream = _rolling_sound if cue == &"roll" else SOUNDS[cue]
	if DisplayServer.get_name() != "headless" or OS.has_feature("movie"):
		_sound.play()
	sound_played.emit(cue)


func _ceiling_drop() -> float:
	return float(settings.ceiling_spikes.drop_distance) * minf(smoothstep(0, settings.ceiling_spikes.drop_seconds, _phase),
		1.0 - smoothstep(settings.ceiling_spikes.retract_end, settings.ceiling_spikes.reset_end, _phase))


func _ceiling_extension() -> float:
	return smoothstep(settings.ceiling_spikes.drop_seconds, settings.ceiling_spikes.extend_end, _phase) * (
		1.0 - smoothstep(settings.ceiling_spikes.retract_start, settings.ceiling_spikes.retract_end, _phase))


func _ceiling_teeth() -> Vector2:
	return Vector2(0, 12 + _ceiling_drop() + 11.5 * _ceiling_extension())


func _wall_extension() -> float:
	return smoothstep(0.0, settings.wall_spikes.extend_end, _phase) * (
		1.0 - smoothstep(settings.wall_spikes.retract_start, settings.wall_spikes.retract_end, _phase))


func _wall_teeth() -> Vector2:
	return Vector2(direction * (14 + 21.5 * _wall_extension()), 0)


func _mace_position() -> Vector2:
	var swing := sin(_time * TAU / _period()) * float(settings.pendulum.angle_radians)
	return Vector2(sin(swing), cos(swing)) * float(settings.pendulum.length)


func _geyser_height() -> float:
	return float(settings.geyser.height) * smoothstep(0.0, settings.geyser.rise_seconds, _phase) * (
		1.0 - smoothstep(settings.geyser.recede_start, settings.geyser.recede_end, _phase))


func _cloud_opacity() -> float:
	return (1.0 - smoothstep(0.26, POISON_DURATION, _phase)) * smoothstep(0.0, 0.13, _phase)


func _cloud_center() -> Vector2:
	return Vector2(direction * (30.0 + 65.0 * smoothstep(0.0, POISON_DURATION, _phase)), -2)


func _cloud_size() -> Vector2:
	return Vector2(83, 35) + Vector2(42, 22) * smoothstep(0.0, POISON_DURATION, _phase)


func _draw() -> void:
	match kind:
		Kind.CEILING_SPIKES:
			var drop := _ceiling_drop()
			draw_line(Vector2.ZERO, Vector2(0, drop), Color("#625047"), 12)
			Art.paint(self, Frame.PISTON, Vector2(0, drop), Vector2(68, 28))
			if _ceiling_extension() > 0.0:
				Art.paint(self, Frame.SPIKES, _ceiling_teeth(), Vector2(62, 23 * _ceiling_extension()))
		Kind.WALL_SPIKES:
			if _wall_extension() > 0.0:
				draw_set_transform(_wall_teeth(), -direction * PI / 2)
				Art.paint(self, Frame.SPIKES, Vector2.ZERO, Vector2(41, 43 * _wall_extension()))
				draw_set_transform(Vector2.ZERO)
			Art.paint(self, Frame.SOCKET, Vector2.ZERO, Vector2(35, 48))
		Kind.PENDULUM:
			var head := _mace_position()
			draw_line(Vector2(0, 1), head, Color("#483b36"), 7, true)
			draw_line(Vector2(0, 1), head, Color("#9c8170"), 2, true)
			draw_circle(Vector2.ZERO, 8.0, Color("#95816c"))
			draw_set_transform(head, head.angle() - PI / 2)
			Art.paint(self, Frame.MACE, Vector2.ZERO, Vector2(49, 57))
			draw_set_transform(Vector2.ZERO)
		Kind.LAVA:
			Art.paint(self, Frame.LAVA, Vector2(0, -6), Vector2(98, 24))
			var height := _geyser_height()
			if height > 0.5:
				var frame := Frame.GEYSER if int(_time * 12.0) % 2 == 0 else Frame.GEYSER_ALT
				Art.paint(self, frame, Vector2(0, -height / 2), Vector2(43, height))
		Kind.FIREBALL, Kind.EXPLODING_FIREBALL, Kind.POISON, Kind.BOULDER:
			_draw_launcher()
		Kind.PORTAL_A, Kind.PORTAL_B, Kind.RANDOM_PORTAL:
			var frame := Frame.RANDOM_PORTAL if kind == Kind.RANDOM_PORTAL else Frame.PORTAL
			var tint := Color(0.91, 0.96, 1.0) if kind == Kind.PORTAL_B else Color.WHITE
			Art.paint(self, frame, Vector2(0, -PORTAL_SIZE.y / 2.0), PORTAL_SIZE, tint)
		Kind.ELECTRIC:
			Art.paint(self, Frame.ELECTRODE, Vector2(0, -4), Vector2(75, 20))
			var frame := Frame.ARC if int(_time * 17.0) % 2 == 0 else Frame.ARC_ALT
			Art.paint(self, frame, Vector2(0, -23), Vector2(70, 45),
				Color(1, 1, 1, 0.53 + 0.24 * sin(_time * 31.0)))


func _draw_launcher() -> void:
	Art.paint(self, Frame.SOCKET, Vector2.ZERO, Vector2(51, 49),
		Color("#a4c987") if kind == Kind.POISON else Color.WHITE)
	if kind == Kind.POISON and _cloud_opacity() > 0.0:
		Art.paint(self, Frame.POISON, _cloud_center(), _cloud_size(), Color(1, 1, 1, _cloud_opacity()), direction == 1)
	elif kind == Kind.BOULDER and _next_cycle - _time <= 0.85 and not is_instance_valid(_boulder):
		var pulse := 0.5 + 0.5 * sin(_time * 22.0)
		draw_arc(Vector2.ZERO, 18, 0, TAU, 24, Color(1.0, 0.70, 0.32, 0.55 + 0.45 * pulse), 3.0)
	elif is_instance_valid(_boulder):
		draw_set_transform(_boulder.position, direction * _projectile_age * float(settings.boulder.speed) / BOULDER_RADIUS)
		Art.paint(self, Frame.BOULDER, Vector2.ZERO, Vector2.ONE * BOULDER_RADIUS * 2)
		draw_set_transform(Vector2.ZERO)
	elif _projectile_age < INF and kind in [Kind.FIREBALL, Kind.EXPLODING_FIREBALL]:
		Art.paint(self, Frame.FIREBALL, _projectile_position, FIRE_SIZE, Color.WHITE, direction == -1)
	if _blast_age < BLAST_DURATION:
		var progress := _blast_age / BLAST_DURATION
		Art.paint(self, Frame.BLAST, _blast_position, Vector2.ONE * lerpf(57, 94, progress),
			Color(1, 1, 1, 1.0 - smoothstep(0.18, 1.0, progress)))
