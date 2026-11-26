extends Node2D

const OPEN_TEXTURE := preload("res://assets/environment/common/props/reliquary_open.png")

@export var open_texture: Texture2D = OPEN_TEXTURE

var opened := false

@onready var sprite: Sprite2D = $Sprite
@onready var closed_texture: Texture2D = sprite.texture
@onready var closed_offset := sprite.offset


func set_opened(value: bool) -> void:
	if opened == value:
		return
	opened = value
	sprite.texture = open_texture if opened else closed_texture
	# The raised lid makes the open texture taller. Keep its base in place.
	var extra_height := sprite.texture.get_height() - closed_texture.get_height()
	var offset_scale := 0.5 if sprite.centered else 1.0
	sprite.offset = closed_offset - Vector2(0, extra_height * offset_scale)
	queue_redraw()
