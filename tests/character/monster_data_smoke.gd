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
	var lantern: Dictionary = Bestiary.loot.lantern
	var icon := load(lantern.icon_texture) as Texture2D
	check(icon != null and Rect2(Vector2.ZERO, icon.get_size()).encloses(Bestiary.rectangle(lantern.icon_region)),
		"the lantern drop still resolves its original icon region")
	var all_species := {}
	for id: String in Bestiary.creatures:
		var entry: Dictionary = Bestiary.creatures[id]
		var sheets := Art.load_poses(entry.art)
		var locomotion_ok := valid_locomotion(sheets.get("action"))
		if id == "spider":
			locomotion_ok = sheets.get("idle") != null and sheets.get("walk") != null
		check(locomotion_ok and sheets.attack != null and (
				not entry.attack.has("unarmed") or sheets.get("attack_unarmed") != null),
			"%s has usable sprites for its configured poses" % id)
		if entry.attack.has("unarmed"):
			check(valid_locomotion(sheets.get("action_unarmed")), "%s has a complete disarmed action atlas" % id)
		if id == "treant":
			check_treant_locomotion_size(sheets)
		check(Bestiary.loot.monsters.has(id) and valid_drop_items(Bestiary.loot.monsters[id]),
			"%s has valid loot rules" % id)
	for region in range(Campaign.SCENES.size()):
		change_scene_to_file(Campaign.SCENES[region])
		await scene_changed
		var level := current_scene as Ruins
		var expected: Array = Bestiary.encounters.get(Campaign.IDS[region], [])
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


func valid_locomotion(sheet: Texture2D) -> bool:
	var columns := Art.ACTION_COLUMNS
	var rows := Art.Locomotion.size()
	if sheet == null or sheet.get_size() != Vector2(Art.ACTION_CELL * Vector2i(columns, rows)):
		return false
	var image := sheet.get_image()
	var padding := Rect2i(Vector2i.ONE, Art.ACTION_CELL - Vector2i(2, 2))
	for row in range(rows):
		var poses := {}
		for column in range(columns):
			var origin := Vector2i(column, row) * Art.ACTION_CELL
			var pose := image.get_region(Rect2i(origin, Art.ACTION_CELL))
			var bounds := pose.get_used_rect()
			if not bounds.has_area() or not padding.encloses(bounds):
				return false
			poses[hash(pose.get_data())] = true
		if poses.size() < 3:
			return false
	return true


func check_treant_locomotion_size(sheets: Dictionary) -> void:
	var armed: Image = sheets.action.get_image()
	var unarmed: Image = sheets.action_unarmed.get_image()
	var reference: Image = sheets.attack_unarmed.get_image()
	var combat_cell := Vector2i(Bestiary.vector(Bestiary.rules.art.frame_size))
	var recovery := reference.get_region(Rect2i(Vector2i(combat_cell.x * 2, 0), combat_cell)).get_used_rect()
	var grounded := int(Art.ACTION_ORIGIN.y)
	var consistent_height := true
	var consistent_feet := true
	for row in range(Art.Locomotion.size()):
		for frame in range(Art.ACTION_COLUMNS):
			var region := Rect2i(Vector2i(frame, row) * Art.ACTION_CELL, Art.ACTION_CELL)
			var with_blade := armed.get_region(region).get_used_rect()
			var without_blade := unarmed.get_region(region).get_used_rect()
			var height := grounded - with_blade.position.y
			consistent_height = consistent_height and absi(height - recovery.size.y) <= 6
			consistent_height = consistent_height and absi(with_blade.position.y - without_blade.position.y) <= 2
			var lift := grounded - with_blade.end.y
			var expected_lift: int = [0, 0, 4, 6][frame] if row == Art.Locomotion.RUN else 0
			consistent_feet = consistent_feet and lift == expected_lift and with_blade.end.y == without_blade.end.y
	check(consistent_height, "treant stays at the same body height across gait and equipment changes")
	check(consistent_feet, "treant shares a foot baseline with or without the blade and lifts only in the last two run frames")


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
		for encounter in Bestiary.encounters.get(Campaign.IDS[region], []):
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
