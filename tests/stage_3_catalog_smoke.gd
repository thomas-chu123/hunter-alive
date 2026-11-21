extends SceneTree

const Campaign := preload("res://scripts/campaign.gd")
const Bestiary := preload("res://scripts/ruin_bestiary.gd")
const Equipment := preload("res://scripts/ruin_equipment.gd")
const Armory := preload("res://scripts/ruin_armory.gd")
const Save := preload("res://scripts/camp_save.gd")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var state: Dictionary = {}
	var ordinary := {}
	for region in range(3):
		state["region"] = region
		set_meta(Save.RESTORE_META, state)
		change_scene_to_file(Campaign.scene_path(state))
		await scene_changed
		var area = current_scene
		var species := {}
		for monster in area.enemies:
			species[monster.species] = true
			monster.set_physics_process(false)
		check(species.size() == [6, 7, 8][region], "region %d spawns its intended distinct species" % region)
		for id in species:
			if id != "seal_keeper":
				ordinary[id] = true
		area.hunter.set_physics_process(false)

		for chest in Armory.CHESTS[region]:
			area.hunter.position = Vector2(chest[1], chest[2])
			area._interact()
			check(area.owned_equipment.has(chest[0]), "interacting with chest grants " + chest[0])
		if region == Campaign.Region.TEMPLE:
			area.hunter.position = area.landscape.shrine.position
			area._interact()
			area._set_camp_open(false)
			area.hunter.set_physics_process(false)
			area.hunter.position = area.landscape.cache.position
			area._interact()
			check(area.owned_equipment.has("ember_staff") and area.owned_equipment.has("moss_vest"), "temple overlook grants base staff and vest")

		# Arrange death or windup state to check reward wiring. The route smoke
		# uses actual weapon inputs for required campaign encounters.
		for monster in area.enemies.duplicate():
			var id: String = monster.species
			if id in ["treant", "thorn_archer", "shield_heron"]:
				monster.windup = 0.5
				monster.receive_hit(1, true, true)
			if Bestiary.DROPS.has(id) or id in ["spider", "bell_moth"]:
				monster.state = monster.State.RECOVER
				monster.receive_hit(200, false)
		for drop in area.drops.duplicate():
			drop.spawn = area.elapsed - 1.0
			area.hunter.position = drop.at + Vector2(0, 25)
			area._collect_drops()
		if region == Campaign.Region.TEMPLE:
			area._forge_fang_dagger()
			check(area.owned_equipment.has("fang_dagger") and area.owned_equipment.has("root_blade"),
				"forge and disarm grant two distinct weapons")
		state = area._checkpoint_state()
		if region == Campaign.Region.COURT:
			var armor := 0
			for id: String in area.owned_equipment:
				var item := Equipment.item(id)
				check(Equipment.icon(id) != null, "inventory icon is available for " + id)
				if item[1] != "武器":
					armor += 1
			check(ordinary.size() == 20 and species.has("seal_keeper"), "campaign has 20 ordinary species plus its final boss")
			check(armor == 20 and area.hunter.unlocked_weapons.size() == 10, "all 20 wearables and 10 weapons are obtainable")
			for weapon: String in area.hunter.unlocked_weapons:
				area.hunter.select_weapon(weapon)
				check(area.hunter.selected_weapon() == weapon and area.hunter.weapon_damage(weapon) > 0
					and Equipment.icon(weapon) != null, "equippable weapon has damage and art: " + weapon)
			check(Save.write(area._checkpoint_state()) == OK, "catalog loadout writes to disk")
		await process_frame
	quit(1 if failures else 0)


func check(passed: bool, title: String) -> void:
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", title])
