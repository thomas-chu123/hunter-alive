extends SceneTree

const Vault := preload("res://scripts/scene/temple_vault.gd")
const Campaign := preload("res://scripts/game/campaign.gd")
const Hunter := preload("res://scripts/character/ruin_hunter.gd")
var failures := 0


func check(valid: bool, description: String) -> void:
	print("PASS " if valid else "FAIL ", description)
	if not valid:
		failures += 1


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file(Campaign.scene_path({}))
	await scene_changed
	var level := current_scene as Vault
	var hunter := level.hunter
	if "--route" in OS.get_cmdline_user_args():
		await check_route(level)
		quit(1 if failures else 0)
		return
	var terrain := level.terrain
	var props := level.get_node("Landscape/Props") as TileMapLayer
	# Check the four ascent shafts and all gaps crossed on the direct route.
	var shafts := [Vector2i(28, 27), Vector2i(98, 15), Vector2i(47, 3), Vector2i(95, -9)]
	var x := 11
	for shaft: Vector2i in shafts:
		check(props.get_cell_source_id(shaft) == 3 and props.get_cell_source_id(shaft + Vector2i.UP * 6) == 3
			and terrain.get_cell_source_id(shaft + Vector2i.UP * 12) < 0, "paired climb through floor at %s" % shaft)
		check(walkable_span(terrain, x, shaft.x, shaft.y), "traversable approach on row %d" % shaft.y)
		x = shaft.x
	check(walkable_span(terrain, x, 118, -21) and level.landscape.portal_open, "top path reaches open stone gate")
	var lizard = level.enemies.filter(func(m): return m.species == "lizard")[0]
	lizard.set_physics_process(false)
	var trap: Node2D
	for tile in level.get_node("Landscape/Traps").get_children(true):
		if tile is Vault.Trap and tile.kind == Vault.Trap.Kind.BOULDER:
			trap = tile
	hunter.position = Vector2(850, 540)
	lizard.position = Vector2(1060, 540)
	level.hare.position = lizard.position + Vector2(13, 0)
	var before: int = lizard.health
	level._update_clash(0.1)
	check(lizard.health < before and level.hare.health < level.hare.max_health, "lizard and hare wound each other in close contact")
	level.hare.position.x = 1440
	level.hare.set_physics_process(false)
	trap._activate()
	var lizard_id: int = lizard.get_instance_id()
	for frame in 65:
		await physics_frame
	check(not instance_from_id(lizard_id) and level._has_drop("lizard"), "rolling boulder defeats lizard and awards its soul")
	hunter.position = Vault.SLUICE
	level._interact()
	check(level.drained and terrain.get_cell_source_id(Vector2i(109, 25)) < 0 and terrain.get_cell_source_id(Vector2i(109, 19)) >= 0,
		"sluice opens lab at ground level and leaves the 160 px climbing ledge intact")
	hunter.position = Vector2(2420, 540)
	level._interact()
	hunter.gear["頭部"] = "sealed_cap"
	hunter.invincible_left = 0
	var health := hunter.health
	hunter.hurt(2500, 1, "poison")
	check(level.obtained_equipment.has("sealed_cap") and hunter.health == health, "research room mask protects against poison")
	hunter.position = Vector2(2350, -182)
	hunter.velocity = Vector2.ZERO
	for frame in 24:
		await physics_frame
	check(level.crack_time > 0 and not level.collapsed, "standing on slab gives advance warning")
	for frame in 110:
		await physics_frame
	check(level.collapsed and hunter.is_on_floor() and absf(hunter.position.y - 60) < 2, "collapse lands inside treasury")
	hunter.position = Vector2(2410, 60)
	level._update_nest()
	var mole: Array = level.enemies.filter(func(m): return m.species == "root_mole")
	check(mole.size() == 1 and mole[0].profile.speed > mole[0].design.motion.speed, "stone hunting awakens a faster disguised nest guardian")
	hunter.position = Vector2(2600, 60)
	level._interact()
	check(not level.obtained_equipment.has("cliff_boots"), "guardian blocks treasure while alive")
	check(mole[0].receive_hit(99, false) == level.Monster.HitResult.BLOCKED, "closed stone shell resists attacks")
	mole[0].state = level.Monster.State.RECOVER
	mole[0].receive_hit(99, false)
	level._interact()
	check(level.obtained_equipment.has("cliff_boots"), "treasury awards cliff boots")
	hunter.position = Vector2(2180, 60)
	level._interact()
	check(not level.passage_open, "wall release inaccessible from main route")
	hunter.position = Vault.RELEASE
	level._interact()
	check(level.passage_open and terrain.get_cell_source_id(Vector2i(110, 2)) < 0, "inside release opens return passage")
	hunter.position = Vector2(2100, 60)
	for frame in 300:
		await physics_frame
	check(level.loose_floor == 15 and terrain.get_cell_source_id(Vector2i(127, 3)) < 0 and terrain.get_cell_source_id(Vector2i(127, 15)) >= 0,
		"treasury collapse leaves a safe lower landing")
	var saved := level._checkpoint_state()
	set_meta(level.CampSave.RESTORE_META, saved)
	reload_current_scene()
	await scene_changed
	level = current_scene as Vault
	check(level.passage_open and level.collapsed and level.drained and level.loose_floor == 15 and level.obtained_equipment.has("cliff_boots"), "checkpoint restores passage, collapse and reward")
	quit(1 if failures else 0)


func walkable_span(terrain: TileMapLayer, start: int, finish: int, row: int) -> bool:
	var gap := 0
	var width := terrain.tile_set.tile_size.x
	var jump_span := 2.0 * Hunter.JUMP_SPEED * Hunter.RUN_SPEED / Hunter.GRAVITY
	for x in range(mini(start, finish), maxi(start, finish) + 1):
		var data := terrain.get_cell_tile_data(Vector2i(x, row))
		if data != null and data.get_collision_polygons_count(0) > 0:
			gap = 0
		else:
			gap += width
			if gap + 12 > jump_span:
				return false
	return true


func check_route(level: Vault) -> void:
	var hunter := level.hunter
	var terrain := level.terrain
	var targets: Array[Vector2] = [Vector2(560, 540), Vector2(1960, 300),
		Vector2(940, 60), Vector2(1900, -180), Vector2(2360, -420)]
	# Isolate traversal; enemy AI and trap timing are covered separately.
	for enemy in level.enemies:
		enemy.set_physics_process(false)
	for tile in level.get_node("Landscape/Traps").get_children(true):
		tile.set_physics_process(false)
	for target: Vector2 in targets:
		var dir := signf(target.x - hunter.position.x)
		var move := "hunt_right" if dir > 0 else "hunt_left"
		Input.action_press(move)
		for i in 1150:
			if absf(hunter.position.x - target.x) < 12:
				break
			if hunter.position.y > target.y + 40:
				break
			var forward := terrain.local_to_map(Vector2(hunter.position.x + dir * 22, target.y + 2))
			if hunter.is_on_floor() and (terrain.get_cell_source_id(forward) < 0 or hunter.is_on_wall()):
				Input.action_press("hunt_jump")
			await physics_frame
			Input.action_release("hunt_jump")
		Input.action_release(move)
		print("walk ", target, " reached ", hunter.position)
		if absf(hunter.position.x - target.x) > 15 or hunter.position.y > target.y + 40:
			check(false, "failed to reach waypoint %s" % target)
			return
		if target == targets.back():
			check(level._near_prop(level.landscape.portals), "continuous traversal from camp to interactable exit")
			return
		Input.action_press("hunt_climb_up")
		for i in 230:
			await physics_frame
			if hunter.position.y <= target.y - 245:
				break
		Input.action_release("hunt_climb_up")
		print("climb ", hunter.position)
		if hunter.position.y > target.y - 239:
			check(false, "failed to reach waypoint %s" % target)
			return
		Input.action_press("hunt_jump")
		await physics_frame
		await physics_frame
		Input.action_release("hunt_jump")
