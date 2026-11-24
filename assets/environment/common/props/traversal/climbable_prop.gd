extends Area2D

const DETECTION_LAYER := 1 << 1
const TOP_CLEARANCE := 8.0
const HEIGHT := 120.0


func climb_limit(direction: float) -> float:
	return to_global(Vector2(0, -HEIGHT - TOP_CLEARANCE if direction < 0.0 else 0.0)).y
