extends SceneTree

const RuinsScene := preload("res://scenes/ruins/ruins.tscn")
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
	var ruins = RuinsScene.instantiate()
	root.add_child(ruins)

	# Wait for ready and first frame setup
	for i in range(5):
		await process_frame

	var hunter = ruins.hunter
	var hit_effects = ruins.hit_effects
	var camera = ruins.camera

	check(hunter != null, "Hunter is present in ruins")
	check(hit_effects != null, "HitEffects manager is initialized")
	check(camera != null, "Camera is linked to hit effects")

	# Test 1: Test swing visual & windup shake for heavy attack
	print("--- Testing Heavy Swing Effect ---")
	hit_effects.swing(hunter.position, 1.0, 75.0, 3, "hunter_knife")
	await process_frame
	check(not hit_effects.slashes.is_empty(), "Heavy crescent slash effect created")
	check(hit_effects.slashes[0].heavy == true, "Slash marked as heavy finisher")

	# Capture swing image
	var img_swing = root.get_viewport().get_texture().get_image()
	if img_swing != null:
		var err = img_swing.save_png(ARTIFACT_DIR + "/attack_vfx_heavy_slash.png")
		check(err == OK, "Saved heavy slash screenshot to artifact directory")

	# Test 2: Test Heavy Blade Impact (Step 3 Finisher / Ultimate move)
	print("--- Testing Finisher Impact VFX & Screen Shake ---")
	var hit_point = hunter.position + Vector2(40, -25)
	hit_effects.blade_impact(hit_point, 1.0, 3, false, false)

	# Peak camera shake is immediately initialized on hit
	var initial_shake = camera.offset.length()
	print("Immediate Camera Shake Amplitude on Finisher: ", initial_shake, " px")
	check(initial_shake >= 8.0, "Screen shake amplitude exceeds 8.0px on big hit (actual: %.2f px)" % initial_shake)

	# Verify effect objects are instantiated
	check(not hit_effects.sparks.is_empty(), "High-density spark rays created on finisher")
	check(hit_effects.sparks[0].heavy == true, "Sparks configured with heavy burst parameters")
	check(not hit_effects.shockwaves.is_empty(), "Shockwave expansion rings spawned")
	check(not hit_effects.starbursts.is_empty(), "Starburst impact flare generated")
	check(not hit_effects.slash_scars.is_empty(), "Impact slash scar geometry added")
	check(hit_effects.flash_rect.color.a > 0.1, "Screen flash overlay triggered (alpha > 0.1)")
	check(hit_effects.time_scale_before_hit > 0.0, "Hitstop tracked time scale correctly")

	# Capture impact screenshot
	var img_impact = root.get_viewport().get_texture().get_image()
	if img_impact != null:
		var err = img_impact.save_png(ARTIFACT_DIR + "/attack_vfx_finisher.png")
		check(err == OK, "Saved finisher impact screenshot to artifact directory")

	# Wait for finisher effects to finish before testing spell
	var wait_finisher := create_tween().set_ignore_time_scale(true)
	wait_finisher.tween_interval(0.35)
	await wait_finisher.finished

	# Test 3: Test Fire Impact (Staff Spell Ultimate)
	print("--- Testing Fire Spell Impact ---")
	hit_effects.fire_impact(hit_point)
	check(not hit_effects.explosions.is_empty(), "Explosion particles spawned")
	check(not hit_effects.shockwaves.is_empty(), "Shockwave spawned for explosion")

	# Allow shake and hitstop to conclude
	var timer := create_tween().set_ignore_time_scale(true)
	timer.tween_interval(0.35)
	await timer.finished

	check(Engine.time_scale == 1.0, "Hitstop cleanly restored Engine.time_scale to 1.0")
	check(camera.offset == Vector2.ZERO, "Camera shake decayed back to Vector2.ZERO")

	ruins.queue_free()
	await process_frame
	print("Combat VFX Verification Complete. Total failures: ", failures)
	quit(0 if failures == 0 else 1)
