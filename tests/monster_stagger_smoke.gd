extends SceneTree

const Ruins := preload("res://scripts/ruins.gd")
const Monster := preload("res://scripts/ruin_monster.gd")

var level: Ruins
var label: Label
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/flooded_corridor.tscn")
	await scene_changed
	level = current_scene
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	level.lantern_found = true
	level._sync_region_gate()
	level.camera.zoom = Vector2.ONE * 2.7
	level.camera.position.y = -80
	level.camera.position_smoothing_enabled = false
	var overlay := CanvasLayer.new()
	overlay.layer = 7
	level.add_child(overlay)
	label = Label.new()
	label.position = Vector2(26, 92)
	label.add_theme_font_override("font", level.font)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_constant_override("outline_size", 7)
	overlay.add_child(label)
	await frames(35)
	await knife_hit(1.0, "從左側刀擊，巨蛛收腳後仰")
	await knife_hit(-1.0, "從右側刀擊，巨蛛朝另一側後退")
	await bow_hit()
	if DisplayServer.get_name() == "headless":
		level.hit_effects.clear()
		OS.delay_msec(250)
		await process_frame
	quit(1 if failures else 0)


func knife_hit(direction: float, text: String) -> void:
	label.text = text
	var spider := await arrange(direction)
	var initial_hp := spider.health
	await wait_for_tell(spider)
	check(spider.state == Monster.State.WINDUP, "spider is telegraphing before the melee input")
	var before := spider.position.x
	Input.action_press("hunt_attack")
	await frames(2)
	Input.action_release("hunt_attack")
	for frame in range(20):
		if spider.stagger_left > 0.0:
			break
		await physics_frame
	var reached_stagger := spider.state == Monster.State.STAGGER and spider.stagger_left > 0.0
	check(reached_stagger and spider.health < initial_hp and spider.windup == 0.0,
		"real knife input damages the spider and interrupts the tell")
	var stationary_gait := spider.gait_distance
	var progressed := 0.0
	var active_frames := 0
	var walked_during_stagger := false
	for frame in range(16):
		await physics_frame
		if spider.state == Monster.State.STAGGER:
			active_frames += 1
			walked_during_stagger = walked_during_stagger or not is_equal_approx(stationary_gait, spider.gait_distance)
			progressed = maxf(progressed, (spider.position.x - before) * direction)
	check(active_frames >= 8 and progressed >= 12.0 and progressed < 30.0 and not walked_during_stagger,
		"knockback moves away from the blade with paused gait (%.1f px, %d frames)" % [progressed, active_frames])
	check(spider.state != Monster.State.STAGGER and level.hunter.health == level.hunter.max_health(),
		"brief stagger ends and the interrupted attack does not hit")
	await frames(42)
	remove(spider)


func bow_hit() -> void:
	label.text = "獵弓命中，巨蛛保留原本的受擊節奏"
	var spider := await arrange(1.0, 200.0)
	Input.action_press("hunt_switch")
	await frames(2)
	Input.action_release("hunt_switch")
	await frames(4)
	var initial_hp := spider.health
	Input.action_press("hunt_attack")
	await frames(2)
	Input.action_release("hunt_attack")
	for frame in range(60):
		await physics_frame
		if spider.health < initial_hp:
			break
	check(level.hunter.with_bow and spider.health < initial_hp and spider.hit_left > 0.0 and spider.state != Monster.State.STAGGER,
		"real bow input damages the spider and shows a flinch without melee stagger")
	await frames(40)
	remove(spider)


func arrange(direction: float, gap: float = 68.0) -> Monster:
	level.hunter.position = Vector2(920.0 - direction * gap, 539.0)
	level.hunter.velocity = Vector2.ZERO
	level.hunter.facing = direction
	level.hunter.invincible_left = 0.0
	level.hunter.hurt_left = 0.0
	level.hunter.rest()
	level._add_monster("spider", 920)
	await frames(3)
	return level.enemies.back()


func wait_for_tell(spider: Monster) -> void:
	for frame in range(60):
		await physics_frame
		if spider.windup > 0.0:
			return


func remove(spider: Monster) -> void:
	level.enemies.erase(spider)
	spider.queue_free()
	level.arrows.clear()


func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", message])
