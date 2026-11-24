extends SceneTree

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const Campaign := preload("res://scripts/game/campaign.gd")
const Equipment := preload("res://scripts/game/ruin_equipment.gd")
const Monster := preload("res://scripts/character/ruin_monster.gd")
const Art := preload("res://scripts/character/ruin_sprite_art.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")
const Save := preload("res://scripts/game/camp_save.gd")
const SPAWNS := [
	{240: "dust_hare", 1320: "spider", 1580: "shale_beetle", 1880: "lizard",
		2240: "spider", 2340: "bell_moth", 2840: "treant"},
	{680: "reed_leech", 1180: "lantern_crab", 1600: "mirror_eel", 1780: "root_mole",
		2200: "silt_ray", 2640: "sluice_snail", 2940: "tide_salamander"},
	{700: "thorn_archer", 1020: "shield_heron", 1320: "key_jackal", 1600: "ash_scribe",
		1960: "shard_warden", 2260: "copper_cicada", 2560: "burial_ram", 2860: "seal_keeper"},
	{},
]

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
			# Sample the crown in each pose, clear of the raised weapon.
			check_giant_combat_size(id, entry.art, sheets, "",
				Rect2i(91, 46, 50, 64), {
					"attack": [Rect2i(95, 71, 33, 43), Rect2i(98, 45, 47, 71), Rect2i(98, 45, 45, 71)],
					"attack_transition": [Rect2i(92, 45, 46, 71), Rect2i(98, 43, 45, 75)],
				})
			check_giant_combat_size(id, entry.art, sheets, "_unarmed",
				Rect2i(95, 45, 54, 67), {
					"attack": [Rect2i(98, 48, 54, 70), Rect2i(94, 48, 56, 74), Rect2i(103, 49, 50, 73)],
					"attack_transition": [Rect2i(102, 50, 49, 72), Rect2i(99, 50, 56, 82)],
				})
		elif id == "seal_keeper":
			check_giant_combat_size(id, entry.art, sheets, "",
				Rect2i(144, 58, 6, 48), {
					"attack": [Rect2i(117, 77, 9, 48), Rect2i(115, 55, 31, 48), Rect2i(108, 58, 7, 48)],
					"attack_transition": [Rect2i(111, 57, 12, 48), Rect2i(119, 56, 29, 48)],
				})
		check(Bestiary.loot.monsters.has(id) and valid_drop_items(Bestiary.loot.monsters[id]),
			"%s has valid loot rules" % id)
	for region in range(Campaign.SCENES.size()):
		change_scene_to_file(Campaign.SCENES[region])
		await scene_changed
		var level := current_scene as Ruins
		var expected_spawns: Dictionary = SPAWNS[region].duplicate()
		check(level.region == region and level.enemies.size() == expected_spawns.size(),
			"%s spawns its configured roster" % Campaign.IDS[region])
		for monster in level.enemies:
			all_species[monster.species] = true
			check(monster.species == expected_spawns.get(int(monster.home.x), "") and monster.home.y == 540.0,
				"%s has its configured spawn position" % monster.species)
			expected_spawns.erase(int(monster.home.x))
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
	var idle := unarmed.get_region(Rect2i(Vector2i.ZERO, Art.ACTION_CELL)).get_used_rect()
	var grounded := int(Art.ACTION_ORIGIN.y)
	var consistent_height := true
	var consistent_feet := true
	for row in range(Art.Locomotion.size()):
		for frame in range(Art.ACTION_COLUMNS):
			var region := Rect2i(Vector2i(frame, row) * Art.ACTION_CELL, Art.ACTION_CELL)
			var with_blade := armed.get_region(region).get_used_rect()
			var without_blade := unarmed.get_region(region).get_used_rect()
			var height := grounded - with_blade.position.y
			consistent_height = consistent_height and absi(height - idle.size.y) <= 6
			consistent_height = consistent_height and absi(with_blade.position.y - without_blade.position.y) <= 2
			var lift := grounded - with_blade.end.y
			var expected_lift: int = [0, 0, 4, 6][frame] if row == Art.Locomotion.RUN else 0
			consistent_feet = consistent_feet and lift == expected_lift and with_blade.end.y == without_blade.end.y
	check(consistent_height, "treant stays at the same body height across gait and equipment changes")
	check(consistent_feet, "treant shares a foot baseline with or without the blade and lifts only in the last two run frames")


func check_giant_combat_size(id: String, appearance: Dictionary, sheets: Dictionary, suffix: String,
		idle_head_region: Rect2i, head_regions: Dictionary) -> void:
	var idle_image: Image = sheets["action" + suffix].get_image()
	var idle_frame := idle_image.get_region(Rect2i(Vector2i.ZERO, Art.ACTION_CELL))
	var idle_feet := ink_bounds(idle_frame, Rect2i(0, int(Art.ACTION_ORIGIN.y) - 8, Art.ACTION_CELL.x, 12))
	var idle_head := ink_bounds(idle_frame, idle_head_region)
	var idle_height := (Art.ACTION_ORIGIN.y - idle_head.position.y) * Art.ACTION_SCALE
	var idle_width := idle_feet.size.x * Art.ACTION_SCALE
	var layout := Art.combat_frame_layout(appearance)
	var cell := Vector2i(Bestiary.vector(layout.frame_size))
	var ground := int(Bestiary.vector(layout.frame_anchor).y)
	var scale := float(Bestiary.rules.art.frame_scale)
	var padding := Rect2i(Vector2i.ONE, cell - Vector2i(2, 2))
	for key: String in head_regions:
		var atlas := key + suffix
		var image: Image = sheets[atlas].get_image()
		var regions: Array = head_regions[key]
		check(image.get_size() == cell * Vector2i(regions.size(), 1), "%s %s matches its frame layout" % [id, atlas])
		for frame in range(regions.size()):
			var pose := image.get_region(Rect2i(Vector2i(frame * cell.x, 0), cell))
			var feet := ink_bounds(pose, Rect2i(0, ground - 8, cell.x, 12))
			var head := ink_bounds(pose, regions[frame])
			var height := (ground - head.position.y) * scale
			var width := feet.size.x * scale
			check(idle_head.has_area() and idle_feet.has_area() and head.has_area() and feet.has_area()
				and absi(feet.end.y - ground) <= 1 and padding.encloses(pose.get_used_rect())
				and absf(height / idle_height - 1.0) <= 0.07 and absf(width / idle_width - 1.0) <= 0.12,
				"%s %s frame %d body %.1f px (idle %.1f), foot span %.1f px (idle %.1f), sole row %d" % [
					id, atlas, frame, height, idle_height, width, idle_width, feet.end.y])


func ink_bounds(pose: Image, sample: Rect2i) -> Rect2i:
	var bounds := Rect2i()
	for y in range(sample.position.y, sample.end.y):
		for x in range(sample.position.x, sample.end.x):
			if pose.get_pixel(x, y).a >= 0.10:
				var pixel := Rect2i(Vector2i(x, y), Vector2i.ONE)
				bounds = bounds.merge(pixel) if bounds.has_area() else pixel
	return bounds


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
		var state := {"region": region, "stage": 0, "guardian_felled": true, "keeper_felled": true, "lantern_found": true}
		set_meta(Save.RESTORE_META, state)
		change_scene_to_file(Campaign.scene_path(state))
		await scene_changed
		var level := current_scene as Ruins
		if region in [Campaign.Region.TEMPLE, Campaign.Region.COURT]:
			var species := "treant" if region == Campaign.Region.TEMPLE else "seal_keeper"
			check(not level.enemies.any(func(monster: Monster) -> bool: return monster.species == species),
				"%s stays defeated when this checkpoint is restored" % species)
		if region == Campaign.Region.CORRIDOR:
			check(level.enemies.any(func(monster: Monster) -> bool: return monster.species == "lantern_crab" and not monster.armed),
				"restoring the lantern checkpoint spawns a disarmed crab")


func check(result: bool, message: String) -> void:
	if not result:
		failures += 1
	print("%s %s" % ["PASS" if result else "FAIL", message])
