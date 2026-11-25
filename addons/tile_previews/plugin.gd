@tool
extends EditorPlugin

var active_layer: TileMapLayer
var placement := preload("placement_preview.gd").new()
var original_positions := {}
var generator := preload("generator.gd").new()


func _enter_tree() -> void:
	EditorInterface.get_resource_previewer().add_preview_generator(generator)
	EditorInterface.get_selection().selection_changed.connect(_update_layer)
	_update_layer()


func _exit_tree() -> void:
	_restore_layer()
	EditorInterface.get_resource_previewer().remove_preview_generator(generator)


func _restore_layer() -> void:
	if is_instance_valid(active_layer):
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
		active_layer.child_entered_tree.connect(_tile_added)
		active_layer.child_exiting_tree.connect(_tile_removed)
		for tile in active_layer.get_children(true):
			_tile_added(tile)


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
