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
	var giant_source := Tiles.get_source(5) as TileSetScenesCollectionSource
	var base_previews := {}
	for i in base.get_scene_tiles_count():
		var marker := base.get_scene_tile_scene(base.get_scene_tile_id(i)).instantiate() as Sprite2D
		base_previews[marker.get_meta("monster_species")] = marker.scale
		marker.free()
	var giant_homes := {}
	var giant_species := {}
	for i in giant_source.get_scene_tiles_count():
		var id := giant_source.get_scene_tile_id(i)
		var marker := giant_source.get_scene_tile_scene(id).instantiate() as Sprite2D
		var species: String = marker.get_meta("monster_species")
		check(base_previews.has(species) and marker.scale.is_equal_approx(base_previews.get(species, Vector2.ZERO) * 1.5),
			"%s giant preview is 1.5x" % species)
		giant_species[species] = true
		marker.free()
		var cell := Vector2i(40 + i, 12)
		layer.set_cell(cell, 5, Vector2i.ZERO, id)
		giant_homes[level.to_local(layer.to_global(layer.map_to_local(cell)))] = species
	check(giant_source.resource_name == "巨型" and giant_source.get_scene_tiles_count() == base_previews.size()
		and giant_species.size() == base_previews.size(), "giant palette covers the full roster once")
	var normal_mole_cell := Vector2i(32, 15)
	var giant_mole_cell := Vector2i(33, 15)
	layer.set_cell(normal_mole_cell, 0, Vector2i.ZERO, 10)
	layer.set_cell(giant_mole_cell, 5, Vector2i.ZERO, 1)
	var mole_design: Dictionary = Ruins.Bestiary.creatures.root_mole
	mole_design.scale = 1.25
	root.add_child(level)
	var normal_home := level.to_local(layer.to_global(layer.map_to_local(normal_mole_cell)))
	var giant_home := level.to_local(layer.to_global(layer.map_to_local(giant_mole_cell)))
	var normal_moles := level.enemies.filter(func(m): return m.home == normal_home and m.species == "root_mole")
	var giant_moles := level.enemies.filter(func(m): return m.home == giant_home and m.species == "root_mole")
	check(normal_moles.size() == 1 and giant_moles.size() == 1, "both painted mole variants spawn")
	if normal_moles.size() == 1 and giant_moles.size() == 1:
		var normal: Ruins.Monster = normal_moles[0]
		var giant: Ruins.Monster = giant_moles[0]
		check(normal.actor_art.scale == Vector2.ONE * 1.25, "ordinary tile uses species scale")
		check(giant.actor_art.scale == Vector2.ONE * 1.5, "giant tile overrides species scale")
		check(normal.body_hitbox().size == giant.body_hitbox().size
			and normal.get_child(0).shape.size == giant.get_child(0).shape.size,
			"visual scale preserves collision")
	var giant_bell_moth: Ruins.Monster
	var golden_outline := Color(str(Ruins.Bestiary.tier_profile(5).outline))
	for giant in level.enemies:
		if not giant_homes.has(giant.home):
			continue
		var species: String = giant_homes[giant.home]
		var gold := Ruins.Monster.new()
		gold.configure(species, Vector2.ZERO, null, 5)
		var group := giant.actor_art.get_parent() as CanvasGroup
		check(giant.species == species and giant.tier == gold.tier
			and giant.level == gold.level and giant.health == gold.health
			and giant.actor_art.scale == Vector2.ONE * 1.5
			and group != null and group.material.get_shader_parameter("outline_color") == golden_outline,
			"%s giant spawns with gold stats and outline at 1.5x" % species)
		gold.free()
		giant_homes.erase(giant.home)
		if species == "bell_moth":
			giant_bell_moth = giant
	check(giant_homes.is_empty(), "all giant tiles spawn at their painted positions")
	var configured := Ruins.Monster.new()
	configured.configure("root_mole", Vector2.ZERO, level.hunter, 0, -1.0)
	check(configured.visual_scale == 1.25, "invalid tile scale falls back to species scale")
	mole_design.scale = "invalid"
	configured.configure("root_mole", Vector2.ZERO, level.hunter)
	check(configured.visual_scale == 1.0, "invalid species scale falls back to 1.0")
	mole_design.erase("scale")
	configured.configure("root_mole", Vector2.ZERO, level.hunter, 0, 1.5)
	configured.promote_to_boss(2.0, 1, 1.0)
	level.add_child(configured)
	check(configured.actor_art.scale == Vector2.ONE * 3.0 and configured.boss_scale == 2.0,
		"visual multiplier composes with boss size")
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
	check(is_instance_valid(giant_bell_moth), "giant bell moth is available for loot check")
	if is_instance_valid(giant_bell_moth):
		giant_bell_moth.receive_hit(giant_bell_moth.max_health, false)
		var rolled := level.drops.filter(func(d): return d.rolled and d.rank == 5)
		var hoods := level.drops.filter(func(d): return d.kind == "scaleveil_hood" and d.rank == 5)
		check(rolled.size() == 1 and not hoods.is_empty(), "giant kill grants rank 5 random and species equipment")
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
	check(vault_layer.tile_set == Tiles,
		"ruins_1 Monster layer inherits the shared five-tier painting palette")
	for variant: Dictionary in Ruins.Bestiary.rules.tiers.variants:
		var source := vault_layer.tile_set.get_source(int(variant.tile_source_id)) as TileSetScenesCollectionSource
		check(source != null and source.resource_name == variant.name and source.get_scene_tiles_count() == base.get_scene_tiles_count(),
			"ruins_1 palette offers %s with the full roster" % variant.name)
	for cell in vault_layer.get_used_cells():
		if vault_layer.get_cell_alternative_tile(cell) == 10 or vault_layer.get_cell_source_id(cell) == 5:
			vault_layer.set_cell(cell, 4, Vector2i.ZERO, 10)
	root.add_child(vault)
	vault.hunter.position = vault.nest_position
	vault._update_nest()
	check(vault.guardian.tier == 5 and vault.guardian.health == 49, "delayed gold mole keeps painted tier")
	check(vault.guardian.actor_art.scale == Vector2.ONE, "unconfigured monster uses 1.0 scale")
	vault.free()

	var giant_vault := (load(Ruins.Campaign.scene_path({})) as PackedScene).instantiate() as Vault
	var giant_layer := giant_vault.get_node("Landscape/Monster") as TileMapLayer
	for cell in giant_layer.get_used_cells():
		if giant_layer.get_cell_alternative_tile(cell) == 10 or giant_layer.get_cell_source_id(cell) == 5:
			giant_layer.set_cell(cell, 5, Vector2i.ZERO, 1)
	root.add_child(giant_vault)
	giant_vault.hunter.position = giant_vault.nest_position
	giant_vault._update_nest()
	check(is_instance_valid(giant_vault.guardian) and giant_vault.guardian.actor_art.scale == Vector2.ONE * 1.5
		and giant_vault.guardian.tier == 5 and giant_vault.guardian.health == 49,
		"delayed giant mole retains its scale and gold stats")
	giant_vault.free()
	quit(1 if failures else 0)
