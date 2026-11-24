extends RefCounted

const ATLAS := preload("res://assets/environment/common/traps/trap_atlas.png")

enum Frame {
	PISTON, SPIKES, SOCKET, MACE,
	LAVA, GEYSER, FIREBALL, BLAST,
	POISON, BOULDER, PORTAL, RANDOM_PORTAL,
	ELECTRODE, ARC, GEYSER_ALT, ARC_ALT,
}


static func paint(canvas: CanvasItem, frame: int, center: Vector2, size: Vector2,
		tint := Color.WHITE, flip_x := false) -> void:
	var region := Rect2(frame % 4 * 128 + 4, (frame >> 2) * 128 + 4, 120, 120)
	if flip_x:
		canvas.draw_set_transform(center, 0.0, Vector2(-1, 1))
		canvas.draw_texture_rect_region(ATLAS, Rect2(-size / 2.0, size), region, tint)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture_rect_region(ATLAS, Rect2(center - size / 2.0, size), region, tint)
