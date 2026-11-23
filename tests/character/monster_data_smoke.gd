extends SceneTree

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const Campaign := preload("res://scripts/game/campaign.gd")
const Equipment := preload("res://scripts/game/ruin_equipment.gd")
const Monster := preload("res://scripts/character/ruin_monster.gd")
const Art := preload("res://scripts/character/ruin_sprite_art.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")
const Save := preload("res://scripts/game/camp_save.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == Campaign.TITLE_SCENE
		and ResourceLoader.exists(Campaign.TITLE_SCENE), "title resolves through the new scene path")
	var all_species := {}
	for id: String in Bestiary.creatures:
		var entry: Dictionary = Bestiary.creatures[id]
		var sheets: Dictionary = Art.poses[id]
		check(sheets.idle != null and sheets.attack != null and (
				not entry.attack.has("unarmed") or sheets.get("attack_unarmed") != null),
			"%s has usable sprites for its configured poses" % id)
		check(Bestiary.loot.monsters.has(id) and valid_drop_items(Bestiary.loot.monsters[id]),
			"%s has valid loot rules" % id)
	for region in range(Campaign.SCENES.size()):
		change_scene_to_file(Campaign.SCENES[region])
		await scene_changed
		var level := current_scene as Ruins
		var expected: Array = Bestiary.encounters[Campaign.IDS[region]]
		check(level.region == region and level.enemies.size() == expected.size(),
			"%s spawns its configured roster" % Campaign.IDS[region])
		for index in range(mini(level.enemies.size(), expected.size())):
			var monster := level.enemies[index]
			var encounter: Dictionary = expected[index]
			all_species[monster.species] = true
			check(monster.species == encounter.species and is_equal_approx(monster.home.x, float(encounter.x)),
				"%s has its configured spawn position" % monster.species)
	check(all_species.size() == Bestiary.creatures.size(), "no monster data is missing an encounter")
	await check_checkpoint_spawns()
	quit(1 if failures else 0)


func valid_drop_items(rules: Dictionary) -> bool:
	for event in ["before_defeat", "defeat", "disarm"]:
		for rule: Dictionary in rules.get(event, []):
			var item: String = rule.item
			if item not in ["material", "fang_material", "blade", "lantern"] and (
					Equipment.item(item).is_empty() and Bestiary.soul(item).is_empty()):
				return false
	return true


func check_checkpoint_spawns() -> void:
	for region in range(Campaign.SCENES.size()):
		var state := {"region": region, "guardian_felled": true, "keeper_felled": true, "lantern_found": true}
		set_meta(Save.RESTORE_META, state)
		change_scene_to_file(Campaign.scene_path(state))
		await scene_changed
		var level := current_scene as Ruins
		for encounter in Bestiary.encounters[Campaign.IDS[region]]:
			var flag: String = encounter.get("skip_if", "")
			if not state.get(flag, false):
				continue
			var species: String = encounter.species
			check(not level.enemies.any(func(monster: Monster) -> bool: return monster.species == species),
				"%s stays defeated when this checkpoint is restored" % species)
		if region == Campaign.Region.CORRIDOR:
			check(level.enemies.any(func(monster: Monster) -> bool: return monster.species == "lantern_crab" and not monster.armed),
				"restoring the lantern checkpoint spawns a disarmed crab")


func check(result: bool, message: String) -> void:
	if not result:
		failures += 1
	print("%s %s" % ["PASS" if result else "FAIL", message])
