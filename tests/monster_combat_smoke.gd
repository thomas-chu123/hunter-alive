extends SceneTree

const Bestiary := preload("res://scripts/ruin_bestiary.gd")
const Monster := preload("res://scripts/ruin_monster.gd")
const Art := preload("res://scripts/ruin_sprite_art.gd")
const Effects := preload("res://scripts/ruin_enemy_effects.gd")
const Ruins := preload("res://scripts/ruins.gd")
const ELEMENT := {"metal": "金", "wood": "木", "water": "水", "fire": "火", "earth": "土"}

var level: Ruins
var label: Label
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var ground_fire_only := "--ground-fire" in OS.get_cmdline_user_args()
	change_scene_to_file("res://scenes/buried_court/buried_court.tscn" if ground_fire_only else "res://scenes/flooded_corridor/flooded_corridor.tscn")
	await scene_changed
	level = current_scene
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	if not ground_fire_only:
		level.lantern_found = true
		level._sync_region_gate()
	level.camera.zoom = Vector2.ONE * 2.25
	level.camera.position.y = -101
	level.camera.position_smoothing_enabled = false
	make_label()
	await physics_frame
	if ground_fire_only:
		await encounter("ash_scribe", false)
		quit(1 if failures else 0)
		return
	var elements := {}
	var attack_paths := {}
	for id in Bestiary.creatures:
		var entry: Dictionary = Bestiary.creatures[id]
		var attack: Dictionary = entry.attack
		elements[attack.element] = true
		var sheet: Texture2D = Art.poses[id].attack
		attack_paths[sheet.resource_path] = true
		check(valid_poses(sheet.get_image()),
			"%s has three distinct transparent sprite frames" % id)
		await encounter(id, false)
		if attack.has("unarmed"):
			var unarmed: Texture2D = Art.poses[id].attack_unarmed
			check(valid_poses(unarmed.get_image()),
				"%s has three distinct disarmed frames" % id)
			await encounter(id, true)
	check(attack_paths.size() == 21 and elements.size() == 5, "21 monster attack sheets and all five elements are used")
	await check_dodges()
	quit(1 if failures else 0)


func encounter(id: String, unarmed: bool) -> void:
	var entry: Dictionary = Bestiary.creatures[id]
	var attack: Dictionary = entry.attack
	var mode: String = attack.mode if not unarmed else attack.unarmed.mode
	var gap := 165.0 if mode == "bolt" else 60.0
	var direction := -1 if Bestiary.creatures.keys().find(id) % 2 == 0 else 1
	reset_hunter(900 + gap * direction)
	var monster := add_enemy(id)
	if unarmed:
		monster.armed = false
	label.text = "%s｜%s · %s%s" % [entry.name, ELEMENT[attack.element], attack.name,
		"（繳械後改用近戰）" if unarmed else ""]
	label.add_theme_color_override("font_color", Effects.COLORS[attack.element])
	var poses := {}
	var damaged_during_windup := false
	var projectiles := 0
	var peak_impact := 0
	var health := level.hunter.health
	monster.launched.connect(func(_origin: Vector2, _facing: float, _attack: Dictionary) -> void:
		monster.set_meta("projectiles", int(monster.get_meta("projectiles", 0)) + 1))
	var recovered := false
	if id == "shale_beetle":
		var armor_health := monster.health
		monster.receive_hit(2, false, true)
		check(monster.health == armor_health, "shale beetle shrugs off a hit before it attacks")
	for frame in range(180):
		await physics_frame
		var pose := monster._attack_pose()
		poses[pose] = true
		projectiles = int(monster.get_meta("projectiles", 0))
		peak_impact = maxi(peak_impact, monster.impact_index)
		if pose == Monster.AttackPose.ANTICIPATION and peak_impact == 0:
			damaged_during_windup = damaged_during_windup or affected(health)
		if pose == Monster.AttackPose.RECOVERY:
			if id == "shale_beetle":
				var armor_health := monster.health
				monster.receive_hit(2, false, true)
				check(monster.health == armor_health - 2, "shale beetle can be hit during recovery")
			recovered = true
			await frames(12)
			break
	var expected_shots := 1 if mode == "bolt" else 0
	check(recovered and poses.has(Monster.AttackPose.ANTICIPATION) and poses.has(Monster.AttackPose.RELEASE)
		and not damaged_during_windup and affected(health) and projectiles == expected_shots
		and peak_impact == int(attack.get("hits", 1)),
		"%s%s enters all phases, hits only after release and uses %s (%s, strikes=%d, projectiles=%d)" % [
			id, " disarmed" if unarmed else "", mode, attack.element, peak_impact, projectiles])
	remove_enemy(monster)


func check_dodges() -> void:
	label.text = "閃避驗證｜從側面避開近戰"
	reset_hunter(949)
	var spider := add_enemy("spider")
	await wait_for_windup(spider)
	reset_hunter(860)
	await frames(43)
	check(level.hunter.health == level.hunter.max_health(), "moving behind a winding-up melee leaves the hunter unharmed")
	remove_enemy(spider)

	label.text = "閃避驗證｜移出火印範圍"
	reset_hunter(1000)
	var scribe := add_enemy("ash_scribe")
	await wait_for_windup(scribe)
	reset_hunter(1120)
	await frames(81)
	check(level.hunter.health == level.hunter.max_health() and is_equal_approx(scribe.target_mark.x, 1000),
		"fire glyph remains fixed at the marked point and can be dodged")
	remove_enemy(scribe)

	label.text = "閃避驗證｜實體地形擋住火息"
	reset_hunter(1070)
	var drake := add_enemy("lizard")
	await wait_for_windup(drake)
	var wall := StaticBody2D.new()
	wall.position = Vector2(1001, 485)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(22, 108)
	shape.shape = rectangle
	wall.add_child(shape)
	var stone := Polygon2D.new()
	stone.color = Color("#7a8f8d")
	stone.polygon = PackedVector2Array([Vector2(-11, -54), Vector2(11, -54), Vector2(11, 54), Vector2(-11, 54)])
	wall.add_child(stone)
	level.add_child(wall)
	var launched := false
	for frame in range(90):
		await physics_frame
		launched = launched or not level.arrows.is_empty()
	check(launched and level.arrows.is_empty() and level.hunter.health == level.hunter.max_health(),
		"fire projectile is launched and consumed by a terrain wall before it reaches the hunter")
	remove_enemy(drake)
	wall.queue_free()


func wait_for_windup(monster: Monster) -> void:
	for frame in range(120):
		await physics_frame
		if monster.windup > 0.0:
			return


func affected(initial_health: int) -> bool:
	var hunter = level.hunter
	return hunter.health < initial_health or hunter.pollen_left > 0.0 or hunter.leech_left > 0.0


func valid_poses(sheet: Image) -> bool:
	var frames_seen := {}
	for pose in range(3):
		var cell := sheet.get_region(Rect2i(Vector2i(pose * 224, 0), Vector2i(224, 224)))
		if cell.is_invisible() or cell.get_pixel(0, 0).a > 0:
			return false
		frames_seen[hash(cell.get_data())] = true
	return frames_seen.size() == 3


func add_enemy(id: String) -> Monster:
	level._add_monster(id, 900)
	return level.enemies.back()


func remove_enemy(monster: Monster) -> void:
	level.enemies.erase(monster)
	monster.queue_free()
	level.arrows.clear()


func reset_hunter(x: float) -> void:
	level.hunter.position = Vector2(x, 539)
	level.hunter.velocity = Vector2.ZERO
	level.hunter.hurt_left = 0.0
	level.hunter.invincible_left = 0.0
	level.hunter.rest()


func make_label() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 7
	level.add_child(overlay)
	label = Label.new()
	label.position = Vector2(26, 92)
	label.add_theme_font_override("font", level.font)
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_constant_override("outline_size", 8)
	overlay.add_child(label)


func frames(count: int) -> void:
	for index in range(count):
		await physics_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", message])
