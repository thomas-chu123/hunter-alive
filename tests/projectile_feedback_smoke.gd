extends SceneTree

const Ruins := preload("res://scripts/ruins.gd")

var level: Ruins
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/ruins.tscn")
	await scene_changed
	level = current_scene
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	level.hunter.position = Vector2(1120, 539)
	level.camera.zoom = Vector2.ONE * 2.6
	level.camera.position.y = -94
	level.camera.position_smoothing_enabled = false
	level._grant_equipment("ember_staff")
	level.hunter.select_weapon("ember_staff")
	level._add_monster("lizard", 1250)
	var target = level.enemies.back()
	target.set_physics_process(false)
	await frames(34)

	var health: int = target.health
	var mana := level.hunter.mana
	await attack()
	var start: Vector2 = level.arrows.front().at
	await frames(3)
	var next: Vector2 = level.arrows.front().at
	check(next.x > start.x and next.y == start.y and level.hunter.mana == mana - 1, "rightward fireball keeps its release height and spends one mana")
	await frames(5)
	check(target.health == health - 3 and level.hit_effects.explosions.size() == 1
		and level.hit_effects.fire_voice.playing, "enemy impact applies damage and triggers one explosion with sound")
	await frames(48)

	var wall := StaticBody2D.new()
	wall.position = Vector2(1010, 484)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 60)
	collider.shape = shape
	wall.add_child(collider)
	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([Vector2(-6, -30), Vector2(6, -30), Vector2(6, 30), Vector2(-6, 30)])
	marker.color = Color("#786657")
	wall.add_child(marker)
	level.add_child(wall)
	level.hunter.facing = -1.0
	await attack()
	var left: Vector2 = level.arrows.front().at
	await frames(3)
	var later: Vector2 = level.arrows.front().at
	check(later.x < left.x and later.y == left.y, "leftward fireball also travels horizontally")
	await frames(5)
	check(level.arrows.is_empty() and level.hit_effects.explosions.size() == 1
		and level.hit_effects.fire_voice.playing, "terrain removes the fireball and triggers one audible explosion")
	await frames(48)

	level.hunter.facing = 1.0
	level.hunter.select_weapon("hunter_bow")
	await frames(36)
	check(not level.hit_effects.bow_voice.playing, "equipping a bow does not play the release sound")
	await attack()
	check(level.arrows.size() == 1 and level.hit_effects.bow_voice.playing, "bow plays a release sound as the arrow appears")
	await frames(48)
	level.hit_effects.clear()
	if DisplayServer.get_name() == "headless":
		OS.delay_msec(250)
	else:
		root.get_node("GameMusic").play_region(-1)
		await frames(64)
	quit(1 if failures else 0)


func attack() -> void:
	Input.action_press("hunt_attack")
	for index in range(30):
		await process_frame
		if not level.arrows.is_empty():
			break
	Input.action_release("hunt_attack")


func frames(count: int) -> void:
	for index in range(count):
		await process_frame


func check(passed: bool, message: String) -> void:
	print("%.2fs %s %s" % [Engine.get_process_frames() / 60.0, "PASS" if passed else "FAIL", message])
	if not passed:
		failures += 1
