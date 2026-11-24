extends SceneTree

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const Campaign := preload("res://scripts/game/campaign.gd")
const Ruins := preload("res://scripts/scene/ruins.gd")
const TILESET := preload("res://assets/monster/monster_tileset.tres")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var source := TILESET.get_source(0) as TileSetScenesCollectionSource
	check(TILESET.resource_name == "Monster" and TILESET.tile_size == Vector2i(20, 20),
		"Monster TileSet uses the 20 × 20 grid")
	var species_by_tile := {}
	for index in source.get_scene_tiles_count():
		var tile_id := source.get_scene_tile_id(index)
		var marker := source.get_scene_tile_scene(tile_id).instantiate() as Sprite2D
		species_by_tile[tile_id] = marker.get_meta("monster_species")
		check(marker.texture != null and marker.visible, "%s has a visible editor sprite" % species_by_tile[tile_id])
		marker.free()
	var roster: Array = species_by_tile.values()
	roster.sort()
	var expected := Bestiary.creatures.keys()
	expected.sort()
	check(roster == expected, "Monster TileSet covers all %d bestiary species once" % expected.size())

	for region in Campaign.SCENES.size():
		var packed := load(Campaign.SCENES[region]) as PackedScene
		if packed == null:
			check(false, "%s loads as a scene" % Campaign.IDS[region])
			continue
		var level := packed.instantiate() as Ruins
		var layer := level.get_node("Landscape/Monster") as TileMapLayer
		check(layer.tile_set == TILESET, "%s uses the shared Monster TileSet" % level.name)
		var original_cells := layer.get_used_cells()
		var placements := {}
		var removed_spawn := Vector2.INF
		if region == Campaign.Region.TEMPLE:
			var old_cell := Vector2i(142, 27)
			var new_cell := Vector2i(143, 27)
			var tile_id := layer.get_cell_alternative_tile(old_cell)
			layer.erase_cell(old_cell)
			layer.set_cell(new_cell, 0, Vector2i.ZERO, tile_id)
			removed_spawn = layer.position + layer.map_to_local(old_cell)
			placements[layer.position + layer.map_to_local(new_cell)] = "treant"
		var tile_ids := species_by_tile.keys()
		var count := tile_ids.size() if region == Campaign.Region.VOLCANO else 1
		for index in count:
			var cell := Vector2i(34 + index, 26 + index % 2)
			var tile_id: int = tile_ids[index]
			layer.set_cell(cell, 0, Vector2i.ZERO, tile_id)
			placements[layer.position + layer.map_to_local(cell)] = species_by_tile[tile_id]

		root.add_child(level)
		check(level.enemies.size() == original_cells.size() + count, "%s spawns each painted tile once" % level.name)
		check(not layer.visible, "%s hides editor sprites during play" % level.name)
		var unmatched := placements.duplicate()
		for monster in level.enemies:
			check(monster.home != removed_spawn, "%s has no spawn at the erased location" % monster.species)
			if not unmatched.has(monster.home):
				continue
			var species: String = unmatched.get(monster.home, "")
			check(monster.species == species and monster.position == monster.home and monster.target == level.hunter
				and monster.health > 0 and monster.felled.is_connected(level._on_monster_felled)
				and monster.disarmed.is_connected(level._on_monster_disarmed)
				and monster.launched.is_connected(level._launch_enemy_projectile),
				"%s at %s is registered for AI, combat and loot" % [monster.species, monster.home])
			unmatched.erase(monster.home)
		check(unmatched.is_empty(), "%s uses every painted grid position" % level.name)
		if region == Campaign.Region.TEMPLE:
			level.hunter.position.x = 2561.0
			check(level._monster_hint().is_empty(), "erasing the old treant tile removes its hint trigger")
			level.hunter.position.x = 2581.0
			check(level._monster_hint() == Bestiary.creatures.treant.encounter_hint.text,
				"moving the treant tile moves its hint trigger")
			level.hunter.position.x = 2340.0
			check(level._monster_hint() == Bestiary.creatures.bell_moth.encounter_hint.text,
				"the moved bell moth tile has its original encounter hint")
			level.owned_equipment.append("scaleveil_hood")
			check(level._monster_hint().is_empty(), "the bell moth hint respects the acquired equipment")
		level.free()
	quit(1 if failures else 0)


func check(result: bool, message: String) -> void:
	if not result:
		failures += 1
	print("%s %s" % ["PASS" if result else "FAIL", message])
