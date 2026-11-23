extends RefCounted

const STEPS := {
	"claw": preload("res://assets/audio/monsters/step_claw.wav"),
	"pad": preload("res://assets/audio/monsters/step_pad.wav"),
	"wood": preload("res://assets/audio/monsters/step_wood.wav"),
	"stone": preload("res://assets/audio/monsters/step_stone.wav"),
	"metal": preload("res://assets/audio/monsters/step_metal.wav"),
	"wing": preload("res://assets/audio/monsters/flap.wav"),
}
const ATTACKS := {
	"fang": preload("res://assets/audio/monsters/strike_fang.wav"),
	"wood": preload("res://assets/audio/monsters/strike_wood.wav"),
	"metal": preload("res://assets/audio/monsters/strike_metal.wav"),
	"heavy": preload("res://assets/audio/monsters/strike_heavy.wav"),
	"arrow": preload("res://assets/audio/monsters/cast_arrow.wav"),
	"fire": preload("res://assets/audio/monsters/cast_fire.wav"),
	"water": preload("res://assets/audio/monsters/cast_water.wav"),
	"stone": preload("res://assets/audio/monsters/cast_stone.wav"),
	"rune": preload("res://assets/audio/monsters/cast_rune.wav"),
	"resonance": preload("res://assets/audio/monsters/cast_metal.wav"),
	"pollen": preload("res://assets/audio/monsters/cast_pollen.wav"),
}
const AUDIBLE_DISTANCE := 680.0


static func voice(gain: float) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.max_distance = AUDIBLE_DISTANCE
	player.attenuation = 1.32
	player.panning_strength = 0.46
	player.volume_db = gain
	player.max_polyphony = 2
	return player


static func play(player: AudioStreamPlayer2D, clip: AudioStream, pitch: float) -> void:
	if DisplayServer.get_name() == "headless" and not OS.has_feature("movie"):
		return
	if player.stream != clip:
		player.stream = clip
	player.pitch_scale = pitch
	player.play()
