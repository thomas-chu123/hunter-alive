extends SceneTree

const Monster := preload("res://scripts/character/ruin_monster.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")
const Art := preload("res://scripts/character/ruin_sprite_art.gd")
const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")

var level: Ruins
var caption: Label
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/flooded_corridor/flooded_corridor.tscn")
	await scene_changed
	level = current_scene
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	level.lantern_found = true
	level._sync_region_gate()
	level.camera.zoom = Vector2.ONE * 1.8
	level.camera.position.y = -115
	level.camera.position_smoothing_enabled = false
	var overlay := CanvasLayer.new()
	overlay.layer = 7
	level.add_child(overlay)
	caption = Label.new()
	caption.position = Vector2(26, 92)
	caption.add_theme_font_override("font", level.font)
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_constant_override("outline_size", 7)
	overlay.add_child(caption)
	check_motion_sheets(["walk"], 1, 4)
	check_motion_sheets(["attack_transition", "attack_transition_unarmed"], 4, 2)
	await low_ceiling("treant")
	await low_ceiling("seal_keeper")
	await check_target_memory()
	await check_hover_commitment()
	await scout_jumps()
	await stays_in_territory()
	await attack_transition()
	quit(1 if failures else 0)


func low_ceiling(id: String) -> void:
	caption.text = ("樹靈" if id == "treant" else "古門封印者") + "｜碰到低矮石樑後折返"
	place_hunter(1065)
	var obstacle := block(Vector2(929, 479), Vector2(64, 38))
	var monster := spawn(id, 800)
	var was_chasing := false
	var turned := false
	var chased_again := false
	var farthest := monster.position.x
	for frame in range(240):
		await physics_frame
		farthest = maxf(farthest, monster.position.x)
		was_chasing = was_chasing or monster.state == Monster.State.CHASE
		if monster.state == Monster.State.RETURN:
			turned = true
		if turned and monster.state == Monster.State.CHASE:
			chased_again = true
	check(was_chasing and turned and monster.position.x < farthest - 20 and farthest < 916,
		"%s abandons a blocked passage and walks away from the ceiling" % id)
	check(not chased_again and monster.state == Monster.State.PATROL,
		"%s resumes patrol without immediately retrying the blocked side" % id)
	place_hunter(684)
	for frame in range(90):
		await physics_frame
		if monster.state in [Monster.State.CHASE, Monster.State.WINDUP]:
			break
	check(monster.state in [Monster.State.CHASE, Monster.State.WINDUP],
		"%s can react again from the accessible side" % id)
	await frames(22)
	remove(monster, obstacle)


func check_target_memory() -> void:
	place_hunter(990)
	var monster := spawn("spider", 800)
	await frames(6)
	var remembered: Vector2 = monster.perception.get_var(&"last_seen", Vector2.ZERO)
	var wall := block(Vector2(900, 500), Vector2(24, 160))
	place_hunter(1010)
	await frames(6)
	check(absf(remembered.x - 990.0) < 1.0 and monster.perception.get_var(&"last_seen") == remembered,
		"ground hunter remembers the visible position when its prey moves behind cover")
	remove(monster, wall)
	await frames(2)


func check_hover_commitment() -> void:
	place_hunter(700)
	var monster := spawn("bell_moth", 800)
	monster._begin_windup(0.4)
	await frames(2)
	var origin := monster.position.x
	await frames(12)
	check(monster.windup > 0.0 and is_equal_approx(origin, monster.position.x),
		"hovering attacker holds its horizontal position throughout anticipation")
	remove(monster)
	await frames(2)


func scout_jumps() -> void:
	caption.text = "石縫巨蛛｜跨過低石塊後繼續追擊"
	place_hunter(1040)
	var obstacle := block(Vector2(949, 530), Vector2(22, 20))
	var monster := spawn("spider", 790)
	var jumped := false
	var crossed := false
	for frame in range(220):
		await physics_frame
		jumped = jumped or monster.position.y < 491.0
		if monster.position.x > 974 and monster.is_on_floor():
			crossed = true
			break
	check(jumped and crossed, "small enemy checks a landing before jumping over a low obstacle")
	await frames(32)
	remove(monster, obstacle)


func stays_in_territory() -> void:
	caption.text = "碎岩守衛｜獵人拉開到追擊範圍外"
	place_hunter(830)
	var monster := spawn("shard_warden", 610)
	for frame in range(115):
		await physics_frame
		if monster.position.x > 665.0:
			break
	var started := monster.position.x > 665.0
	Input.action_press("hunt_right")
	for frame in range(160):
		await physics_frame
		if level.hunter.position.x > 1235:
			break
	Input.action_release("hunt_right")
	var returned := monster.state == Monster.State.RETURN
	var farthest := monster.position.x
	for frame in range(170):
		await physics_frame
		farthest = maxf(farthest, monster.position.x)
		returned = returned or monster.state == Monster.State.RETURN
	check(started and returned and farthest <= monster.home.x + float(monster.profile.leash) + 0.1 and
		absf(monster.position.x - monster.home.x) <= float(monster.profile.patrol_radius) + 10.0 and
		monster.state == Monster.State.PATROL, "moving out of territory ends chase and returns the guardian to patrol")
	remove(monster)


func attack_transition() -> void:
	caption.text = "樹靈｜收身蓄力、出刀與揮刀後的跟隨動作"
	place_hunter(966)
	var monster := spawn("treant", 840)
	var seen := {}
	var gait := {}
	var base_poses := {}
	for frame in range(230):
		await physics_frame
		var locomotion := monster._locomotion_cell()
		if locomotion.y == Art.Locomotion.WALK:
			gait[locomotion.x] = true
		if monster._attack_pose() >= 0:
			base_poses[monster._attack_pose()] = true
			var between := monster._transition_frame()
			if between >= 0:
				seen[between] = true
	check(seen.size() == 2 and base_poses.size() == 3, "treant uses both added drawings during an actual attack cycle")
	check(gait.size() > 1, "walk phase advances with terrain movement")
	remove(monster)


func check_motion_sheets(actions: Array, expected: int, frame_count: int) -> void:
	var count := 0
	for species: String in Bestiary.creatures:
		var art: Dictionary = Bestiary.creatures[species].art
		var cell := Vector2i(Bestiary.vector(Art.combat_frame_layout(art).frame_size))
		var sheets := Art.load_poses(art)
		for key: String in actions:
			var texture: Texture2D = sheets.get(key)
			if texture == null:
				continue
			count += 1
			var sheet := texture.get_image()
			var seen := {}
			for frame in range(frame_count):
				var region := sheet.get_region(Rect2i(Vector2i(frame * cell.x, 0), cell))
				if not region.is_invisible() and is_zero_approx(region.get_pixel(0, 0).a):
					seen[hash(region.get_data())] = true
			check(seen.size() == frame_count, "%s/%s has %d distinct transparent drawings" % [species, key, frame_count])
	check(count == expected, "%s has %d sheets" % [actions[0], expected])


func spawn(id: String, x: float) -> Monster:
	level._add_monster(id, x)
	return level.enemies.back()


func place_hunter(x: float) -> void:
	level.hunter.position = Vector2(x, 539)
	level.hunter.velocity = Vector2.ZERO
	level.hunter.invincible_left = 0.0
	level.hunter.hurt_left = 0.0
	level.hunter.rest()


func block(center: Vector2, size: Vector2) -> StaticBody2D:
	var obstacle := StaticBody2D.new()
	obstacle.position = center
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	obstacle.add_child(collision)
	var art := Polygon2D.new()
	var edge := size / 2
	art.color = Color("#85958e")
	art.polygon = PackedVector2Array([-edge, Vector2(edge.x, -edge.y), edge, Vector2(-edge.x, edge.y)])
	obstacle.add_child(art)
	level.add_child(obstacle)
	return obstacle


func remove(monster: Monster, obstacle: StaticBody2D = null) -> void:
	level.enemies.erase(monster)
	monster.queue_free()
	if obstacle != null:
		obstacle.queue_free()
	level.arrows.clear()


func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


func check(passed: bool, title: String) -> void:
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", title])
