extends Node2D

@export var equipment_id: String


func _draw() -> void:
	draw_circle(Vector2(0, -26), 3.5, Color(1.0, 0.79, 0.46, 0.62))
