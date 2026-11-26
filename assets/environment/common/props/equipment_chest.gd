extends "res://assets/environment/common/props/reliquary.gd"

@export var equipment_id: String
@export_range(0, 5) var loot_rank := 0


func _draw() -> void:
	if not opened:
		draw_circle(Vector2(0, -26), 3.5, Color(1.0, 0.79, 0.46, 0.62))
