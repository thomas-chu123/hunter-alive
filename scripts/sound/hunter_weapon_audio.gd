extends RefCounted

const Config := preload("res://scripts/game/config_table.gd")
static var settings := Config.read("audio/sound")
static var SAMPLE_RATE: int = settings.sample_rate
static var PROFILES: Dictionary = settings.weapon_profiles


static func make_stream(weapon: String) -> AudioStreamWAV:
	var profile: Dictionary = PROFILES[weapon]
	var duration: float = profile.duration
	var frequency: float = profile.frequency
	var sweep: float = profile.sweep
	var resonance: float = profile.resonance
	var noise_amount: float = profile.noise_amount
	var weight: float = profile.weight
	var random := RandomNumberGenerator.new()
	random.seed = weapon.hash()
	var data := PackedByteArray()
	var count := int(duration * SAMPLE_RATE)
	data.resize(count * 2)
	var air := 0.0
	for index in range(count):
		var time := float(index) / SAMPLE_RATE
		var progress := time / duration
		var noise := random.randf_range(-1.0, 1.0)
		air = lerpf(air, noise, 0.24)
		var tone := sin(TAU * (frequency * time + sweep * time * time * 0.5))
		var ring := sin(TAU * resonance * time)
		var low := sin(TAU * (82.0 * time - 62.0 * time * time))
		var wave := (0.22 * tone + 0.16 * ring) * exp(-5.0 * progress)
		wave += (0.47 * air + 0.18 * noise) * noise_amount * exp(-7.0 * progress)
		wave += low * weight * exp(-7.0 * progress) + 0.12 * noise * exp(-38.0 * progress)
		if weapon == "scribe_staff":
			wave += 0.16 * (sin(TAU * 672.0 * time) + sin(TAU * 901.0 * time)) * exp(-3.8 * progress)
		elif weapon == "thorn_bow":
			wave += 0.20 * sin(TAU * 386.0 * time) * exp(-9.0 * progress)
		var envelope := minf(time * 950.0, 1.0) * (1.0 - smoothstep(0.78, 1.0, progress))
		data.encode_s16(index * 2, int(clampf(wave * envelope, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
