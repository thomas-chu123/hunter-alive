extends PointLight2D

@onready var steady_energy := energy
var phase := 0.0


func _ready() -> void:
	phase = fposmod(global_position.x * 0.37 + global_position.y * 0.23, TAU)


func _process(delta: float) -> void:
	phase += delta * 7.0
	energy = steady_energy * (1.0 + 0.07 * sin(phase) + 0.04 * sin(phase * 1.9))
