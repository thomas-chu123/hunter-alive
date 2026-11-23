extends SceneTree

const Armory := preload("res://scripts/ruin_armory.gd")
const Equipment := preload("res://scripts/ruin_equipment.gd")
const Sprites := preload("res://scripts/hunter_sprites.gd")

const MOTIONS := ["idle", "walk", "run", "jump", "glide", "land", "crouch", "hurt", "retreat", "climb"]

var checked := 0
var failures := 0


func _initialize() -> void:
	var weapons: Array = Equipment.STARTING_WEAPONS + ["ember_staff"] + Armory.WEAPONS.keys()
	for weapon: String in weapons:
		for motion: String in MOTIONS:
			check_sheet(weapon, motion, Sprites.motion_size(motion), Sprites.MOTION_FRAMES)
		var attacks := {}
		for crouching in [false, true]:
			for step in range(1, 4 if weapon == "fang_dagger" else 2):
				var action := Sprites.attack_action(weapon, crouching, step)
				attacks[action] = true
		for action: String in attacks:
			check_sheet(weapon, action, Sprites.ATTACK_SIZE, Sprites.attack_frames(weapon))
		print("%s sprite set checked" % weapon)
	print("%d sheets checked, %d failures" % [checked, failures])
	quit(1 if failures else 0)


func check_sheet(weapon: String, action: String, cell_size: Vector2i, frames: int) -> void:
	checked += 1
	var path := "%s/%s/%s.png" % [Sprites.ROOT, weapon, action]
	if not ResourceLoader.exists(path, "Texture2D"):
		fail("Missing sheet %s" % path)
		return
	var texture := load(path) as Texture2D
	var image := texture.get_image()
	var required_size := Vector2i(cell_size.x * Sprites.COLUMNS, cell_size.y * ceili(float(frames) / Sprites.COLUMNS))
	if image.get_size() != required_size:
		fail("Wrong size for %s" % path)
		return
	var unique := {}
	var padding := Rect2i(Vector2i.ONE, cell_size - Vector2i(2, 2))
	for frame in range(frames):
		var cell := Vector2i(frame % Sprites.COLUMNS, floori(float(frame) / Sprites.COLUMNS))
		var pose := image.get_region(Rect2i(cell * cell_size, cell_size))
		var bounds := pose.get_used_rect()
		if not bounds.has_area() or not padding.encloses(bounds):
			fail("Empty frame or missing transparent margin: %s frame %d" % [path, frame])
		unique[hash(pose.get_data())] = true
	if action != "idle" and unique.size() < 2:
		fail("No change in pose: %s" % path)


func fail(message: String) -> void:
	failures += 1
	print("FAIL %s" % message)
