extends SceneTree

const Armory := preload("res://scripts/game/ruin_armory.gd")
const HitEffects := preload("res://scripts/effects/ruin_hit_effects.gd")
const Hunter := preload("res://scripts/character/ruin_hunter.gd")
const Monster := preload("res://scripts/character/ruin_monster.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var level := Ruins.new()
	level.hunter = Hunter.new()
	level.hit_effects = HitEffects.new()
	root.add_child(level.hit_effects)
	var weapons := ["hunter_knife", "hunter_bow", "ember_staff"] + Armory.WEAPONS.keys()
	for species: String in ["shale_beetle", "sluice_snail"]:
		for weapon: String in weapons:
			var breaks_guard := species == "sluice_snail" and weapon == "tide_hammer"
			check_attack(level, species, weapon, false, not breaks_guard)
	for weapon in ["hunter_knife", "hunter_bow", "ember_staff", "scribe_staff"]:
		check_attack(level, "sluice_snail", weapon, true, false)
	level.hit_effects.clear()
	OS.delay_msec(250)
	level.hit_effects.free()
	level.health_hearts.free()
	level.hunter.free()
	level.free()
	quit(1 if failures else 0)


func check_attack(level: Ruins, species: String, weapon: String, recovering: bool, blocked: bool) -> void:
	var effects := level.hit_effects
	effects.clear()
	var monster := Monster.new()
	monster.configure(species, Vector2(100, 100), level.hunter)
	monster.set_physics_process(false)
	root.add_child(monster)
	level.enemies.append(monster)
	level.hunter.position = monster.position - Vector2(54, 0)
	if recovering:
		monster._start_recovery(float(monster.attack.recovery))
	attack(level, monster, weapon)
	var damage := monster.max_health - monster.health
	var passed := false
	if blocked:
		passed = damage == 0 and effects.guard_voice.playing and effects.sparks.size() == 1 \
			and effects.sparks[0].tint == HitEffects.GUARD_TINT and effects.shockwaves.size() == 1 \
			and effects.shockwaves[0].tint == HitEffects.GUARD_TINT and effects.explosions.is_empty() \
			and effects.bursts.is_empty() and monster.blade_flash_left == 0.0
	else:
		passed = damage == 1 and not effects.guard_voice.playing
		if weapon == "ember_staff":
			passed = passed and effects.explosions.size() == 1 and effects.fire_voice.playing
	failures += int(not passed)
	print("%s %s %s %s: damage=%d guard_audio=%s sparks=%d explosions=%d" % [
		"PASS" if passed else "FAIL", species, weapon, "recovery" if recovering else "closed",
		damage, effects.guard_voice.playing, effects.sparks.size(), effects.explosions.size()])
	level.enemies.erase(monster)
	monster.free()


func attack(level: Ruins, monster: Monster, weapon: String) -> void:
	match weapon:
		"hunter_bow", "thorn_bow", "ember_staff":
			var sweep := Rect2(monster.position + Vector2(-48, -36), Vector2(12, 8))
			level._arrow_hits_monster(sweep,
				{"direction": 1.0, "damage": 1, "weapon": weapon, "spell": weapon == "ember_staff", "hit_ids": []})
		"scribe_staff":
			level.glyphs.append({"at": monster.position, "left": 0.01, "damage": 1, "direction": 1.0})
			level._update_glyphs(0.02)
		_:
			level._attack(level.hunter.position + Vector2(14, -30), 1.0, false, 1, weapon)
