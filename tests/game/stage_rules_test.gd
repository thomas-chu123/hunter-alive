extends SceneTree

const Ruins := preload("res://scripts/scene/ruins.gd")
const Vault := preload("res://scripts/scene/temple_vault.gd")
const Campaign := Ruins.Campaign
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	failures += int(not ok)


func run() -> void:
	# In-memory overrides last only for this test process.
	Campaign.regions[0].presentation = {"stage_camera_top": -912, "brazier_min_gap": 211.0}
	Vault.vault.normal_depth = 61.0
	Vault.vault.drained_depth = 8.0
	Vault.vault.ambient_brightness = 100
	Ruins.stage_rules.stages.ruins.ambient_brightness = 1
	change_scene_to_file(Campaign.scene_path({}))
	await scene_changed
	var level := current_scene as Vault
	var vault_ambient := level.get_node("AmbientLight") as CanvasModulate
	check(vault_ambient.color.is_equal_approx(Color.WHITE)
		and level.background.self_modulate == vault_ambient.color,
		"ruins_1 brightness 100 gives white ambient light and backdrop")
	check(level.camera.limit_top == -912 and level.landscape.brazier_min_gap == 211.0,
		"regional presentation overrides camera and brazier defaults")
	check(level.river_depth == 61.0, "vault starts at configured water depth")
	Vault.vault.sluice_radius = 14
	level.hunter.position = Vault.SLUICE + Vector2(15, 0)
	check(not level._at_sluice(), "outside configured sluice radius")
	level.hunter.position = Vault.SLUICE + Vector2(13, 0)
	level._update_stage_hud()
	check(level.prompt_label.text.contains("洩水輪"), "sluice prompt uses configured radius")
	level._interact()
	var saved := level._checkpoint_state()
	level.river_depth = 40
	level._restore_camp(saved)
	check(level.drained and level.river_depth == 8.0, "sluice action and restored depth use vault rules")

	var shot: Dictionary = Ruins.Armory.catalog.projectiles.arrow
	shot.speed = 635
	shot.lifetime = 0.72
	shot.height = 11
	level._attack(level.hunter.position, 1, true, 1, "thorn_bow")
	var arrow: Dictionary = level.arrows.back()
	check(arrow.speed == 635 and arrow.left == 0.72 and arrow.height == 11 and arrow.pierce == 1,
		"bow releases configured projectile with weapon-specific pierce")

	# Exercise the normal projectile update away from terrain and enemies.
	level.arrows.clear()
	var origin := Vector2(500, -1500)
	level._cast(origin, 1, "ember_staff")
	var fireball: Dictionary = level.arrows.back()
	fireball.erase("cast_start")
	level._update_arrows(0.1)
	var fire: Dictionary = Ruins.Armory.catalog.projectiles.ember
	check(is_equal_approx(fireball.at.x, origin.x + float(fire.speed) * 0.1)
		and is_equal_approx(fireball.left, float(fire.lifetime) - 0.1),
		"fireball movement and lifetime follow its own projectile profile")

	var enemy := Ruins.Monster.new()
	Ruins.Bestiary.creatures.spider.motion_rules = {"patrol_speed": 37}
	enemy.configure("spider", Vector2.ZERO, level.hunter)
	check(enemy.motion_rules.patrol_speed == 37 and enemy.motion_rules.gravity == Ruins.Bestiary.rules.motion.gravity
		and Ruins.Bestiary.rules.motion.patrol_speed != 37, "species AI override keeps shared defaults intact")
	enemy.free()

	var wave: Dictionary = Ruins.HitEffects.settings.events.guard[0]
	wave.size = 77
	wave.duration = 0.12
	level.hit_effects.guard_impact(Vector2.ZERO, 1)
	var effect: Dictionary = level.hit_effects.shockwaves.back()
	check(effect.radius == 77 and effect.duration == 0.12 and effect.tint == Ruins.HitEffects.GUARD_TINT,
		"guard event uses configured radius, lifetime and tint")

	change_scene_to_file(Campaign.scene_path({"region": 0, "stage": 0}))
	await scene_changed
	var entry := current_scene as Ruins
	var entry_ambient := entry.get_node("AmbientLight") as CanvasModulate
	var rgb: Array = entry.presentation.ambient_rgb
	var minimum_color := Color.BLACK.lerp(Color(rgb[0], rgb[1], rgb[2]), 1.0 / 33.0)
	check(entry_ambient.color.is_equal_approx(minimum_color)
		and entry.background.self_modulate == entry_ambient.color,
		"ruins entry brightness 1 applies independently of ruins_1")
	Ruins.reward_rules.cache_equipment_by_region.ruins = ["copper_helm", "ram_boots"]
	Ruins.reward_rules.cache_materials = 11
	entry.hunter.global_position = entry.landscape.reliquaries[0].global_position
	var capacity := Ruins.Progression.bag_capacity(entry.hunter.level)
	while entry.inventory.size() < capacity - 1:
		if not entry._grant_equipment("hunter_knife", 1, true):
			break
	var before := entry.materials
	entry._interact()
	check(not entry.landscape.cache_open and entry.materials == before and not entry.obtained_equipment.has("ram_boots"),
		"cache with insufficient space grants nothing and remains available")
	entry._remove_inventory_item(entry.inventory.back().uid)
	entry._interact()
	check(entry.landscape.cache_open and entry.materials == before + 11 and entry.obtained_equipment.has("copper_helm")
		and entry.obtained_equipment.has("ram_boots"), "cache grants configured items and material count together")
	entry._interact()
	check(entry.materials == before + 11, "opened cache cannot grant rewards twice")
	unload_current_scene()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
