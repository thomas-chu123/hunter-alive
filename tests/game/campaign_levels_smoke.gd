extends SceneTree

const Campaign := preload("res://scripts/game/campaign.gd")
const Save := preload("res://scripts/game/camp_save.gd")
const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const Music := preload("res://scripts/music/game_music.gd")
const Level := preload("res://scripts/scene/ruins.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check(Campaign.scene_path({"region": 2}).ends_with("buried_court_1.tscn"), "older saves resume in stage 1 of their region")
	check(Campaign.scene_path({"region": -1, "stage": 99}).ends_with("ruins_1.tscn"), "invalid checkpoint location falls back to the start")
	for region in range(Campaign.IDS.size()):
		var stream := load(Music.BOSS_TRACKS[region]) as AudioStreamMP3
		check(stream != null and stream.get_length() >= 29.0, "region %d boss soundtrack imports" % (region + 1))

	change_scene_to_file(Campaign.scene_path({}))
	await scene_changed
	var textures := {}
	for region in range(Campaign.IDS.size()):
		for stage in range(1, Campaign.BOSS_STAGE + 1):
			var level := current_scene as Level
			var expected := Campaign.scene_path({"region": region, "stage": stage})
			if not check(level != null and level.scene_file_path == expected and level.stage == stage,
					"entered " + expected.get_file()):
				quit(1)
				return
			var texture_path := level.background.texture.resource_path
			if stage == 1:
				textures[region] = texture_path
			check(texture_path == textures[region], "region background stays consistent")
			var player := level.hunter
			var exit := level.landscape.portals[0]
			check(level._near_prop(level.landscape.campfires), "camp is in reach at spawn")
			level._interact()
			check(level.camp_menu.visible, "camp opens")
			level._set_camp_open(false)
			for enemy in level.enemies:
				enemy.set_physics_process(false)
			player.invincible_left = 30.0
			if stage < Campaign.BOSS_STAGE:
				await check_platforms(level)
			else:
				await check_boss(level)
			player.position = exit.global_position + Vector2(0, -1)
			level._interact()
			if region == Campaign.Region.VOLCANO and stage == Campaign.BOSS_STAGE:
				check(level.completed and level.end_screen.visible, "final portal shows the ending")
				check(Save.read().state.get("boss_felled", false), "final victory persists")
				continue
			for frame in range(20):
				if is_instance_valid(current_scene) and current_scene != level:
					break
				await process_frame
			var checkpoint: Dictionary = Save.read().get("state", {})
			var next_region := region + 1 if stage == Campaign.BOSS_STAGE else region
			var next_stage := stage + 1 if stage < Campaign.BOSS_STAGE else 1
			if not check(checkpoint.get("stage") == next_stage and checkpoint.get("region") == next_region,
					"exit saves the next region and stage"):
				quit(1)
				return
			if region == Campaign.Region.TEMPLE and stage == 2:
				change_scene_to_file(Campaign.TITLE_SCENE)
				await scene_changed
				current_scene._continue()
				await scene_changed
				check(current_scene.stage == 3, "title Continue opens the saved stage")
	check(textures.values().size() == 4 and Array(textures.values()).all(func(path): return textures.values().count(path) == 1),
		"four distinct backgrounds")
	var final_checkpoint: Dictionary = Save.read().state
	set_meta(Save.RESTORE_META, final_checkpoint)
	change_scene_to_file(Campaign.scene_path(final_checkpoint))
	await scene_changed
	check(current_scene.boss_felled and current_scene.enemies.is_empty() and current_scene.landscape.portal_open,
		"loading the final checkpoint preserves the defeated boss and open exit")
	quit(1 if failures else 0)


func check_platforms(level: Level) -> void:
	var terrain: TileMapLayer = level.get_node("Landscape/Terrain")
	var traps: TileMapLayer = level.get_node("Landscape/Traps")
	var roster_floors := {}
	for enemy in level.enemies:
		roster_floors[roundi(enemy.home.y / 20.0)] = true
	for floor_row in [27, 21, 15, 9, 3]:
		check(roster_floors.has(floor_row) and traps.get_used_cells().any(func(cell): return cell.y in [floor_row - 1, floor_row]),
			"floor %d has a monster and a trap" % floor_row)
	check(level.landscape.portals[0].position.y < level.landscape.campfires[0].position.y - 400.0,
		"exit is on the top floor")
	var hunter := level.hunter
	for row in [27, 24, 21, 18, 15, 12, 9, 6]:
		var possible := terrain.get_used_cells().filter(func(cell):
			return (cell.y == row - 3 and cell.x > 2 and cell.x < 35 and
				terrain.get_cell_alternative_tile(cell) == 1 and
				terrain.get_cell_source_id(cell + Vector2i(0, 3)) != -1))
		if not check(not possible.is_empty(), "overlapping step from row %d" % row):
			return
		var cell: Vector2i = possible[possible.size() / 2]
		hunter.position = Vector2(cell.x * 20 + 10, row * 20 - 4)
		hunter.velocity = Vector2.ZERO
		for frame in range(12):
			await physics_frame
		Input.action_press("hunt_jump")
		await physics_frame
		await physics_frame
		Input.action_release("hunt_jump")
		var reached := false
		for frame in range(45):
			await physics_frame
			if hunter.is_on_floor() and absf(hunter.position.y - (row - 3) * 20) < 5.0:
				reached = true
				break
		check(reached, "basic jump from y=%d to y=%d" % [row * 20, (row - 3) * 20])
	var elevated := level.enemies.filter(func(enemy): return enemy.position.y <= 300.0)
	if not elevated.is_empty():
		var enemy = elevated[0]
		enemy.state = enemy.State.RECOVER
		enemy.armed = false
		enemy.receive_hit(200, false)
		check(level.drops.any(func(drop): return drop.kind == "soul_currency" and drop.at.y < 470.0),
			"upper floor loot lands above ground level")
	if level.region == Campaign.Region.TEMPLE and level.stage == 1:
		await check_soul_routes(level)


func check_soul_routes(level: Level) -> void:
	var hunter := level.hunter
	hunter.position = Vector2(760, 416)
	hunter.velocity = Vector2.ZERO
	hunter.equipped_soul = "lizard"
	for frame in range(12):
		await physics_frame
	Input.action_press("hunt_right")
	Input.action_press("hunt_soul")
	Input.action_press("hunt_jump")
	await physics_frame
	await physics_frame
	Input.action_release("hunt_jump")
	var glided := false
	for frame in range(65):
		await physics_frame
		glided = glided or hunter.gliding
		if hunter.position.x >= 930.0:
			break
	Input.action_release("hunt_right")
	Input.action_release("hunt_soul")
	for frame in range(50):
		await physics_frame
		if hunter.is_on_floor():
			break
	check(glided and hunter.is_on_floor() and absf(hunter.position.y - 420.0) < 5.0,
		"lizard glide crosses the upper platform gap")

	hunter.position = Vector2(919, 536)
	hunter.velocity = Vector2.ZERO
	hunter.equipped_soul = "spider"
	for frame in range(12):
		await physics_frame
	Input.action_press("hunt_right")
	Input.action_press("hunt_soul")
	Input.action_press("hunt_jump")
	await physics_frame
	await physics_frame
	Input.action_release("hunt_jump")
	var climbed := false
	for frame in range(45):
		await physics_frame
		if hunter.wall_holding and hunter.velocity.y < 0.0:
			climbed = true
			break
	Input.action_press("hunt_jump")
	await physics_frame
	await physics_frame
	Input.action_release("hunt_jump")
	Input.action_release("hunt_soul")
	for frame in range(45):
		await physics_frame
		if hunter.position.x > 985.0:
			Input.action_release("hunt_right")
		if hunter.is_on_floor() and absf(hunter.position.y - 420.0) < 5.0:
			break
	Input.action_release("hunt_right")
	check(climbed and hunter.is_on_floor() and absf(hunter.position.y - 420.0) < 5.0,
		"spider soul climbs and wall-jumps onto the upper floor")
	hunter.equipped_soul = ""


func check_boss(level: Level) -> void:
	var boss := level.boss
	if not check(is_instance_valid(boss) and level.enemies.size() == 1, "arena has one boss"):
		return
	var terrain: TileMapLayer = level.get_node("Landscape/Terrain")
	check(terrain.get_used_cells().all(func(cell): return cell.y >= 27 or cell.x in [0, 91]),
		"boss arena has one continuous floor")
	var original: Dictionary = Bestiary.creatures[boss.species]
	check(boss.boss_scale > 1.0 and boss.level > original.level and boss.max_health > original.health,
		"boss scale, level and health exceed the base monster")
	check(level.boss_panel.visible and int(level.boss_health.max_value) == boss.max_health and
		level.boss_panel.anchor_left == 0.5, "large boss bar is centered at the top")
	check(root.get_node("GameMusic").current_region == Music.FIRST_BOSS + level.region,
		"entry selects the region's boss score")
	var portal := level.landscape.portals[0]
	level.hunter.position = portal.global_position
	level._interact()
	check(not level.landscape.portal_open and not level.transitioning and not level.completed, "live boss locks the exit")
	boss.receive_hit(2, false)
	level._update_boss_hud()
	check(int(level.boss_health.value) == boss.max_health - 2, "boss bar updates after damage")
	level._retry()
	boss = level.boss
	boss.set_physics_process(false)
	check(is_instance_valid(boss) and boss.health == boss.max_health, "retry restores the boss encounter")
	if level.region == Campaign.Region.COURT:
		boss.receive_hit(boss.max_health, false)
		check(boss.second_phase and boss.armed and boss.health == boss.max_health / 2, "keeper shield rises at half boss health")
		boss.windup = 0.4
		boss.receive_hit(1, true, true)
	elif level.region == Campaign.Region.VOLCANO:
		boss.receive_hit(boss.max_health / 2 + 1, false)
		level._update_boss_hud()
		check(boss.second_phase, "caldera boss reaches its second phase")
	boss.receive_hit(boss.max_health, false)
	level._update_boss_hud()
	check(level.boss_felled and not level.boss_panel.visible and level.landscape.portal_open,
		"boss defeat clears the HUD and unlocks the portal")


func check(condition: bool, description: String) -> bool:
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])
	return condition
