extends SceneTree

const Trap := preload("res://scripts/trap/trap_tile.gd")
const Art := preload("res://scripts/trap/trap_art.gd")
const Course := preload("res://scripts/trap/trap_course.gd")
const COURSE_SCENE := "res://scenes/trap_course/trap_course.tscn"
const TITLE_SCENE := "res://scenes/title/title.tscn"

var failures := 0
var level: Course
var traps: Dictionary = {}
var cues: Array[StringName] = []
var hits: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file(TITLE_SCENE)
	await scene_changed
	var trial_button: Button
	for button in current_scene.buttons.get_children():
		if button.text == "陷阱試煉":
			trial_button = button
			break
	check(is_instance_valid(trial_button), "title exposes the trap course")
	if not trial_button:
		quit(1)
		return
	trial_button.pressed.emit()
	await scene_changed
	level = current_scene
	check(level.scene_file_path == COURSE_SCENE, "title button opens the playable course")
	var layer: TileMapLayer = level.get_node("Landscape/Traps")
	layer.update_internals()
	await physics_frame
	await physics_frame
	check(layer.get_used_cells().size() == 16 and layer.tile_set.get_source_count() == 4,
		"editable 20 px Traps layer contains 16 placements and four source collections")
	for tile in layer.get_children(true):
		if tile is Trap:
			tile.set_physics_process(false)
			tile.sound_played.connect(cues.append)
			traps[Vector2i(tile.position)] = tile
	check(traps.size() == 16, "all scene tiles instantiate with runtime scripts")
	if traps.size() != 16:
		quit(1)
		return
	level.hunter.damaged.connect(func(_source: float, _damage: int, effect: String) -> void: hits.append(effect))

	test_atlas()
	test_ceiling()
	test_walls()
	test_pendulum()
	test_lava()
	test_fireballs()
	test_poison()
	test_boulder()
	test_portals(layer)
	test_electric()
	await test_course_controls()
	await physics_frame
	print("Trap smoke test complete (%d failures)" % failures)
	quit(1 if failures else 0)


func test_atlas() -> void:
	var atlas := Art.ATLAS.get_image()
	var has_frames := atlas.get_size() == Vector2i(512, 512)
	for y in range(4):
		for x in range(4):
			var cell := atlas.get_region(Rect2i(x * 128, y * 128, 128, 128))
			has_frames = has_frames and cell.get_used_rect().has_area() and cell.get_pixel(0, 0).a == 0
	check(has_frames, "ImageGen atlas contains 16 isolated alpha sprites")
	check(atlas.get_region(Rect2i(132, 132, 120, 120)).get_data() != atlas.get_region(Rect2i(260, 388, 120, 120)).get_data()
		and atlas.get_region(Rect2i(132, 388, 120, 120)).get_data() != atlas.get_region(Rect2i(388, 388, 120, 120)).get_data(),
		"lava and electric animations have distinct ImageGen frames")


func test_ceiling() -> void:
	var trap := at(240, 300)
	prepare(Vector2(240, 440))
	advance(trap, 299)
	check(trap._ceiling_drop() == 0 and hits.is_empty() and cues.is_empty(), "ceiling spikes wait for 5.00 seconds")
	advance(trap, 12)
	check(trap._ceiling_drop() > 36 and trap._ceiling_extension() == 0 and hits.is_empty(),
		"piston descends before teeth emerge")
	advance(trap, 20)
	check(trap._ceiling_extension() > 0.9 and hits.size() == 1 and cues == [&"spikes"],
		"emerging ceiling teeth deal damage and trigger their sound")
	advance(trap, 145)
	check(trap._ceiling_drop() == 0 and trap._ceiling_extension() == 0, "ceiling piston and teeth retract")
	advance(trap, 143)
	check(cues == [&"spikes", &"spikes"], "next ceiling strike is on the 10-second cycle")


func test_walls() -> void:
	for x in [560, 820]:
		var trap := at(x, 400)
		prepare(Vector2(x + trap.direction * 48, 440))
		advance(trap, roundi((trap.cycle_seconds - 0.05) * 60))
		check(hits.is_empty() and trap._wall_extension() == 0.0, "wall %s is harmless while retracted" % x)
		advance(trap, 17)
		check(trap._wall_extension() > 0.9 and hits.size() == 1 and cues == [&"spikes"], "wall %s extends toward the hunter with sound and damage" % x)
		advance(trap, 60)
		check(trap._wall_extension() == 0.0, "wall %s retracts after its active window" % x)


func test_pendulum() -> void:
	var trap := at(1060, 300)
	prepare(Vector2(1060, 440))
	advance(trap, 48)
	var right := trap._mace_position().x
	advance(trap, 96)
	check(right > 65 and trap._mace_position().x < -65 and hits.size() == 1 and cues == [&"swing"],
		"pendulum swings both ways, hits with its head and whooshes through the center")


func test_lava() -> void:
	var trap := at(1300, 440)
	prepare(Vector2(1300, 440))
	advance(trap, 1)
	check(hits == ["lava"] and trap._geyser_height() == 0, "lava pool burns between eruptions")
	prepare(Vector2(1300, 381))
	advance(trap, 256)
	check(trap._geyser_height() > 70 and hits == ["lava"] and cues == [&"blast"],
		"lava erupts with a blast and hits above the pool")
	advance(trap, 52)
	check(trap._geyser_height() == 0, "geyser animation recedes")


func test_fireballs() -> void:
	var left := at(1520, 420)
	prepare(Vector2(1660, 440))
	advance(left, 181)
	check(left._projectile_position.x > 65 and left._projectile_age < INF, "left launcher fires a right-moving projectile")
	advance(left, 18)
	check(hits == ["lava"] and cues == [&"fireball"] and left._blast_age == INF, "ordinary fireball hits and expires on contact")

	var right := at(1940, 420)
	prepare(Vector2(2700, 440))
	advance(right, 226)
	check(right._projectile_position.x < -100 and right._projectile_age < INF, "right launcher fires a left-moving projectile")
	advance(right, 25)
	check(right._blast_age < Trap.BLAST_DURATION and cues == [&"fireball", &"blast"], "explosive fireball detonates at range with a separate blast cue")
	level.hunter.position = right.to_global(right._blast_position) + Vector2(0, 20)
	advance(right, 1)
	check(hits == ["lava"], "explosion damages intersecting hunters after projectile expires")
	advance(right, 24)
	check(right._blast_age >= Trap.BLAST_DURATION, "explosion expires")


func test_poison() -> void:
	var trap := at(2140, 420)
	prepare(Vector2(2210, 440))
	advance(trap, 269)
	var opacity := trap._cloud_opacity()
	var center := trap._cloud_center().x
	check(hits == ["poison"] and cues == [&"poison"] and opacity > 0.9, "green poison cloud expands, hisses and damages")
	advance(trap, 52)
	check(trap._cloud_center().x > center and trap._cloud_opacity() < opacity and trap._cloud_opacity() > 0,
		"green poison drifts outward and visibly fades")
	advance(trap, 40)
	check(trap._cloud_opacity() == 0, "poison fades to zero")


func test_boulder() -> void:
	var trap := at(2500, 420)
	prepare(Vector2(2590, 440))
	advance(trap, 311)
	check(is_instance_valid(trap._boulder) and trap._boulder.position.x > 100
		and absf(trap._boulder.global_position.y - 418) < 2 and hits.size() == 1 and cues == [&"roll"],
		"boulder rolls out of the socket, follows the floor, hurts and starts looping audio")
	var rolling := trap._rolling_sound
	check(rolling.format == AudioStreamWAV.FORMAT_16_BITS and rolling.stereo
		and rolling.loop_mode == AudioStreamWAV.LOOP_FORWARD and rolling.loop_end > 0
		and rolling.loop_end * 4 == rolling.data.size(),
		"rolling loop spans every stereo 16-bit frame")
	advance(trap, 101)
	check(not is_instance_valid(trap._boulder) and not trap._sound.playing, "boulder and rolling sound terminate together")


func test_portals(layer: TileMapLayer) -> void:
	var fixed := at(2940, 440)
	var exit := at(3260, 440)
	prepare(fixed.global_position)
	level.hunter.velocity = Vector2(200, -30)
	advance(fixed, 1)
	check(level.hunter.position.is_equal_approx(Vector2(3260, 439)) and level.hunter.velocity == Vector2.ZERO
		and hits.is_empty() and cues == [&"portal"], "fixed portal teleports A to B, clears momentum and plays arrival sound")
	advance(exit, 8)
	check(level.hunter.position.x == 3260 and cues.size() == 1, "B never sends the hunter back")

	# Add a same-layer marker with no ground and an otherwise valid marker on a different layer.
	var landing_scene := preload("res://assets/environment/common/traps/random_landing.tscn")
	var floating := landing_scene.instantiate() as Trap
	floating.position = Vector2(2120, 230)
	layer.add_child(floating)
	var other_layer := TileMapLayer.new()
	level.add_child(other_layer)
	var elsewhere := landing_scene.instantiate() as Trap
	elsewhere.position = Vector2(3480, 440)
	other_layer.add_child(elsewhere)

	var random := at(3520, 440)
	random._rng.seed = 257
	check(not random._can_land(floating.global_position), "random portal rejects a landing without terrain beneath it")
	var locations: Dictionary = {}
	prepare(random.global_position)
	for attempt in range(18):
		level.hunter.position = Vector2(3440, 440)
		advance(random, 1)
		level.hunter.position = random.global_position
		advance(random, 1)
		locations[roundi(level.hunter.position.x)] = true
	check(locations.size() == 3 and locations.has_all([120, 3140, 3680]) and cues.size() == 18 and hits.is_empty(),
		"seeded random portal reaches all three valid same-layer destinations and plays each arrival")
	other_layer.queue_free()


func test_electric() -> void:
	var trap := at(3820, 440)
	prepare(Vector2(3820, 440))
	advance(trap, 1)
	check(hits == ["shock"] and level.hunter.electric_hit_left > 0.0 and cues == [&"shock"],
		"electric field damages the hunter, enables its arc overlay and plays the electric buzz")
	advance(trap, 10)
	check(hits.size() == 1 and cues.size() == 1, "invulnerability prevents repeated shock noise")
	level.hunter.respawn(Course.START)
	check(level.hunter.electric_hit_left == 0, "respawn clears the electric overlay")


func test_course_controls() -> void:
	var electric := at(3820, 440)
	level.hunter.respawn(Vector2(3680, 439))
	level.hunter.invincible_left = 0.0
	electric.set_physics_process(true)
	Input.action_press("hunt_right")
	for frame in range(55):
		await physics_frame
	Input.action_release("hunt_right")
	check(level.hunter.health < level.hunter.max_health(), "walking with normal game input into a painted hazard loses health")
	electric.set_physics_process(false)
	level.hunter.invincible_left = 0.0
	level.hunter.hurt(level.hunter.position.x, level.hunter.health)
	await process_frame
	check(level.hunter.health == level.hunter.max_health() and level.hunter.position.x == Course.START.x,
		"death resets the trial hunter at the start")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	root.push_input(escape)
	await scene_changed
	check(current_scene.scene_file_path == TITLE_SCENE, "Escape returns from the course to the title")


func at(x: int, y: int) -> Trap:
	# The map origin is offset so scene cells sit at exact 20 px world coordinates.
	return traps[Vector2i(x + 10, y + 10)]


func prepare(at_position: Vector2) -> void:
	level.hunter.respawn(at_position)
	level.hunter.invincible_left = 0.0
	cues.clear()
	hits.clear()


func advance(trap: Trap, steps: int) -> void:
	for step in range(steps):
		trap._physics_process(1.0 / 60.0)


func check(condition: bool, message: String) -> void:
	print("%s %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1
