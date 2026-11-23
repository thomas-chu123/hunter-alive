extends Node2D

const WeaponAudio := preload("res://scripts/sound/hunter_weapon_audio.gd")
const DURATION := 0.23
const SLASH_DURATION := 0.115
const SPARK_DURATION := 0.17
const FIRE_DURATION := 0.38
const SAMPLE_RATE := 22050

var bursts: Array[Dictionary] = []
var slashes: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var explosions: Array[Dictionary] = []
var fire_voice: AudioStreamPlayer
var bow_voice: AudioStreamPlayer
var slash_layer: Node2D
var camera: Camera2D
var shake: Tween
var hitstop: Tween
var time_scale_before_hit := 1.0
var hit_voice: AudioStreamPlayer
var disarm_voice: AudioStreamPlayer
var swing_voice: AudioStreamPlayer
var finisher_voice: AudioStreamPlayer
var weapon_voices := {}


func _ready() -> void:
	z_index = 3
	slash_layer = Node2D.new()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	slash_layer.material = additive
	slash_layer.draw.connect(_draw_slashes)
	add_child(slash_layer)
	hit_voice = _make_voice(_make_sound(false))
	disarm_voice = _make_voice(_make_sound(true))
	swing_voice = _make_voice(_make_blade_sound(false))
	finisher_voice = _make_voice(_make_blade_sound(true))
	fire_voice = _make_voice(_make_projectile_sound(true))
	bow_voice = _make_voice(_make_projectile_sound(false))


func _make_voice(stream: AudioStream) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.max_polyphony = 5
	voice.stream = stream
	add_child(voice)
	return voice


func _exit_tree() -> void:
	_end_hitstop()
	_end_shake()
	_stop_audio()


func _stop_audio() -> void:
	for voice: AudioStreamPlayer in [hit_voice, disarm_voice, swing_voice, finisher_voice, fire_voice, bow_voice]:
		if is_instance_valid(voice):
			voice.stop()
	for voice: AudioStreamPlayer in weapon_voices.values():
		if is_instance_valid(voice):
			voice.stop()


func impact(point: Vector2, direction: float, disarm: bool) -> void:
	bursts.append({"point": point, "direction": direction, "disarm": disarm, "age": 0.0})
	_play(disarm_voice if disarm else hit_voice)
	queue_redraw()


func release_weapon(weapon: String) -> void:
	if weapon == "hunter_bow":
		_play(bow_voice)
	elif WeaponAudio.PROFILES.has(weapon):
		if not weapon_voices.has(weapon):
			weapon_voices[weapon] = _make_voice(WeaponAudio.make_stream(weapon))
		_play(weapon_voices[weapon], 1.5)


func fire_impact(point: Vector2) -> void:
	explosions.append({"point": point, "age": 0.0, "angle": randf() * TAU})
	_play(fire_voice, -1.0)
	queue_redraw()


func swing(point: Vector2, direction: float, reach: float, step: int, weapon: String = "hunter_knife") -> void:
	slashes.append({"point": point, "direction": direction, "reach": reach, "step": step, "age": 0.0})
	if weapon == "hunter_knife":
		_play(swing_voice, -4.0 if step == 3 else -7.0)
	else:
		release_weapon(weapon)
	slash_layer.queue_redraw()


func blade_impact(point: Vector2, direction: float, step: int, blocked: bool, disarmed: bool) -> void:
	var heavy := step == 3 and not blocked
	var tint := Color("#ffca72")
	if blocked or disarmed:
		tint = Color("#b9d7eb")
	elif heavy:
		tint = Color("#ff9f54")
	var rays: Array[Vector2] = []
	var center := randf_range(-0.13, 0.13) - 0.15
	for index in range(12 if heavy else 8):
		var angle := center + randf_range(-0.72, 0.72)
		rays.append(Vector2(cos(angle) * direction, sin(angle)) * randf_range(175.0, 320.0))
	sparks.append({"point": point, "rays": rays, "tint": tint, "age": 0.0, "heavy": heavy})
	var voice := finisher_voice if heavy else hit_voice
	if blocked or disarmed:
		voice = disarm_voice
	_play(voice, -4.0 if blocked else 0.0)
	queue_redraw()
	if not blocked:
		_punctuate_hit(direction, heavy)


func _play(voice: AudioStreamPlayer, gain: float = 0.0) -> void:
	voice.volume_db = -5.0 + gain
	voice.pitch_scale = randf_range(0.92, 1.08)
	voice.play()


func _punctuate_hit(direction: float, heavy: bool) -> void:
	# One timer owns the slowdown, including when another strike lands before it ends.
	if hitstop == null:
		time_scale_before_hit = Engine.time_scale
	else:
		hitstop.kill()
	Engine.time_scale = time_scale_before_hit * (0.12 if heavy else 0.20)
	hitstop = create_tween().set_ignore_time_scale(true)
	hitstop.tween_interval(0.050 if heavy else 0.032)
	hitstop.tween_callback(_end_hitstop)
	if shake != null:
		shake.kill()
	var amplitude := 3.6 if heavy else 2.2
	_shake_camera(0.0, direction, amplitude)
	shake = create_tween().set_ignore_time_scale(true)
	shake.tween_method(_shake_camera.bind(direction, amplitude), 0.0, 1.0, 0.085)


func _shake_camera(progress: float, direction: float, amplitude: float) -> void:
	if is_instance_valid(camera):
		camera.offset = Vector2(cos(progress * TAU * 1.5) * direction, -0.48 * cos(progress * TAU * 2.25)) \
			* amplitude * pow(1.0 - progress, 2.0)


func _end_hitstop() -> void:
	if hitstop != null:
		hitstop.kill()
		hitstop = null
		Engine.time_scale = time_scale_before_hit


func _end_shake() -> void:
	if shake != null:
		shake.kill()
		shake = null
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO


func clear() -> void:
	bursts.clear()
	slashes.clear()
	sparks.clear()
	explosions.clear()
	_end_hitstop()
	_end_shake()
	_stop_audio()
	queue_redraw()
	slash_layer.queue_redraw()


func _process(delta: float) -> void:
	if not bursts.is_empty() or not sparks.is_empty() or not explosions.is_empty():
		_age_effects(bursts, delta, DURATION)
		_age_effects(sparks, delta, SPARK_DURATION)
		_age_effects(explosions, delta, FIRE_DURATION)
		queue_redraw()
	if not slashes.is_empty():
		_age_effects(slashes, delta, SLASH_DURATION)
		slash_layer.queue_redraw()


func _age_effects(effects: Array[Dictionary], delta: float, lifetime: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		effects[index].age += delta
		if effects[index].age >= lifetime:
			effects.remove_at(index)


func _draw() -> void:
	for burst: Dictionary in bursts:
		var point: Vector2 = burst.point
		var progress := clampf(burst.age / DURATION, 0, 1)
		var color := Color("#ffe085") if burst.disarm else Color("#ffae71")
		draw_arc(point, 4 + progress * 24, 0, TAU, 18, Color(color, 0.80 * (1 - progress)), 1.6, true)
		draw_circle(point, 4.5 * (1 - progress), Color("#fff2c8"))
		for index in range(7):
			var angle := -1.25 + index * 0.42
			var direction := Vector2(cos(angle) * burst.direction, sin(angle))
			var tip := point + direction * (8 + progress * (19 + index % 3 * 5))
			draw_line(tip - direction * (7 * (1 - progress)), tip,
				Color(color, 1 - progress), 2.3 * (1 - progress), true)
	for spark: Dictionary in sparks:
		var age: float = spark.age
		var progress := age / SPARK_DURATION
		var point: Vector2 = spark.point
		var fade := pow(1.0 - progress, 1.8)
		var color := Color(Color.WHITE.lerp(spark.tint, minf(progress * 3.5, 1.0)), fade)
		var radius := (6.0 if spark.heavy else 4.0) * maxf(1.0 - progress * 4.0, 0.0)
		if radius > 0.0:
			draw_circle(point, radius, Color("#fff5db"), true, -1, true)
		for ray: Vector2 in spark.rays:
			var tip := point + ray * (0.014 + (1.0 - exp(-age * 13.0)) / 13.0)
			draw_line(tip - ray.normalized() * (3.0 + ray.length() * 0.023) * fade, tip,
				color, maxf(1.0, 2.7 * fade), true)

	for blast: Dictionary in explosions:
		var point: Vector2 = blast.point
		var t: float = blast.age / FIRE_DURATION
		var alpha := 1.0 - t
		var spread := 1.0 - pow(alpha, 2.6)
		draw_circle(point, 8.0 + 24.0 * spread, Color(1.0, 0.30, 0.07, 0.28 * alpha), true, -1, true)
		draw_arc(point, 6.0 + spread * 29.0, 0, TAU, 30, Color(1.0, 0.58, 0.19, 0.72 * alpha * alpha), 2, true)
		for ember in range(12):
			var ray := Vector2.from_angle(blast.angle + TAU * ember / 12.0)
			var tip := point + ray * spread * (19 + (ember % 4) * 8) + Vector2(0, -6 * t)
			draw_line(tip - ray * (4.0 + 7.0 * alpha), tip, Color(1.0, 0.43 + alpha * 0.35, 0.13, alpha), 1.0 + alpha * 2.0, true)
		if t < 0.23:
			draw_circle(point, 9.0 + 16.0 * t, Color(1, 0.92, 0.64, 1.0 - t / 0.23), true, -1, true)


func _draw_slashes() -> void:
	for slash: Dictionary in slashes:
		var progress: float = slash.age / SLASH_DURATION
		var fade := pow(1.0 - progress, 1.5)
		var step: int = slash.step
		var point: Vector2 = slash.point
		var reach: float = slash.reach
		var direction: float = slash.direction
		var angle := deg_to_rad(-12.0) if step == 2 else 0.0
		slash_layer.draw_set_transform(point, angle * direction, Vector2(direction, -1 if step == 2 else 1))
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var edge := PackedVector2Array()
		var heavy := step == 3
		for index in range(19):
			var along := float(index) / 18.0
			var width := sin(along * PI) * (1.0 - progress)
			var sweep := lerpf(-1.20 + progress * 0.9, 1.16 + progress * 0.25, along)
			var line := Vector2(-8.0 + (reach + 7.0) * cos(sweep), 27.0 * sin(sweep))
			if heavy:
				line = Vector2(lerpf(-10.0, reach + 6.0, along), -8.0 * sin(along * PI))
			var normal := Vector2(-2.0, -9.0) if heavy else Vector2(-9.0 * cos(sweep), -13.0 * sin(sweep))
			var thickness := normal * width
			outer.append(line - thickness * 0.42)
			if index > 0 and index < 18:
				inner.append(line + thickness)
			edge.append(line - thickness * 0.17)
		inner.reverse()
		outer.append_array(inner)
		var tint := Color("#ec9d4b") if heavy else Color("#92c8d8")
		slash_layer.draw_colored_polygon(outer, Color(tint, fade * 0.67))
		slash_layer.draw_polyline(edge, Color("#fff3c6", fade * 0.89), 1.7, true)


func _make_sound(disarm: bool) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = 78
	var count := int(SAMPLE_RATE * (0.22 if disarm else 0.15))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var time := float(i) / SAMPLE_RATE
		var thump := sin(TAU * (168.0 * time - 250.0 * time * time)) * exp(-31.0 * time)
		var crack := random.randf_range(-1, 1) * exp(-84.0 * time)
		var ring := sin(TAU * 1370 * time) * exp(-22.0 * time) if disarm else 0.0
		var wave := (0.52 * thump + 0.31 * crack + 0.32 * ring) * minf(1, time * 2300)
		data.encode_s16(i * 2, int(clampf(wave, -1, 1) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream


func _make_blade_sound(heavy: bool) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = 459
	var count := int(SAMPLE_RATE * (0.21 if heavy else 0.11))
	var data := PackedByteArray()
	data.resize(count * 2)
	var previous := 0.0
	for index in range(count):
		var time := float(index) / SAMPLE_RATE
		var noise := random.randf_range(-1, 1)
		var air := (noise - previous * 0.80) * exp(-time * 37.0)
		previous = noise
		var metal := sin(TAU * (1890.0 * time - 4200.0 * time * time)) * exp(-time * 33.0)
		var wave := (0.24 * air + 0.18 * metal) * minf(time * 200.0, 1.0)
		if heavy:
			var weight := sin(TAU * (112.0 * time - 130.0 * time * time)) * exp(-time * 22.0)
			wave += (0.62 * weight + noise * 0.26 * exp(-time * 100.0)) * minf(time * 2300.0, 1.0)
		data.encode_s16(index * 2, int(clampf(wave, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream



func _make_projectile_sound(fire: bool) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 219
	var data := PackedByteArray()
	var count := int(SAMPLE_RATE * (0.32 if fire else 0.16))
	data.resize(count * 2)
	var filtered := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.18)
		var wave: float
		if fire:
			wave = 0.67 * sin(TAU * (112.0 * t - 115.0 * t * t)) * exp(-17.0 * t)
			wave += (0.8 * filtered + 0.17 * noise) * exp(-22.0 * t)
		else:
			wave = (0.41 * sin(TAU * (294.0 * t - 290.0 * t * t))
				+ 0.15 * sin(TAU * 881.0 * t)) * exp(-35.0 * t) + 0.3 * noise * exp(-84.0 * t)
		data.encode_s16(index * 2, int(clampf(wave * minf(1.0, t * 1500), -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
