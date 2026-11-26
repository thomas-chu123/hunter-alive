extends SceneTree

const Balloon := preload("res://scripts/ui/npc_dialogue_balloon.gd")
const Temple := preload("res://scripts/scene/temple_vault.gd")
const Progression := preload("res://scripts/game/ruin_progression.gd")

var failures := 0


func _initialize() -> void:
	run_checks.call_deferred()


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])


func choose(ruins: Temple, cue: String) -> DialogueLine:
	var greeting := await Temple.NPC_DIALOGUE.get_next_dialogue_line(cue, [ruins])
	if greeting == null or greeting.responses.size() != 2:
		check(false, "%s has an action and a leave option" % cue)
		return null
	var result := await Temple.NPC_DIALOGUE.get_next_dialogue_line(greeting.responses[0].next_id, [ruins])
	check(result != null and result.text == ruins.npc_feedback, "%s action runs through Dialogue Manager" % cue)
	return result


func run_checks() -> void:
	var scene: PackedScene = load("res://scenes/ruins/ruins_1.tscn")
	var ruins := scene.instantiate() as Temple
	root.add_child(ruins)
	current_scene = ruins
	var layer := ruins.npc_layer
	var terrain: TileMapLayer = ruins.get_node("Landscape/Terrain")
	for cell in layer.get_used_cells():
		var tile := layer.get_cell_tile_data(cell)
		var cue: String = tile.get_custom_data("dialogue_cue")
		var feet := layer.to_global(layer.map_to_local(cell))
		var ground := terrain.local_to_map(terrain.to_local(feet + Vector2.DOWN))
		check(terrain.get_cell_source_id(ground) != -1 and layer.nearest_to(feet) == tile,
			"%s tile has ground and is selected at its feet" % cue)
	var atlas := layer.tile_set.get_source(0) as TileSetAtlasSource
	var cues := {}
	var sprite_sheet := atlas.texture.get_image()
	for index in atlas.get_tiles_count():
		var coords := atlas.get_tile_id(index)
		var tile := atlas.get_tile_data(coords, 0)
		var region := atlas.get_tile_texture_region(coords)
		var sprite_bottom := sprite_sheet.get_region(region).get_used_rect().end.y
		var feet_offset := sprite_bottom - region.size.y / 2.0 - tile.texture_origin.y
		var cue: String = tile.get_custom_data("dialogue_cue")
		cues[cue] = true
		check(is_zero_approx(feet_offset), "%s sprite feet align with the interaction point" % cue)
		var greeting := await Temple.NPC_DIALOGUE.get_next_dialogue_line(cue, [ruins])
		check(greeting != null and not greeting.character.is_empty() and not greeting.text.is_empty(),
			"%s has a named greeting" % cue)
	check(cues.size() == 15 and atlas.get_tiles_count() == 15, "TileSet contains 15 unique NPCs")
	var palette := TileMapLayer.new()
	palette.tile_set = layer.tile_set
	var pattern_cues := {}
	for index in palette.tile_set.get_patterns_count():
		var pattern := palette.tile_set.get_pattern(index)
		var cell := Vector2i(index, 0)
		palette.set_pattern(cell, pattern)
		var tile := palette.get_cell_tile_data(cell)
		check(pattern.get_used_cells() == [Vector2i.ZERO] and tile != null
			and pattern.resource_name == tile.get_custom_data("npc_name"),
			"NPC pattern %d stamps its named tile" % (index + 1))
		if tile != null:
			pattern_cues[tile.get_custom_data("dialogue_cue")] = pattern
	check(pattern_cues.size() == cues.size() and cues.keys().all(func(cue): return pattern_cues.has(cue)),
		"NPC patterns cover the complete roster")
	palette.free()
	check(layer.nearest_to(Vector2(-200, 540)) == null, "out-of-range interaction rejected")

	# Exercise the overlap even when the authored Lia tile is moved elsewhere.
	var door_test_cell := Vector2i(15, 27)
	layer.set_pattern(door_test_cell, pattern_cues["lia"])
	var lia_by_door := layer.to_global(layer.map_to_local(door_test_cell))
	ruins.hunter.global_position = lia_by_door
	var door := ruins._find_door()
	check(door != null, "Lia and the wooden door have overlapping interaction ranges")
	if door != null:
		ruins.hunter.global_position = door.global_position
		check(ruins._near_npc(ruins._find_door()) == null, "standing at the wooden door still selects the door")

	ruins.hunter.global_position = lia_by_door
	ruins.hunter.velocity = Vector2.ZERO
	await process_frame
	await process_frame
	check("莉亞" in ruins.prompt_label.text, "the interaction prompt names Lia beside the door")
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_E
	interact_key.pressed = true
	Input.parse_input_event(interact_key)
	await physics_frame
	await process_frame
	interact_key.pressed = false
	Input.parse_input_event(interact_key)
	var balloon := ruins.npc_balloon as Balloon
	check(is_instance_valid(balloon) and not ruins.hunter.is_physics_processing(), "physical E opens one balloon and locks gameplay")
	if is_instance_valid(balloon):
		check(not balloon.balloon.get_children().any(func(child: Node) -> bool: return child is Button),
			"NPC dialogue UI has no example banner")
		check(balloon.dialogue_line != null and balloon.dialogue_line.character == "莉亞", "the balloon displays Lia’s conversation")
		ruins._interact()
		check(ruins.npc_balloon == balloon, "repeat interaction keeps the same balloon")
		if balloon.dialogue_line != null and balloon.dialogue_line.responses.size() == 2:
			await balloon.next(balloon.dialogue_line.responses[1].next_id)
		await process_frame
	check(not is_instance_valid(ruins.npc_balloon) and ruins.hunter.is_physics_processing(), "leaving the dialogue unlocks gameplay")

	var stock := ruins.inventory.size()
	var original_inventory := ruins.inventory.duplicate()
	while ruins.inventory.size() < Progression.bag_capacity(ruins.hunter.level):
		ruins.inventory.append({"uid": -1, "item": Temple.NPC_GIFT, "rank": 1})
	await choose(ruins, "martha")
	check(not ruins.npc_gift_claimed, "full bag preserves the gift")
	ruins.soul_balance = Temple.NPC_SHOP_PRICE
	await choose(ruins, "finn")
	check(ruins.soul_balance == Temple.NPC_SHOP_PRICE, "full bag preserves shop payment")
	ruins.inventory = original_inventory

	await choose(ruins, "martha")
	await choose(ruins, "martha")
	check(ruins.inventory.size() == stock + 1 and ruins._first_item(Temple.NPC_GIFT) > 0, "gift adds exactly one item")
	ruins.soul_balance = 0
	await choose(ruins, "finn")
	check(ruins._first_item(Temple.NPC_SHOP_ITEM) == 0 and ruins.soul_balance == 0, "insufficient funds gives no item")

	await choose(ruins, "ed")
	check(ruins.soul_balance == 0, "turn-in requires the letter")
	await choose(ruins, "pip")
	await choose(ruins, "pip")
	ruins._update_hud()
	check(ruins.letter_quest == Temple.LetterQuest.CARRYING and "皮普" in ruins.status_flags.text, "acceptance puts the letter objective in the HUD")
	var active_checkpoint := ruins._checkpoint_state().duplicate(true)
	ruins.letter_quest = Temple.LetterQuest.AVAILABLE
	ruins._restore_camp(active_checkpoint)
	check(ruins.letter_quest == Temple.LetterQuest.CARRYING, "an active quest survives checkpoint restore")
	await choose(ruins, "ed")
	await choose(ruins, "ed")
	ruins._update_hud()
	check(ruins.letter_quest == Temple.LetterQuest.DELIVERED and ruins.soul_balance == Temple.LETTER_REWARD and "皮普" not in ruins.status_flags.text,
		"turn-in consumes the letter, clears the objective and pays once")
	await choose(ruins, "finn")
	check(ruins._first_item(Temple.NPC_SHOP_ITEM) > 0 and ruins.soul_balance == Temple.LETTER_REWARD - Temple.NPC_SHOP_PRICE, "purchase exchanges souls for equipment")

	ruins.hunter.health = 1
	ruins.hunter.mana = 0
	await choose(ruins, "lia")
	check(ruins.hunter.health == ruins.hunter.max_health() and ruins.hunter.mana == 0, "healer restores HP without changing mana")
	var saved := ruins._checkpoint_state().duplicate(true)
	ruins._restore_camp({})
	check(not ruins.npc_gift_claimed and ruins.letter_quest == Temple.LetterQuest.AVAILABLE, "legacy checkpoints default to unclaimed gift and available quest")
	ruins._restore_camp(saved)
	check(ruins.npc_gift_claimed and ruins.letter_quest == Temple.LetterQuest.DELIVERED, "gift and completed quest survive checkpoint restore")
	print("NPC checks finished with %d failures" % failures)
	quit(1 if failures else 0)
