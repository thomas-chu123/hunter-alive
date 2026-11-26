extends Node2D

const WeaponAudio := preload("res://scripts/sound/hunter_weapon_audio.gd")
const Config := preload("res://scripts/game/config_table.gd")
static var settings := Config.read("effects")
static var GUARD_TINT := Color(str(settings.guard_color))
static var DURATION: float = settings.durations.impact
static var SLASH_DURATION: float = settings.durations.slash
static var SPARK_DURATION: float = settings.durations.spark
static var FIRE_DURATION: float = settings.durations.fire
static var SHOCKWAVE_DURATION: float = settings.durations.shockwave
static var STARBURST_DURATION: float = settings.durations.starburst
static var SCAR_DURATION: float = settings.durations.scar
static var SAMPLE_RATE: int = WeaponAudio.SAMPLE_RATE
static var mix: Dictionary = WeaponAudio.settings.hunter_voice

var bursts: Array[Dictionary] = []
var slashes: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var explosions: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []
var starbursts: Array[Dictionary] = []
var slash_scars: Array[Dictionary] = []

var fire_voice: AudioStreamPlayer
var bow_voice: AudioStreamPlayer
var slash_layer: Node2D
var additive_layer: Node2D
var flash_layer: CanvasLayer
var flash_rect: ColorRect

var camera: Camera2D
var shake: Tween
var hitstop: Tween
var time_scale_before_hit := 1.0
var hit_voice: AudioStreamPlayer
var disarm_voice: AudioStreamPlayer
var guard_voice: AudioStreamPlayer
var swing_voice: AudioStreamPlayer
var finisher_voice: AudioStreamPlayer
var weapon_voices := {}


func _ready() -> void:
	z_index = 3
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	slash_layer = Node2D.new()
	slash_layer.material = additive
	slash_layer.draw.connect(_draw_slashes)
	add_child(slash_layer)

	additive_layer = Node2D.new()
	additive_layer.material = additive
	additive_layer.draw.connect(_draw_additive_effects)
	add_child(additive_layer)

	# Full-screen impact flash layer for ultimate/heavy hit feel
	flash_layer = CanvasLayer.new()
	flash_layer.layer = 120
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_layer.add_child(flash_rect)
	add_child(flash_layer)

	hit_voice = _make_voice(_make_sound(false))
	disarm_voice = _make_voice(_make_sound(true))
	guard_voice = _make_voice(disarm_voice.stream)
	swing_voice = _make_voice(_make_blade_sound(false))
	finisher_voice = _make_voice(_make_blade_sound(true))
	fire_voice = _make_voice(_make_projectile_sound(true))
	bow_voice = _make_voice(_make_projectile_sound(false))


func _make_voice(stream: AudioStream) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.max_polyphony = 6
	voice.stream = stream
	add_child(voice)
	return voice


func _exit_tree() -> void:
	_end_hitstop()
	_end_shake()
	_stop_audio()


func _stop_audio() -> void:
	for voice: AudioStreamPlayer in [hit_voice, disarm_voice, guard_voice, swing_voice, finisher_voice, fire_voice, bow_voice]:
		if is_instance_valid(voice):
			voice.stop()
	for voice: AudioStreamPlayer in weapon_voices.values():
		if is_instance_valid(voice):
			voice.stop()


func impact(point: Vector2, direction: float, disarm: bool) -> void:
	bursts.append({"point": point, "direction": direction, "disarm": disarm, "age": 0.0})
	play_event("disarm" if disarm else "impact", point)
	_play(disarm_voice if disarm else hit_voice)
	_punctuate_hit(direction, disarm, 6.5 if disarm else 4.2)
	queue_redraw()
	additive_layer.queue_redraw()


func release_weapon(weapon: String) -> void:
	if weapon == "hunter_bow":
		_play(bow_voice)
	elif WeaponAudio.PROFILES.has(weapon):
		if not weapon_voices.has(weapon):
			weapon_voices[weapon] = _make_voice(WeaponAudio.make_stream(weapon))
		_play(weapon_voices[weapon], mix.weapon_gain)


func play_event(event: String, point: Vector2, direction := 1.0, base_color := Color.WHITE, extra_radius := 0.0) -> void:
	for layer: Dictionary in settings.events[event]:
		var tint := base_color.lightened(float(layer.get("lighten", 0.0)))
		if layer.has("color"):
			var rgba: Array = layer.color
			tint = Color(rgba[0], rgba[1], rgba[2], rgba[3])
		var radius := extra_radius + float(layer.get("size", 0.0))
		match layer.kind:
			"wave":
				trigger_shockwave(point, radius, tint, layer.duration, layer.get("thickness", 3.0))
			"burst":
				trigger_starburst(point, radius, tint, layer.duration)
			"scar":
				trigger_slash_scar(point, direction, radius, tint, layer.duration)
			"flash":
				trigger_screen_flash(tint, layer.duration)


func fire_impact(point: Vector2) -> void:
	explosions.append({"point": point, "age": 0.0, "angle": randf() * TAU})
	play_event("fire", point)
	_punctuate_hit(0.0, true, 8.5)
	_play(fire_voice, mix.fire_gain)
	queue_redraw()
	additive_layer.queue_redraw()


func trigger_shockwave(point: Vector2, max_radius: float, tint: Color, duration: float = -1.0, thickness: float = 3.0) -> void:
	shockwaves.append({
		"point": point,
		"radius": max_radius,
		"tint": tint,
		"duration": SHOCKWAVE_DURATION if duration < 0.0 else duration,
		"thickness": thickness,
		"age": 0.0
	})
	additive_layer.queue_redraw()


func trigger_starburst(point: Vector2, radius: float, tint: Color, duration: float = -1.0) -> void:
	starbursts.append({
		"point": point,
		"radius": radius,
		"tint": tint,
		"duration": STARBURST_DURATION if duration < 0.0 else duration,
		"rotation": randf() * TAU,
		"age": 0.0
	})
	additive_layer.queue_redraw()


func trigger_slash_scar(point: Vector2, direction: float, length: float, tint: Color, duration: float = -1.0) -> void:
	var angle := randf_range(-0.45, 0.45)
	slash_scars.append({
		"start": point - Vector2(cos(angle) * direction, sin(angle)) * (length * 0.5),
		"end": point + Vector2(cos(angle) * direction, sin(angle)) * (length * 0.5),
		"tint": tint,
		"duration": SCAR_DURATION if duration < 0.0 else duration,
		"age": 0.0
	})
	additive_layer.queue_redraw()


func trigger_screen_flash(tint: Color, duration: float = 0.08) -> void:
	if not is_instance_valid(flash_rect):
		return
	flash_rect.color = tint
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(flash_rect, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func swing(point: Vector2, direction: float, reach: float, step: int, weapon: String = "hunter_knife") -> void:
	var heavy := step == 3 or weapon in ["tide_hammer", "gate_halberd", "root_blade"]
	slashes.append({
		"point": point,
		"direction": direction,
		"reach": reach,
		"step": step,
		"heavy": heavy,
		"weapon": weapon,
		"age": 0.0
	})
	if heavy:
		# Heavy swing air-pressure screen shake - adds visceral weight to start of big moves
		_windup_shake(direction, 3.2 if weapon == "tide_hammer" else 2.6)
	if weapon == "hunter_knife":
		_play(swing_voice, mix.finisher_gain if step == 3 else mix.swing_gain)
	else:
		release_weapon(weapon)
	slash_layer.queue_redraw()


func guard_impact(point: Vector2, direction: float) -> void:
	_impact_sparks(point, direction, GUARD_TINT, false)
	play_event("guard", point, direction, GUARD_TINT)
	_play(guard_voice)


func blade_impact(point: Vector2, direction: float, step: int, disarmed: bool) -> void:
	var heavy := step == 3 or disarmed
	var tint := Color("#ffca72")
	if disarmed:
		tint = GUARD_TINT
	elif heavy:
		tint = Color("#ff8833")
	_impact_sparks(point, direction, tint, heavy)

	play_event("blade_heavy" if heavy else "blade_light", point, direction)

	var voice := disarm_voice if disarmed else (finisher_voice if heavy else hit_voice)
	_play(voice, mix.heavy_gain if heavy else 0.0)
	_punctuate_hit(direction, heavy, 12.0 if heavy else 5.2)


func _impact_sparks(point: Vector2, direction: float, tint: Color, heavy: bool) -> void:
	var rays: Array[Vector2] = []
	var center := randf_range(-0.13, 0.13) - 0.15
	var ray_count := 20 if heavy else 10
	for index in range(ray_count):
		var angle := center + randf_range(-0.85, 0.85)
		var length := randf_range(220.0, 480.0) if heavy else randf_range(160.0, 310.0)
		rays.append(Vector2(cos(angle) * direction, sin(angle)) * length)
	sparks.append({"point": point, "rays": rays, "tint": tint, "age": 0.0, "heavy": heavy})
	queue_redraw()


func _play(voice: AudioStreamPlayer, gain: float = 0.0) -> void:
	voice.volume_db = float(mix.gain_db) + gain
	voice.pitch_scale = randf_range(mix.pitch_min, mix.pitch_max)
	voice.play()


func _windup_shake(direction: float, amplitude: float) -> void:
	if shake != null:
		shake.kill()
	_shake_camera(0.0, direction, amplitude, 25.0)
	shake = create_tween().set_ignore_time_scale(true)
	shake.tween_method(_shake_camera.bind(direction, amplitude, 25.0), 0.0, 1.0, 0.09)


func _punctuate_hit(direction: float, heavy: bool, amplitude: float = 5.0) -> void:
	if hitstop == null:
		time_scale_before_hit = Engine.time_scale
	else:
		hitstop.kill()

	# Dramatic hit-stop duration and slowdown curve for ultimate/heavy attacks
	var timing: Dictionary = settings.impact_timing.heavy if heavy else settings.impact_timing.light
	Engine.time_scale = time_scale_before_hit * float(timing.time_scale)
	hitstop = create_tween().set_ignore_time_scale(true)
	hitstop.tween_interval(timing.stop)
	hitstop.tween_callback(_end_hitstop)

	if shake != null:
		shake.kill()

	var duration: float = timing.shake
	var freq: float = timing.frequency
	_shake_camera(0.0, direction, amplitude, freq)
	shake = create_tween().set_ignore_time_scale(true)
	shake.tween_method(_shake_camera.bind(direction, amplitude, freq), 0.0, 1.0, duration)


func _shake_camera(progress: float, direction: float, amplitude: float, frequency: float = 32.0) -> void:
	if is_instance_valid(camera):
		# Multi-axis trauma decay shake with primary impact impulse + orthogonal chaotic jitter
		var trauma := pow(1.0 - progress, 2.2)
		var impulse_x := cos(progress * TAU * 2.2) * direction * 0.8
		var jitter_x := sin(progress * frequency * 1.3) * 0.55
		var jitter_y := cos(progress * frequency * 1.7) * 0.85
		var total_offset := Vector2(impulse_x + jitter_x, jitter_y) * (amplitude * trauma)
		camera.offset = total_offset


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
	shockwaves.clear()
	starbursts.clear()
	slash_scars.clear()
	if is_instance_valid(flash_rect):
		flash_rect.color = Color(1, 1, 1, 0)
	_end_hitstop()
	_end_shake()
	_stop_audio()
	queue_redraw()
	slash_layer.queue_redraw()
	additive_layer.queue_redraw()


func _process(delta: float) -> void:
	var needs_redraw := false
	if not bursts.is_empty() or not sparks.is_empty() or not explosions.is_empty():
		_age_effects(bursts, delta, DURATION)
		_age_effects(sparks, delta, SPARK_DURATION)
		_age_effects(explosions, delta, FIRE_DURATION)
		needs_redraw = true

	if not shockwaves.is_empty() or not starbursts.is_empty() or not slash_scars.is_empty():
		_age_effects_custom(shockwaves, delta)
		_age_effects_custom(starbursts, delta)
		_age_effects_custom(slash_scars, delta)
		additive_layer.queue_redraw()

	if not slashes.is_empty():
		_age_effects(slashes, delta, SLASH_DURATION)
		slash_layer.queue_redraw()

	if needs_redraw:
		queue_redraw()


func _age_effects(effects: Array[Dictionary], delta: float, lifetime: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		effects[index].age += delta
		if effects[index].age >= lifetime:
			effects.remove_at(index)


func _age_effects_custom(effects: Array[Dictionary], delta: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		effects[index].age += delta
		if effects[index].age >= float(effects[index].get("duration", 0.25)):
			effects.remove_at(index)


func _draw() -> void:
	for burst: Dictionary in bursts:
		var point: Vector2 = burst.point
		var progress := clampf(burst.age / DURATION, 0, 1)
		var color := Color("#ffe085") if burst.disarm else Color("#ffae71")
		draw_arc(point, 5 + progress * 28, 0, TAU, 22, Color(color, 0.85 * (1 - progress)), 2.0, true)
		draw_circle(point, 5.0 * (1 - progress), Color("#fff5d0"))
		for index in range(9):
			var angle := -1.35 + index * 0.35
			var dir := Vector2(cos(angle) * burst.direction, sin(angle))
			var tip := point + dir * (9 + progress * (24 + index % 3 * 7))
			draw_line(tip - dir * (9 * (1 - progress)), tip,
				Color(color, 1 - progress), 2.8 * (1 - progress), true)

	for spark: Dictionary in sparks:
		var age: float = spark.age
		var progress := age / SPARK_DURATION
		var point: Vector2 = spark.point
		var fade := pow(1.0 - progress, 1.6)
		var color := Color(Color.WHITE.lerp(spark.tint, minf(progress * 2.8, 1.0)), fade)
		var radius := (9.0 if spark.heavy else 5.0) * maxf(1.0 - progress * 3.5, 0.0)
		if radius > 0.0:
			draw_circle(point, radius, Color("#ffffff"), true, -1, true)
		for ray: Vector2 in spark.rays:
			var tip := point + ray * (0.016 + (1.0 - exp(-age * 16.0)) / 14.0)
			draw_line(tip - ray.normalized() * (4.5 + ray.length() * 0.035) * fade, tip,
				color, maxf(1.2, (4.2 if spark.heavy else 2.6) * fade), true)

	for blast: Dictionary in explosions:
		var point: Vector2 = blast.point
		var t: float = blast.age / FIRE_DURATION
		var alpha := 1.0 - t
		var spread := 1.0 - pow(alpha, 2.6)
		draw_circle(point, 10.0 + 34.0 * spread, Color(1.0, 0.28, 0.06, 0.35 * alpha), true, -1, true)
		draw_arc(point, 8.0 + spread * 38.0, 0, TAU, 32, Color(1.0, 0.62, 0.18, 0.82 * alpha * alpha), 3.0, true)
		for ember in range(16):
			var ray := Vector2.from_angle(blast.angle + TAU * ember / 16.0)
			var tip := point + ray * spread * (24 + (ember % 4) * 11) + Vector2(0, -8 * t)
			draw_line(tip - ray * (5.0 + 9.0 * alpha), tip, Color(1.0, 0.45 + alpha * 0.35, 0.12, alpha), 1.5 + alpha * 2.5, true)
		if t < 0.23:
			draw_circle(point, 12.0 + 20.0 * t, Color(1, 0.95, 0.75, 1.0 - t / 0.23), true, -1, true)


func _draw_additive_effects() -> void:
	# Shockwave rings
	for wave: Dictionary in shockwaves:
		var progress: float = wave.age / wave.duration
		var fade := pow(1.0 - progress, 1.5)
		var max_r: float = wave.radius
		var current_r := max_r * (0.2 + 0.8 * pow(progress, 0.55))
		var color: Color = wave.tint
		var thickness: float = wave.thickness
		var wave_pt: Vector2 = wave.point
		additive_layer.draw_arc(wave_pt, current_r, 0, TAU, 36, Color(color, fade * 0.85), thickness * fade + 0.8, true)
		if progress < 0.4:
			var core_fade := (1.0 - progress / 0.4)
			additive_layer.draw_circle(wave_pt, current_r * 0.4, Color(1.0, 1.0, 1.0, core_fade * 0.45))

	# Starburst flares
	for star: Dictionary in starbursts:
		var progress: float = star.age / star.duration
		var fade := pow(1.0 - progress, 1.8)
		var max_rad: float = star.radius
		var length := max_rad * (1.0 + progress * 0.5)
		var rot: float = star.rotation
		var color: Color = star.tint
		var star_pt: Vector2 = star.point
		for i in range(4):
			var arm_angle := rot + i * (PI * 0.5)
			var p1: Vector2 = star_pt + Vector2.from_angle(arm_angle) * length
			var p2: Vector2 = star_pt + Vector2.from_angle(arm_angle + PI * 0.5) * (length * 0.18)
			var p3: Vector2 = star_pt + Vector2.from_angle(arm_angle - PI * 0.5) * (length * 0.18)
			additive_layer.draw_colored_polygon(PackedVector2Array([star_pt, p2, p1, p3]), Color(color, fade * 0.65))
		additive_layer.draw_circle(star_pt, length * 0.22 * fade, Color(1.0, 1.0, 1.0, fade * 0.9))

	# Slash scars
	for scar: Dictionary in slash_scars:
		var progress: float = scar.age / scar.duration
		var fade := pow(1.0 - progress, 2.0)
		var s_start: Vector2 = scar.start
		var s_end: Vector2 = scar.end
		var s_color: Color = scar.tint
		additive_layer.draw_line(s_start, s_end, Color(s_color, fade * 0.9), 3.5 * fade + 0.5, true)
		additive_layer.draw_line(s_start, s_end, Color(1.0, 1.0, 1.0, fade * 0.95), 1.5 * fade, true)


func _draw_slashes() -> void:
	for slash: Dictionary in slashes:
		var progress: float = slash.age / SLASH_DURATION
		var fade := pow(1.0 - progress, 1.4)
		var step: int = slash.step
		var heavy: bool = slash.heavy
		var point: Vector2 = slash.point
		var reach: float = slash.reach * (1.35 if heavy else 1.0)
		var direction: float = slash.direction
		var angle := deg_to_rad(-14.0) if step == 2 else 0.0

		slash_layer.draw_set_transform(point, angle * direction, Vector2(direction, -1 if step == 2 else 1))
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var edge := PackedVector2Array()

		var segments := 26 if heavy else 19
		for index in range(segments):
			var along := float(index) / float(segments - 1)
			var width := sin(along * PI) * (1.0 - progress) * (1.6 if heavy else 1.0)
			var sweep := lerpf(-1.30 + progress * 0.95, 1.25 + progress * 0.30, along)
			var line := Vector2(-10.0 + (reach + 12.0) * cos(sweep), (36.0 if heavy else 27.0) * sin(sweep))
			if heavy and step == 3:
				line = Vector2(lerpf(-14.0, reach + 16.0, along), -12.0 * sin(along * PI))
			var normal := Vector2(-3.0, -14.0) if (heavy and step == 3) else Vector2(-11.0 * cos(sweep), -16.0 * sin(sweep))
			var thickness := normal * width
			outer.append(line - thickness * 0.55)
			if index > 0 and index < segments - 1:
				inner.append(line + thickness)
			edge.append(line - thickness * 0.2)

		inner.reverse()
		outer.append_array(inner)

		var tint := Color("#ff7722") if (heavy and step == 3) else (Color("#ff9933") if heavy else (Color("#55bbee") if step == 2 else Color("#92c8d8")))
		slash_layer.draw_colored_polygon(outer, Color(tint, fade * 0.75))
		slash_layer.draw_polyline(edge, Color("#ffffff", fade * 0.95), (2.8 if heavy else 1.8), true)

		# Flying energy trail sparks along the crescent arc for heavy moves
		if heavy:
			for i in range(4):
				var along_spark := fposmod(progress * 1.5 + float(i) * 0.25, 1.0)
				var sweep_s := lerpf(-1.1, 1.2, along_spark)
				var spark_pos := Vector2(-10.0 + (reach + 10.0) * cos(sweep_s), 32.0 * sin(sweep_s))
				slash_layer.draw_circle(spark_pos, 2.5 * fade, Color(1.0, 0.9, 0.6, fade * 0.8))


func _make_sound(disarm: bool) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = 78
	var count := int(SAMPLE_RATE * (mix.disarm_duration if disarm else mix.hit_duration))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var time := float(i) / SAMPLE_RATE
		var thump := sin(TAU * (140.0 * time - 210.0 * time * time)) * exp(-24.0 * time)
		var bass := sin(TAU * (65.0 * time)) * exp(-14.0 * time) * 0.55
		var crack := random.randf_range(-1, 1) * exp(-76.0 * time)
		var ring := sin(TAU * 1370 * time) * exp(-20.0 * time) if disarm else 0.0
		var wave := (0.45 * thump + 0.35 * bass + 0.30 * crack + 0.35 * ring) * minf(1, time * 2400)
		data.encode_s16(i * 2, int(clampf(wave, -1, 1) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream


func _make_blade_sound(heavy: bool) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = 459
	var count := int(SAMPLE_RATE * (mix.heavy_duration if heavy else mix.swing_duration))
	var data := PackedByteArray()
	data.resize(count * 2)
	var previous := 0.0
	for index in range(count):
		var time := float(index) / SAMPLE_RATE
		var noise := random.randf_range(-1, 1)
		var air := (noise - previous * 0.80) * exp(-time * 33.0)
		previous = noise
		var metal := sin(TAU * (1820.0 * time - 3800.0 * time * time)) * exp(-time * 28.0)
		var wave := (0.24 * air + 0.20 * metal) * minf(time * 200.0, 1.0)
		if heavy:
			var sub_bass := sin(TAU * (58.0 * time - 45.0 * time * time)) * exp(-time * 12.0)
			var weight := sin(TAU * (108.0 * time - 120.0 * time * time)) * exp(-time * 18.0)
			wave += (0.65 * weight + 0.45 * sub_bass + noise * 0.32 * exp(-time * 85.0)) * minf(time * 2400.0, 1.0)
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
	var count := int(SAMPLE_RATE * (mix.fire_duration if fire else mix.bow_duration))
	data.resize(count * 2)
	var filtered := 0.0
	for index in range(count):
		var t := float(index) / SAMPLE_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.18)
		var wave: float
		if fire:
			var sub := sin(TAU * (52.0 * t)) * exp(-12.0 * t) * 0.45
			wave = 0.65 * sin(TAU * (108.0 * t - 110.0 * t * t)) * exp(-15.0 * t) + sub
			wave += (0.85 * filtered + 0.22 * noise) * exp(-19.0 * t)
		else:
			wave = (0.41 * sin(TAU * (294.0 * t - 290.0 * t * t))
				+ 0.15 * sin(TAU * 881.0 * t)) * exp(-35.0 * t) + 0.3 * noise * exp(-84.0 * t)
		data.encode_s16(index * 2, int(clampf(wave * minf(1.0, t * 1500), -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
