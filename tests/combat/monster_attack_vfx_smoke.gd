extends SceneTree

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const EnemyEffects := preload("res://scripts/effects/ruin_enemy_effects.gd")
const Monster := preload("res://scripts/character/ruin_monster.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/ruins/ruins.tscn")
	await scene_changed
	var level := current_scene as Ruins
	level.set_physics_process(false)
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	level.hunter.set_physics_process(false)
	level.hunter.position = Vector2(1120, 539)
	await physics_frame
	await physics_frame

	check_melee_timing(level)
	check_projectiles(level)
	print("Monster attack VFX failures: ", failures)
	quit(1 if failures else 0)


func check_melee_timing(level: Ruins) -> void:
	var monster := Monster.new()
	monster.configure("dust_hare", Vector2(1020, 539), level.hunter)
	level.add_child(monster)
	monster.set_physics_process(false)
	monster._start_strike()

	var first := float(monster.combat_rules.strike_moments[0])
	var second := float(monster.combat_rules.strike_moments[1])
	var recharge := float(monster.combat_rules.double_windup_at)
	monster.strike = float(monster.attack.active) * (1.0 - first - 0.001)
	monster._update_strike()
	check(monster.impact_index == 1 and monster._release_vfx_progress(first) == 0.0,
		"first melee flare starts at the first hit")
	check(monster._release_vfx_progress(recharge) == 1.0 and monster._between_double_hits(recharge),
		"first crescent fades before the second windup")
	monster.strike = float(monster.attack.active) * (1.0 - second - 0.001)
	monster._update_strike()
	check(monster.impact_index == 2 and monster._release_vfx_progress(second) == 0.0
		and monster._release_vfx_progress(1.0) == 1.0, "second hit starts a fresh flare and fades by the end")
	monster.queue_free()


func check_projectiles(level: Ruins) -> void:
	var effects := level.hit_effects
	var attack: Dictionary = Bestiary.creatures.lizard.attack
	var origin := Vector2(1090, 500)
	var tint := EnemyEffects.element_color(attack.element)
	level._launch_enemy_projectile(origin, 1.0, attack)
	check(level.arrows.size() == 1 and effects.starbursts.size() == 1 and effects.shockwaves.size() == 1
		and effects.starbursts[0].point == origin and effects.shockwaves[0].tint == tint,
		"hostile launch produces one elemental flash and ring at the outlet")
	level._update_arrows(0.01)
	check(level.arrows.size() == 1
		and absf(level.arrows[0].at.x - float(level.arrows[0].origin_x) - float(attack.speed) * 0.01) < 0.001
		and level.arrows[0].at.y == origin.y, "trail starts at the outlet and follows travel")
	var health := level.hunter.health
	level._update_arrows(0.08)
	check(level.arrows.is_empty() and level.hunter.health == health - int(attack.damage)
		and effects.starbursts.back().point == Vector2(level.hunter.position.x, origin.y)
		and effects.shockwaves.back().tint == tint, "hunter contact preserves damage and adds an elemental burst")

	effects.clear()
	# The wall in the temple stops this shot before the hunter.
	level._launch_enemy_projectile(Vector2(1020, 500), 1.0, attack)
	level._update_arrows(0.27)
	check(level.arrows.is_empty() and level.hunter.health == health - int(attack.damage)
		and effects.starbursts.size() == 2 and effects.starbursts.back().point == Vector2(1080, 500)
		and effects.shockwaves.back().tint == tint, "terrain contact adds a burst at the wall")

	effects.clear()
	level._launch_enemy_projectile(Vector2(1020, 445), -1.0, attack)
	level.arrows[0].left = 0.001
	level._update_arrows(0.02)
	check(level.arrows.is_empty() and effects.starbursts.size() == 1 and effects.shockwaves.size() == 1,
		"an expired projectile adds no collision burst")


func check(condition: bool, message: String) -> void:
	print("%s %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1
