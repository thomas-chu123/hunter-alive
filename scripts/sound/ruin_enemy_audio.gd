extends RefCounted

const Config := preload("res://scripts/game/config_table.gd")
static var settings := Config.read("sound")
static var mix: Dictionary = settings.monster_voice
static var SAMPLE_RATE: int = settings.sample_rate
static var STEPS := Config.resources(settings.monster_steps)
static var ATTACKS := Config.resources(settings.monster_attacks)
static var AUDIBLE_DISTANCE: float = mix.distance

static var heavy_slam_stream: AudioStreamWAV = _make_heavy_slam_sound()


static func voice(gain: float) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.max_distance = AUDIBLE_DISTANCE
	player.attenuation = mix.attenuation
	player.panning_strength = mix.panning
	player.volume_db = gain
	player.max_polyphony = mix.polyphony
	return player


static func play(player: AudioStreamPlayer2D, clip: AudioStream, pitch: float) -> void:
	if DisplayServer.get_name() == "headless" and not OS.has_feature("movie"):
		return
	if player.stream != clip:
		player.stream = clip
	player.pitch_scale = pitch
	player.play()


static func play_attack(player: AudioStreamPlayer2D, key: String, is_heavy: bool = false) -> void:
	if DisplayServer.get_name() == "headless" and not OS.has_feature("movie"):
		return
	var clip: AudioStream = heavy_slam_stream if (is_heavy and heavy_slam_stream != null) else ATTACKS.get(key, ATTACKS["heavy"])
	player.stream = clip
	player.pitch_scale = randf_range(mix.heavy_pitch_min, mix.heavy_pitch_max) if is_heavy else 1.0
	player.volume_db = mix.heavy_gain_db if is_heavy else mix.attack_gain_db
	player.play()


static func _make_heavy_slam_sound() -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = 337
	var count := int(SAMPLE_RATE * float(mix.heavy_duration))
	var data := PackedByteArray()
	data.resize(count * 2)
	var prev_noise := 0.0
	for i in range(count):
		var time := float(i) / SAMPLE_RATE
		# Deep visceral earthquake sub-bass slam (52Hz down to 28Hz)
		var sub_bass := sin(TAU * (55.0 * time - 42.0 * time * time)) * exp(-11.0 * time)
		# Heavy blunt body/wood/stone impact thump (110Hz down to 60Hz)
		var thump := sin(TAU * (120.0 * time - 160.0 * time * time)) * exp(-21.0 * time)
		# Cracking gravel / splinter / bone crunch noise
		var raw_noise := random.randf_range(-1.0, 1.0)
		var crack := (raw_noise - prev_noise * 0.75) * exp(-55.0 * time)
		prev_noise = raw_noise
		# Sudden rushing air whoosh
		var whoosh := sin(TAU * 140.0 * time) * exp(-18.0 * time) * 0.35

		var wave := (0.55 * sub_bass + 0.45 * thump + 0.32 * crack + whoosh) * minf(1.0, time * 2800.0)
		data.encode_s16(i * 2, int(clampf(wave, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
