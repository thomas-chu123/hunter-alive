extends Polygon2D

const DISTANCE := 4096.0


@export var bounds := Rect2(-8, -88, 16, 88)


func project(eye_world: Vector2, start_depth: float = 0.0) -> void:
	var eye := to_local(eye_world)
	visible = eye.x < bounds.position.x or eye.x > bounds.end.x
	if not visible:
		return
	var away := -signf(eye.x)
	var upper := Vector2(0.0, bounds.position.y)
	var lower := Vector2(0.0, bounds.end.y)
	# Start at the post's center so its lit side remains visible.
	var start := 1.0 + start_depth / absf(eye.x)
	var finish := 1.0 + DISTANCE / absf(eye.x)
	polygon = PackedVector2Array([
		eye.lerp(upper, start), eye.lerp(lower, start),
		eye.lerp(lower, finish), eye.lerp(upper, finish),
	])
