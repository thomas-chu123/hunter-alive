@tool
extends EditorPlugin

var active_layer: TileMapLayer
var placement := preload("placement_preview.gd").new()
var original_positions := {}
var generator := preload("generator.gd").new()


func _enter_tree() -> void:
	EditorInterface.get_resource_previewer().add_preview_generator(generator)
	set_force_draw_over_forwarding_enabled()
	EditorInterface.get_selection().selection_changed.connect(_update_layer)
	_update_layer()


func _exit_tree() -> void:
	_restore_layer()
	EditorInterface.get_resource_previewer().remove_preview_generator(generator)


func _restore_layer() -> void:
	if is_instance_valid(active_layer):
		active_layer.changed.disconnect(update_overlays)
		if active_layer.child_entered_tree.is_connected(_tile_added):
			active_layer.child_entered_tree.disconnect(_tile_added)
			active_layer.child_exiting_tree.disconnect(_tile_removed)
	for id: int in original_positions:
		var tile := instance_from_id(id) as Node2D
		if tile:
			tile.position = original_positions[id]
	active_layer = null
	original_positions.clear()
	placement.texture_bounds.clear()


func _update_layer() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	_watch_layer(selected[0] as TileMapLayer if selected.size() == 1 else null)


func _watch_layer(layer: TileMapLayer) -> void:
	_restore_layer()
	active_layer = layer
	if active_layer:
		active_layer.changed.connect(update_overlays)
		active_layer.child_entered_tree.connect(_tile_added)
		active_layer.child_exiting_tree.connect(_tile_removed)
		for tile in active_layer.get_children(true):
			_tile_added(tile)
	update_overlays()


func _tile_added(tile: Node) -> void:
	if tile is Node2D and (tile.scene_file_path.begins_with("res://assets/environment/common/props/")
			or tile.scene_file_path.begins_with("res://assets/environment/common/traps/")
			or tile.scene_file_path.begins_with("res://assets/items/")):
		_center_tile.call_deferred(tile.get_instance_id())


func _tile_removed(tile: Node) -> void:
	var id := tile.get_instance_id()
	if original_positions.has(id):
		tile.position = original_positions[id]
		original_positions.erase(id)


func _center_tile(id: int) -> void:
	var tile := instance_from_id(id) as Node2D
	if not tile or not active_layer or tile.get_parent() != active_layer or tile.owner or original_positions.has(id):
		return
	var rect := placement.bounds(tile)
	if rect.has_area():
		original_positions[id] = tile.position
		tile.position -= tile.transform.basis_xform(rect.get_center())


func _forward_canvas_force_draw_over_viewport(overlay: Control) -> void:
	var layer := active_layer
	if not is_instance_valid(layer) or not layer.is_visible_in_tree() or not layer.tile_set:
		return
	var fixtures := layer.tile_set == preload("res://assets/environment/common/terrain/interior_fixtures_tileset.tres")
	var transform := layer.get_global_transform_with_canvas()
	var half := Vector2(layer.tile_set.tile_size) * 0.5
	for index in layer.tile_set.get_source_count():
		var id := layer.tile_set.get_source_id(index)
		if not fixtures and not layer.tile_set.get_source(id) is TileSetScenesCollectionSource:
			continue
		for cell in layer.get_used_cells_by_id(id):
			var center := layer.map_to_local(cell)
			var point := transform * center
			if not Rect2(Vector2.ZERO, overlay.size).has_point(point):
				continue
			var corners := PackedVector2Array()
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
				corners.append(transform * (center + half * corner))
			overlay.draw_polyline(corners, Color(0, 0, 0, 0.8), 3)
			overlay.draw_polyline(corners, Color.AQUAMARINE, 1)
			overlay.draw_circle(point, 2, Color.AQUAMARINE)
