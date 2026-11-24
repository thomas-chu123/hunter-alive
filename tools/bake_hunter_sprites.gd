extends SceneTree

const Armory := preload("res://scripts/game/ruin_armory.gd")
const Art := preload("res://scripts/character/hunter_weapon_art.gd")
const Body := preload("res://scripts/character/hunter_animation.gd")
const Equipment := preload("res://scripts/game/ruin_equipment.gd")
const Sprites := preload("res://scripts/character/hunter_sprites.gd")

var viewport: SubViewport
var failures := 0


func _initialize() -> void:
	bake.call_deferred()


func bake() -> void:
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var weapons: Array = Equipment.STARTING_WEAPONS + ["ember_staff"] + Armory.WEAPONS.keys()
	for weapon: String in weapons:
		var folder := Sprites.ROOT.path_join(weapon)
		var result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		if result != OK:
			push_error("Cannot create sprite folder: %s" % folder)
			quit(1)
			return
		for atlas: String in Sprites.MOTION_ATLASES:
			var actions: Array = Sprites.MOTION_ATLASES[atlas].duplicate()
			if atlas == "reaction" and Sprites.attack_frames(weapon) == Sprites.MOTION_FRAMES:
				actions.append("attack")
			await write_sheet(folder, weapon, atlas, actions, false, 1)
		if Sprites.attack_frames(weapon) == Sprites.MOTION_FRAMES:
			continue
		var steps := 3 if weapon == "fang_dagger" else 1
		for step in range(1, steps + 1):
			await write_sheet(folder, weapon, Sprites.attack_action(weapon, false, step), [], false, step)
			if Sprites.attack_action(weapon, true, step) != Sprites.attack_action(weapon, false, step):
				await write_sheet(folder, weapon, Sprites.attack_action(weapon, true, step), [], true, step)
	quit(1 if failures else 0)


func write_sheet(folder: String, weapon: String, name: String, actions: Array, crouching: bool, step: int) -> void:
	var attack := actions.is_empty()
	var count := Sprites.attack_frames(weapon) if attack else Sprites.MOTION_FRAMES
	var size := Sprites.ATTACK_SIZE if attack else Sprites.MOTION_SIZE
	var origin := Sprites.ATTACK_ORIGIN if attack else Sprites.MOTION_ORIGIN
	var used_cells := count if attack else count * actions.size()
	viewport.size = size * Vector2i(Sprites.COLUMNS, Sprites.ROWS)
	for index in range(used_cells):
		var cell := Vector2i(index % Sprites.COLUMNS, floori(float(index) / Sprites.COLUMNS))
		var action: String = "attack" if attack else actions[cell.y]
		var frame := index if attack else cell.x
		var canvas := Node2D.new()
		canvas.scale = Vector2.ONE * Sprites.SCALE
		canvas.position = Vector2(cell * size) + origin
		if action == "climb":
			canvas.position += Vector2(10, -24) * Sprites.SCALE
			canvas.rotation = -PI * 0.5
		canvas.draw.connect(draw_pose.bind(canvas, weapon, action, frame, count, crouching, step))
		viewport.add_child(canvas)

	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var path := folder.path_join(name + ".png")
	if image == null or image.is_empty() or not cells_have_padding(image, size, used_cells):
		push_error("Empty or clipped sprite frame in %s" % path)
		failures += 1
	elif straight_alpha(image).save_png(ProjectSettings.globalize_path(path)) != OK:
		push_error("Cannot write %s" % path)
		failures += 1
	else:
		print("PASS %s (%d frames)" % [path, used_cells])
	for child in viewport.get_children():
		viewport.remove_child(child)
		child.queue_free()


func cells_have_padding(image: Image, size: Vector2i, count: int) -> bool:
	var padding := Rect2i(Vector2i.ONE, size - Vector2i(2, 2))
	for frame in range(count):
		var cell := Vector2i(frame % Sprites.COLUMNS, floori(float(frame) / Sprites.COLUMNS))
		var used := image.get_region(Rect2i(cell * size, size)).get_used_rect()
		if not used.has_area() or not padding.encloses(used):
			print("Frame %d bounds %s, cell %s" % [frame, used, size])
			return false
	return true


# Rendering on a transparent canvas stores premultiplied color.
# Convert partial-alpha pixels back to straight alpha for the PNG import.
func straight_alpha(image: Image) -> Image:
	var bytes := image.get_data()
	for i in range(0, bytes.size(), 4):
		var alpha := bytes[i + 3]
		if alpha == 0 or alpha == 255:
			continue
		for channel in range(3):
			bytes[i + channel] = mini(255, roundi(bytes[i + channel] * 255.0 / alpha))
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes)


func draw_pose(canvas: Node2D, weapon: String, action: String, frame: int, count: int, crouching: bool, step: int) -> void:
	if action == "attack":
		var progress := float(frame) / count
		if weapon == "hunter_knife":
			Body.draw_short_blade(canvas, frame, 1.0)
		elif weapon == "ember_staff":
			Art.draw_ember_cast(canvas, progress, 1.0, crouching)
		else:
			Art.draw_attack(canvas, weapon, progress, 1.0, crouching, step)
		return

	var motion := action
	if action == "retreat":
		motion = "walk"
		frame = Sprites.MOTION_FRAMES - 1 - frame
	elif action == "climb":
		motion = "run"

	if weapon == "hunter_knife":
		Body.draw_frame(canvas, motion, frame, 1.0)
	elif weapon == "ember_staff":
		if Art.MOTION_GRIPS.has(motion):
			Art.draw_held_motion(canvas, weapon, motion, frame, 1.0)
		elif motion in ["walk", "run"]:
			Body.draw_ember_stride(canvas, motion, frame, 1.0)
		else:
			Body.draw_ember_pose(canvas, 1.0, 0.0)
	else:
		Art.draw_held(canvas, weapon, motion, frame, 1.0)
