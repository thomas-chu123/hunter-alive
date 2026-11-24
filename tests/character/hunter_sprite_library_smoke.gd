extends SceneTree

const Armory := preload("res://scripts/game/ruin_armory.gd")
const Equipment := preload("res://scripts/game/ruin_equipment.gd")
const Sprites := preload("res://scripts/character/hunter_sprites.gd")

var checked := 0
var failures := 0


func _initialize() -> void:
	var weapons: Array = Equipment.STARTING_WEAPONS + ["ember_staff"] + Armory.WEAPONS.keys()
	for weapon: String in weapons:
		var count := Sprites.attack_frames(weapon)
		for atlas: String in Sprites.MOTION_ATLASES:
			var actions: Array = Sprites.MOTION_ATLASES[atlas].duplicate()
			if atlas == "reaction" and count == Sprites.MOTION_FRAMES:
				actions.append("attack")
			check_sheet(weapon, atlas, Sprites.MOTION_SIZE, actions, Sprites.MOTION_FRAMES)
		if count == Sprites.MOTION_FRAMES:
			print("%s sprite set checked" % weapon)
			continue
		var attacks := {}
		for crouching in [false, true]:
			for step in range(1, 4 if weapon == "fang_dagger" else 2):
				var action := Sprites.attack_action(weapon, crouching, step)
				attacks[action] = true
		for action: String in attacks:
			check_sheet(weapon, action, Sprites.ATTACK_SIZE, [action], count)
		print("%s sprite set checked" % weapon)
	print("%d sheets checked, %d failures" % [checked, failures])
	quit(1 if failures else 0)


func check_sheet(weapon: String, atlas: String, cell_size: Vector2i, actions: Array, frames: int) -> void:
	checked += 1
	var path := "%s/%s/%s.png" % [Sprites.ROOT, weapon, atlas]
	if not ResourceLoader.exists(path, "Texture2D"):
		fail("Missing sheet %s" % path)
		return
	var texture := load(path) as Texture2D
	var image := texture.get_image()
	var required_size := cell_size * Vector2i(Sprites.COLUMNS, Sprites.ROWS)
	if image.get_size() != required_size:
		fail("Wrong size for %s" % path)
		return
	var padding := Rect2i(Vector2i.ONE, cell_size - Vector2i(2, 2))
	for frame in range(Sprites.COLUMNS * Sprites.ROWS):
		var cell := Vector2i(frame % Sprites.COLUMNS, floori(float(frame) / Sprites.COLUMNS))
		var pose := image.get_region(Rect2i(cell * cell_size, cell_size))
		var bounds := pose.get_used_rect()
		if frame >= actions.size() * frames:
			if bounds.has_area():
				fail("Unused cell is not empty: %s frame %d" % [path, frame])
		elif not bounds.has_area() or not padding.encloses(bounds):
			fail("Empty frame or missing transparent margin: %s frame %d" % [path, frame])
	for index in range(actions.size()):
		var unique := {}
		for offset in range(frames):
			var frame := index * frames + offset
			var cell := Vector2i(frame % Sprites.COLUMNS, floori(float(frame) / Sprites.COLUMNS))
			unique[hash(image.get_region(Rect2i(cell * cell_size, cell_size)).get_data())] = true
		if actions[index] != "idle" and unique.size() < 2:
			fail("No change in pose: %s %s" % [path, actions[index]])


func fail(message: String) -> void:
	failures += 1
	print("FAIL %s" % message)
