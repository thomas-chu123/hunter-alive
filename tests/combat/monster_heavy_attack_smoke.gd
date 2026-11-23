extends SceneTree

const RuinsScene := preload("res://scenes/ruins/ruins.tscn")
const EnemyAudio := preload("res://scripts/sound/ruin_enemy_audio.gd")
const Effects := preload("res://scripts/effects/ruin_enemy_effects.gd")
const ARTIFACT_DIR := "/Users/skynet/.gemini/antigravity/brain/3420e472-ba92-485f-8fd8-607dd789e8a9"

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		printerr("FAIL ", message)


func run() -> void:
	# 1. Test EnemyAudio Heavy Impact Sound synthesis
	print("--- Testing Monster Heavy Attack Sound ---")
	check(EnemyAudio.heavy_slam_stream != null, "Heavy slam audio stream synthesized successfully")
	check(EnemyAudio.heavy_slam_stream.data.size() > 5000, "Heavy slam stream has sufficient waveform sample data")
	check(EnemyAudio.heavy_slam_stream.format == AudioStreamWAV.FORMAT_16_BITS, "Heavy slam stream uses 16-bit PCM audio")

	var ruins = RuinsScene.instantiate()
	root.add_child(ruins)

	for i in range(5):
		await process_frame

	var hunter = ruins.hunter
	var hit_effects = ruins.hit_effects
	var camera = ruins.camera

	check(hunter != null and hit_effects != null and camera != null, "Ruins combat entities initialized")

	# 2. Test Monster Ground Heavy Slam & Sweep Drawing
	print("--- Testing Monster Heavy Attack VFX Drawing ---")
	var vfx_canvas := Node2D.new()
	vfx_canvas.draw.connect(func():
		# Test drawing heavy charge tell
		Effects.charge(vfx_canvas, hunter.position + Vector2(60, -30), "earth", 0.5, true)
		# Test drawing heavy triple claw sweep
		Effects.sweep(vfx_canvas, 35.0, 70.0, 1.0, "earth", 0.5, true, "slam")
		# Test drawing active heavy ground slam shockwave & spikes
		Effects.ground(vfx_canvas, hunter.position + Vector2(100, 0), 65.0, "earth", true, 0.45, null, {}, true)
	)
	ruins.add_child(vfx_canvas)
	vfx_canvas.queue_redraw()

	await process_frame

	# Capture Monster Heavy Attack Ground Slam & Sweep VFX screenshot
	var img_slam = root.get_viewport().get_texture().get_image()
	if img_slam != null:
		var err = img_slam.save_png(ARTIFACT_DIR + "/monster_heavy_attack_ground_slam.png")
		check(err == OK, "Saved monster ground slam VFX screenshot")

	# 3. Test Monster Heavy Attack Hit Reaction on Player (Heavy Hit / Screen Shake / Red Flash)
	print("--- Testing Monster Heavy Hit on Player ---")
	var initial_health = hunter.health
	# Monster hits player with a heavy strike (damage = 2, effect = "slam")
	hunter.hurt(hunter.position.x - 50.0, 2, "slam")

	check(hunter.health < initial_health, "Hunter received damage from monster")

	# Verify screen shake triggered on heavy hit
	var shake_amplitude = camera.offset.length()
	print("Immediate Camera Shake on Monster Heavy Hit: ", shake_amplitude, " px")
	check(shake_amplitude >= 8.0, "Monster heavy hit triggers dramatic camera shake >= 8.0px (actual: %.2f px)" % shake_amplitude)

	# Verify screen flash is red damage flash
	check(hit_effects.flash_rect.color.r > 0.7, "Damage screen flash is active with red hue (r > 0.7)")
	check(hit_effects.flash_rect.color.a > 0.1, "Damage screen flash alpha > 0.1")

	# Verify impact scars and shockwave spawned at player position
	check(not hit_effects.shockwaves.is_empty(), "Monster heavy impact shockwave ring spawned")
	check(not hit_effects.slash_scars.is_empty(), "Monster heavy claw slash scar spawned")

	# Capture Monster Heavy Hit on Player screenshot
	var img_hit = root.get_viewport().get_texture().get_image()
	if img_hit != null:
		var err = img_hit.save_png(ARTIFACT_DIR + "/monster_heavy_hit_player_impact.png")
		check(err == OK, "Saved monster heavy hit on player screenshot")

	# Wait for shake and flash recovery
	var timer := create_tween().set_ignore_time_scale(true)
	timer.tween_interval(0.35)
	await timer.finished

	check(camera.offset == Vector2.ZERO, "Camera shake smoothly decayed back to zero")

	vfx_canvas.queue_free()
	ruins.queue_free()
	await process_frame

	print("Monster Heavy Attack Verification Complete. Total failures: ", failures)
	quit(0 if failures == 0 else 1)
