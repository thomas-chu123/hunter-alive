extends RefCounted

const FRAME := preload("res://assets/ui/equipment/frame.png")
const BUTTONS := preload("res://assets/ui/equipment/buttons.png")


static func frame() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = FRAME
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_texture_margin(side, 14)
		style.set_content_margin(side, 16 if side in [SIDE_LEFT, SIDE_RIGHT] else 12)
	return style


static func style_button(button: Button) -> void:
	var states := ["normal", "hover", "pressed", "disabled"]
	for index in states.size():
		var style := StyleBoxTexture.new()
		style.texture = BUTTONS
		style.region_rect = Rect2(64 * index, 0, 64, 44)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_texture_margin(side, 10)
			style.set_content_margin(side, 12)
		# Keep the hit box fixed while the face and its caption travel together.
		style.content_margin_top = 9 if states[index] == "pressed" else 5
		style.content_margin_bottom = 5 if states[index] == "pressed" else 9
		button.add_theme_stylebox_override(states[index], style)
		if states[index] == "pressed":
			button.add_theme_stylebox_override("hover_pressed", style)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#ffe6a4")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", Color("#f7e6c4"))
	button.add_theme_color_override("font_disabled_color", Color("#b5b5a3"))
