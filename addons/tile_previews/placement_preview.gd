@tool
extends RefCounted

# Bounds of the authored resting pose, in the scene tile root's local space.
var texture_bounds := {}


func bounds(tile: Node2D) -> Rect2:
	var art: Array[Rect2] = []
	var shapes: Array[Rect2] = []
	_collect(tile, Transform2D.IDENTITY, art, shapes)
	var parts := shapes if art.is_empty() else art
	if parts.is_empty():
		return Rect2()
	var result := parts[0]
	for part in parts:
		result = result.merge(part)
	return result


func _collect(node: Node2D, transform: Transform2D, art: Array[Rect2], shapes: Array[Rect2]) -> void:
	if not node.visible:
		return
	var rect := Rect2()
	if node is Sprite2D and node.texture:
		var size := Vector2i(node.get_rect().size)
		var origin := Vector2i(node.region_rect.position) if node.region_enabled else Vector2i.ZERO
		var used := _used_rect(node.texture, Rect2i(origin + node.frame_coords * size, size))
		if node.flip_h:
			used.position.x = size.x - used.end.x
		if node.flip_v:
			used.position.y = size.y - used.end.y
		rect = Rect2(node.get_rect().position + used.position, used.size)
	elif node is AnimatedSprite2D and node.sprite_frames:
		var texture: Texture2D = node.sprite_frames.get_frame_texture(node.animation, node.frame)
		if texture:
			rect = _used_rect(texture, Rect2i(Vector2i.ZERO, texture.get_size()))
			rect.position += node.offset
			if node.centered:
				rect.position -= texture.get_size() * 0.5
	elif node is Polygon2D or node is Line2D:
		var points: PackedVector2Array = node.polygon if node is Polygon2D else node.points
		if not points.is_empty():
			rect = Rect2(points[0], Vector2.ZERO)
			for point in points:
				rect = rect.expand(point)
			if node is Line2D:
				rect = rect.grow(node.width * 0.5)
	elif node is CollisionShape2D and node.shape:
		shapes.append(transform * node.shape.get_rect())
	if rect.has_area():
		art.append(transform * rect)
	for child in node.get_children():
		if child is Node2D:
			_collect(child, transform * child.transform, art, shapes)


func _used_rect(texture: Texture2D, region: Rect2i) -> Rect2:
	if not texture_bounds.has(texture):
		texture_bounds[texture] = {}
	var regions: Dictionary = texture_bounds[texture]
	if not regions.has(region):
		regions[region] = Rect2(texture.get_image().get_region(region).get_used_rect())
	return regions[region]
