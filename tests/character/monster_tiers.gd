extends SceneTree

const Ruins := preload("res://scripts/scene/ruins.gd")
const Vault := preload("res://scripts/scene/temple_vault.gd")
const Tiles := preload("res://assets/monster/monster_tileset.tres")
var failures := 0


func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	failures += int(not ok)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var level := (load(Ruins.Campaign.SCENES[0]) as PackedScene).instantiate() as Ruins
	var layer := level.get_node("Landscape/Monster") as TileMapLayer
	var base := Tiles.get_source(0) as TileSetScenesCollectionSource
	var homes: Array[Vector2] = []
	for tier in range(1, 6):
		var source := Tiles.get_source(tier - 1) as TileSetScenesCollectionSource
		var same := source.get_scene_tiles_count() == Ruins.Bestiary.creatures.size()
		for i in base.get_scene_tiles_count():
			var id := base.get_scene_tile_id(i)
			same = same and source.get_scene_tile_scene(id) == base.get_scene_tile_scene(id)
			var marker := base.get_scene_tile_scene(id).instantiate()
			var species: String = marker.get_meta("monster_species")
			marker.free()
			var monster := Ruins.Monster.new()
			monster.configure(species, Vector2.ZERO, null, tier)
			var design: Dictionary = Ruins.Bestiary.creatures[species]
			same = same and monster.level == int(design.level) + 5 * (tier - 1)
			same = same and monster.health == int(design.health) + 10 * (tier - 1)
			monster.free()
		check(same, "all 21 species share scenes and retain base stats plus tier %d bonuses" % tier)
		var cell := Vector2i(25 + tier, 15)
		layer.set_cell(cell, tier - 1, Vector2i.ZERO, 1)
		homes.append(layer.position + layer.map_to_local(cell))
	root.add_child(level)
	for tier in range(1, 6):
		var monsters := level.enemies.filter(func(m): return m.home == homes[tier - 1])
		check(monsters.size() == 1 and monsters[0].tier == tier, "painted source spawns tier %d" % tier)
		var spider: Ruins.Monster = monsters[0]
		if tier == 1:
			check(spider.actor_art.get_parent() == spider, "default sprite has no outline")
		else:
			var group := spider.actor_art.get_parent() as CanvasGroup
			var expected := Color(str(Ruins.Bestiary.tier_profile(tier).outline))
			check(group != null and group.material.get_shader_parameter("outline_color") == expected,
				"outline material uses tier %d color" % tier)
			spider.flash_blade_hit()
			spider._physics_process(0.06)
			check(spider.actor_art.material == null and group.material != null, "tier %d outline survives hit flash" % tier)
		check(Ruins.Progression.drop_rank(0.38749, tier) == tier and Ruins.Progression.drop_rank(0.3875, tier) == 0,
			"tier %d rank and no-drop boundary" % tier)

	var chance: float = Ruins.Bestiary.loot.random_equipment.chance
	Ruins.Bestiary.loot.random_equipment.chance = 1
	level._add_monster("bell_moth", 555, 540, 5)
	var moth: Ruins.Monster = level.enemies.back()
	moth.receive_hit(moth.max_health, false)
	var rolled := level.drops.filter(func(d): return d.rolled and d.rank == 5)
	var hoods := level.drops.filter(func(d): return d.kind == "scaleveil_hood" and d.rank == 5)
	check(rolled.size() == 1 and not hoods.is_empty(), "gold kill grants rank 5 random and species equipment")
	Ruins.Bestiary.loot.random_equipment.chance = chance
	level._add_monster("treant", 660, 540, 4)
	level._on_monster_disarmed(level.enemies.back())
	level.guardian_felled = true
	var checkpoint := level._checkpoint_state()
	level.drops.clear()
	level._restore_camp(checkpoint)
	check(level.drops.any(func(d): return d.kind == "blade" and d.rank == 4), "unclaimed silver weapon keeps rank on restore")
	checkpoint.erase("blade_rank")
	level.drops.clear()
	level._restore_camp(checkpoint)
	check(level.drops.any(func(d): return d.kind == "blade" and d.rank == 1), "old checkpoint defaults to rank 1")
	level.free()

	var vault := (load(Ruins.Campaign.scene_path({})) as PackedScene).instantiate() as Vault
	var vault_layer := vault.get_node("Landscape/Monster") as TileMapLayer
	check(vault_layer.tile_set == Tiles and Tiles.get_source_count() == 5,
		"ruins_1 Monster layer inherits the shared five-tier painting palette")
	for variant: Dictionary in Ruins.Bestiary.rules.tiers.variants:
		var source := vault_layer.tile_set.get_source(int(variant.tile_source_id)) as TileSetScenesCollectionSource
		check(source != null and source.resource_name == variant.name and source.get_scene_tiles_count() == base.get_scene_tiles_count(),
			"ruins_1 palette offers %s with the full roster" % variant.name)
	for cell in vault_layer.get_used_cells():
		if vault_layer.get_cell_alternative_tile(cell) == 10:
			vault_layer.set_cell(cell, 4, Vector2i.ZERO, 10)
	root.add_child(vault)
	vault.hunter.position = vault.nest_position
	vault._update_nest()
	check(vault.guardian.tier == 5 and vault.guardian.health == 49, "delayed gold mole keeps painted tier")
	vault.free()
	quit(1 if failures else 0)
