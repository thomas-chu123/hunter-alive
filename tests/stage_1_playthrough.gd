extends SceneTree

var ruins
var hunter
var phase := "startup"
var frame_times: Dictionary = {}
var stuck_frames := 0
var prior_x := 0.0
var previous_frame_us := 0


func _initialize() -> void:
	run.call_deferred()


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if previous_frame_us > 0 and not OS.has_feature("movie"):
		if not frame_times.has(phase):
			frame_times[phase] = []
		frame_times[phase].append((now - previous_frame_us) / 1000.0)
	previous_frame_us = now
	return false


func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.has_feature("movie"):
		root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/ruins.tscn")
	ruins = scene.instantiate()
	root.add_child(ruins)
	hunter = ruins.hunter
	await frames(30)
	print("PASS launched ruins; renderer=%s viewport=%s" % [RenderingServer.get_video_adapter_name(), root.size])

	phase = "movement"
	move(-1)
	for frame in range(240):
		await physics_frame
		if hunter.position.y > 640.0:
			break
	move(0)
	await frames(45)
	if not verify(hunter.position.x > 800.0 and hunter.is_on_floor(), "fall triggers respawn at camp"):
		return
	await tap("hunt_switch")
	phase = "combat"
	for enemy in ruins.enemies.duplicate():
		if enemy.species not in ["spider", "lizard", "treant"]:
			continue
		if not await defeat(enemy):
			verify(false, "combat: " + enemy.species)
			return
		if not ruins.collected_souls.has("lizard") and ruins._has_drop("lizard"):
			for drop in ruins.drops:
				if drop.kind == "lizard":
					await go_to(drop.at.x)
					break
			await frames(20)
			for slot in range(ruins.collected_souls.size()):
				await tap("hunt_equip")
				await frames(2)
				if hunter.equipped_soul == "lizard":
					break
			if not verify(hunter.equipped_soul == "lizard", "collected and equipped wing soul"):
				return
	if not verify(ruins.guardian_felled, "guardian defeated with weapon inputs"):
		return

	phase = "movement"
	await go_to(753.0)
	await frames(20)
	phase = "glide"
	Input.action_press("hunt_soul")
	await tap("hunt_jump")
	move(-1)
	var glided := false
	for frame in range(180):
		await physics_frame
		glided = glided or hunter.gliding
		if hunter.position.x < 175.0:
			break
	move(0)
	Input.action_release("hunt_soul")
	await frames(27)
	if not verify(glided and hunter.position.x < 312.0 and hunter.is_on_floor(), "glided over bridge with jump and soul inputs"):
		return
	await tap("hunt_interact")
	if not verify(ruins.completed and ruins.end_screen.visible, "opened stone gate and reached completion screen"):
		return
	phase = "completion"
	await frames(75)
	for name: String in frame_times:
		var samples: Array = frame_times[name]
		samples.sort()
		var p95: float = samples[ceili(samples.size() * 0.95) - 1]
		var mean_ms: float = float(samples.reduce(func(total, sample): return total + sample, 0.0)) / samples.size()
		print("PERF %s n=%d mean_fps=%.1f p95_ms=%.2f" % [name, samples.size(), 1000.0 / mean_ms, p95])
	quit()


func defeat(enemy: Node2D) -> bool:
	Input.action_press("hunt_attack")
	for frame in range(3000):
		await physics_frame
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			Input.action_release("hunt_attack")
			move(0)
			return true
		var distance: float = enemy.position.x - hunter.position.x
		var direction := signf(distance)
		var separation := absf(distance)
		if separation > 290.0 or (hunter.facing != direction and separation > 175.0):
			move(direction)
		elif separation < 205.0 and hunter.position.x > 775.0:
			move(-direction)
		else:
			move(0)
	Input.action_release("hunt_attack")
	return false


func go_to(x: float) -> void:
	for frame in range(1400):
		await physics_frame
		var offset: float = x - hunter.position.x
		if absf(offset) < 7.0:
			break
		move(signf(offset))
	move(0)
	await frames(14)


func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


func tap(action: StringName) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)


func move(direction: float) -> void:
	var x: float = hunter.position.x
	if direction == 0.0 or absf(x - prior_x) > 0.1:
		stuck_frames = maxi(0, stuck_frames - 1)
	else:
		stuck_frames += 1
	prior_x = x
	hold("hunt_crouch", direction != 0.0 and stuck_frames > 12)
	hold("hunt_left", direction < 0.0)
	hold("hunt_right", direction > 0.0)


func hold(action: StringName, active: bool) -> void:
	if active and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not active and Input.is_action_pressed(action):
		Input.action_release(action)


func verify(condition: bool, description: String) -> bool:
	print("%s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		quit(1)
	return condition
