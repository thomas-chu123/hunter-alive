extends SceneTree

const Campaign := preload("res://scripts/game/campaign.gd")
const Hunter := preload("res://scripts/character/ruin_hunter.gd")
const Equipment := preload("res://scripts/game/ruin_equipment.gd")
const Progression := preload("res://scripts/game/ruin_progression.gd")
const Music := preload("res://scripts/music/game_music.gd")
const WeaponAudio := preload("res://scripts/sound/hunter_weapon_audio.gd")
const Trap := preload("res://scripts/trap/trap_tile.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1


func _initialize() -> void:
	verify.call_deferred()


func verify() -> void:
	var hunter := Hunter.new()
	check(hunter.health == Hunter.tuning.max_health and hunter.mana == Hunter.tuning.max_mana,
		"new hunter uses configured starting stats")
	check(hunter.unlocked_weapons == Equipment.STARTING_WEAPONS, "initial loadout matches catalog")
	for id in Equipment.catalog_ids():
		check(Equipment.item(id).size() == 3 and Equipment.icon(id) != null, "equipment metadata and icon: " + id)
	for id in WeaponAudio.PROFILES:
		var stream := WeaponAudio.make_stream(id)
		check(absf(stream.get_length() - WeaponAudio.PROFILES[id].duration) <= 1.0 / stream.mix_rate,
			"generated sample duration: " + id)
	for path in Music.TRACKS + Music.BOSS_TRACKS:
		check(load(path) is AudioStream, "music stream: " + str(path))
	for i in Campaign.regions.size():
		var region: Dictionary = Campaign.regions[i]
		check(ResourceLoader.exists(Campaign.scene_path({"region": i, "stage": 0}))
			and region.boss.level_bonus > 0 and region.boss.health_multiplier > 0, "region and boss: " + str(region.id))
	check(Progression.COLORS.size() > Progression.MAX_RANK, "each equipment rank has a frame color")
	for profile: String in Trap.settings.cycle_seconds:
		var packed := load("res://assets/environment/common/traps/%s.tscn" % profile) as PackedScene
		var tile := packed.instantiate() as Trap
		root.add_child(tile)
		check(is_equal_approx(tile._period(), Trap.settings.cycle_seconds[profile]), "trap cycle: " + profile)
		tile.free()
	var override_tile := (load("res://assets/environment/common/traps/ceiling_spikes.tscn") as PackedScene).instantiate() as Trap
	override_tile.cycle_seconds = 7.25
	root.add_child(override_tile)
	check(override_tile._period() == 7.25, "scene cycle override takes precedence")
	override_tile.free()
	hunter.free()
	quit(1 if failures else 0)
