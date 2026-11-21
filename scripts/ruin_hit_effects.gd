extends Node2D

const DURATION := 0.23
const SAMPLE_RATE := 22050

var bursts: Array[Dictionary] = []
var audio: AudioStreamPlayer
var hit_sound: AudioStreamWAV
var disarm_sound: AudioStreamWAV


func _ready() -> void:
	z_index = 3
	audio = AudioStreamPlayer.new()
	audio.max_polyphony = 5
	audio.volume_db = -5.0
	add_child(audio)
	hit_sound = _make_sound(false)
	disarm_sound = _make_sound(true)


func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()


func impact(point: Vector2, direction: float, disarm: bool) -> void:
	bursts.append({"point": point, "direction": direction, "disarm": disarm, "age": 0.0})
	audio.stream = disarm_sound if disarm else hit_sound
	audio.play()
	queue_redraw()


func clear() -> void:
	bursts.clear()
	audio.stop()
	queue_redraw()


func _process(delta: float) -> void:
	if bursts.is_empty():
		return
	for index in range(bursts.size() - 1, -1, -1):
		bursts[index].age += delta
		if bursts[index].age >= DURATION:
			bursts.remove_at(index)
	queue_redraw()


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
