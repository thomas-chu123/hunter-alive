extends RefCounted

const SAMPLE_RATE := 22050
# Duration, fundamental, pitch sweep, resonance, air, and low-end weight.
const PROFILES := {
	"root_blade": [0.24, 245.0, -300.0, 514.0, 0.73, 0.21],
	"fang_dagger": [0.13, 1380.0, -1800.0, 2360.0, 0.32, 0.04],
	"sluice_spear": [0.21, 845.0, 960.0, 1700.0, 0.60, 0.03],
	"tide_hammer": [0.38, 101.0, -82.0, 423.0, 0.27, 0.68],
	"thorn_bow": [0.25, 193.0, -38.0, 579.0, 0.26, 0.16],
	"ember_staff": [0.29, 279.0, -286.0, 722.0, 0.86, 0.36],
	"scribe_staff": [0.53, 448.0, 165.0, 1134.0, 0.08, 0.10],
	"gate_halberd": [0.34, 367.0, -240.0, 1399.0, 0.49, 0.35],
}


static func make_stream(weapon: String) -> AudioStreamWAV:
	var profile: Array = PROFILES[weapon]
	var duration: float = profile[0]
	var frequency: float = profile[1]
	var sweep: float = profile[2]
	var resonance: float = profile[3]
	var noise_amount: float = profile[4]
	var weight: float = profile[5]
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
