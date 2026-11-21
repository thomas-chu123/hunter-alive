extends Control

const FRAME := preload("res://assets/ui/health_heart_frame.png")
const HEART_SIZE := Vector2(24, 22)
const PITCH := 27.0

# Follow the center of the illustrated frame so the red fill meets the inner bevel.
var fill_outline := PackedVector2Array([
	Vector2(12, 4.8), Vector2(10.2, 2.5), Vector2(8.1, 1.5), Vector2(6, 1.5),
	Vector2(3.9, 2.5), Vector2(2, 4.5), Vector2(1.1, 7.5), Vector2(1.3, 10.1),
	Vector2(2.7, 12.8), Vector2(5, 15.1), Vector2(8.6, 18.5), Vector2(12, 21.0),
	Vector2(15.4, 18.5), Vector2(19, 15.1), Vector2(21.3, 12.8), Vector2(22.7, 10.1),
	Vector2(22.9, 7.5), Vector2(22, 4.5), Vector2(20.1, 2.5), Vector2(18, 1.5),
	Vector2(15.9, 1.5), Vector2(13.8, 2.5),
])
var fill_colors := PackedColorArray()
var health := 0
var capacity := 0


func _ready() -> void:
	for vertex in fill_outline:
		fill_colors.append(Color("#f65a65").lerp(Color("#991735"), vertex.y / HEART_SIZE.y))


func update_health(current: int, maximum: int) -> void:
	if current == health and maximum == capacity:
		return
	if maximum != capacity:
		custom_minimum_size = Vector2(maxf(0.0, (maximum - 1) * PITCH + HEART_SIZE.x), HEART_SIZE.y)
	health = current
	capacity = maximum
	queue_redraw()


func _draw() -> void:
	for index in range(capacity):
		draw_set_transform(Vector2(index * PITCH, 0))
		var full := index < health
		if full:
			draw_polygon(fill_outline, fill_colors)
		var tint := Color.WHITE if full else Color(0.82, 0.78, 0.77, 0.84)
		draw_texture_rect(FRAME, Rect2(Vector2.ZERO, HEART_SIZE), false, tint)
	draw_set_transform(Vector2.ZERO)
