extends AnimatableBody2D

@export var travel := Vector2(0, -220)
@export var period := 6.0

@onready var origin := position
var elapsed := 0.0


func _physics_process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, period)
	position = origin + travel * (0.5 - 0.5 * cos(TAU * elapsed / period))
