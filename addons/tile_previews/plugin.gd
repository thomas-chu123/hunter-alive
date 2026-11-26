@tool
extends EditorPlugin

var generator := preload("generator.gd").new()


func _enter_tree() -> void:
	EditorInterface.get_resource_previewer().add_preview_generator(generator)


func _exit_tree() -> void:
	EditorInterface.get_resource_previewer().remove_preview_generator(generator)
