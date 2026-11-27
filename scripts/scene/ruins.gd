extends Node2D

const Door := preload("res://assets/environment/common/props/doors/interactive_door.gd")
const Hunter := preload("res://scripts/character/ruin_hunter.gd")
const Monster := preload("res://scripts/character/ruin_monster.gd")
const EnemyEffects := preload("res://scripts/effects/ruin_enemy_effects.gd")
const HitEffects := preload("res://scripts/effects/ruin_hit_effects.gd")
const Landscape := preload("res://scripts/scene/ruin_landscape.gd")
const CampSave := preload("res://scripts/game/camp_save.gd")
const Preferences := preload("res://scripts/game/game_preferences.gd")
const HunterAnimation := preload("res://scripts/character/hunter_animation.gd")
const WeaponArt := preload("res://scripts/character/hunter_weapon_art.gd")
const EquipmentTheme := preload("res://scripts/ui/equipment_theme.gd")
const Equipment := preload("res://scripts/game/ruin_equipment.gd")
const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")
const Progression := preload("res://scripts/game/ruin_progression.gd")
const Armory := preload("res://scripts/game/ruin_armory.gd")
const Campaign := preload("res://scripts/game/campaign.gd")
const FloorVisibility := preload("res://scripts/scene/ruin_floor_visibility.gd")
const NpcTileMap := preload("res://scripts/scene/npc_tile_map.gd")
const NPC_DIALOGUE_BALLOON := preload("res://scenes/ui/npc_dialogue_balloon.tscn")
const NPC_DIALOGUE := preload("res://data/dialogue/villagers.dialogue")
const NPC_GIFT := "stonegrip_gloves"
const NPC_SHOP_ITEM := "scaleveil_hood"
const NPC_SHOP_PRICE := 8
const LETTER_REWARD := 8
enum LetterQuest { AVAILABLE, CARRYING, DELIVERED }
const SOFT_LIGHT := preload("res://assets/environment/common/props/soft_light.tres")
static var stage_rules := Campaign.Config.read("campaign/stage_rules")
static var interaction: Dictionary = stage_rules.interaction
static var reward_rules := Campaign.Config.read("campaign/rewards")
var presentation: Dictionary
static var START := Campaign.Config.vector(Campaign.settings.fallback_spawn)
static var STAGE_WIDTH: int = Campaign.settings.stage_width
const DROP_ATLAS := preload("res://assets/items/misc/world_drops.png")
const DROP_ATLAS_CELL := 40
const DROP_SPRITES := {"soul_currency": 0, "material": 1, "lizard": 2, "spider": 3, "fang_material": 4}
const DROP_COLORS := {
	"material": Color("#eac18c"), "lizard": Color("#a4f2d0"),
	"spider": Color("#ed9e96"), "blade": Color("#ffda84"), "soul_currency": Color("#8de7fb"),
	"fang_material": Color("#eac18c"),
}
const PICKUP_DURATION := 1.3
const PICKUP_FONT_SIZE := 19

static var lantern_icon := load(Bestiary.loot.lantern.icon_texture) as Texture2D

var hunter: Hunter
var hit_effects: HitEffects
@onready var landscape: Landscape = $Landscape
var camera: Camera2D
@onready var background: Sprite2D = $Backdrop/Temple
@onready var backdrop_origin := background.position
@onready var backdrop_scale := background.scale
var enemies: Array[Monster] = []
var drops: Array[Dictionary] = []
var pickup_feedback: Array[Dictionary] = []
var arrows: Array[Dictionary] = []
var enemy_projectile_layer: Node2D
var glyphs: Array[Dictionary] = []
var fang_target: Monster
var fang_hits := 0
var collected_souls: Array[String] = []
var soul_balance := 0
var loot_rng := RandomNumberGenerator.new()
var loot_catalog: Array[String]
var materials := 0
var fangs := 0
var forge_fang: Button
var owned_equipment: Array[String] = []
var inventory: Array[Dictionary] = []
var obtained_equipment: Dictionary = {}
var opened_treasure: Dictionary = {}
var armor_equipped: Dictionary = {}
var preferred_weapons: Dictionary = {}
var next_item_uid := 1
@export_enum("Temple", "Flooded Corridor", "Buried Court", "Volcanic Caldera") var region := 0
@export_range(0, 5) var stage := 0

var guardian_felled := false
var boss: Monster
var boss_felled := false
var boss_panel: PanelContainer
var boss_health: ProgressBar
var boss_caption: Label
var unclaimed_blade_rank := 1
var unclaimed_blade_x := -1.0
var lantern_found := false
var keeper_felled := false
var cache_flags: Dictionary = {}
var transitioning := false
var end_title: Label
var end_story: Label
var end_prompt: Label
var completed := false
var restarting := false
var notice_left := 0.0
var elapsed := 0.0
var rng := RandomNumberGenerator.new()

var health_label: Label
var level_label: Label
var health_hearts := preload("res://scripts/ui/ruin_health_hearts.gd").new()
var weapon_status: Label
var soul_status: Label
var spirit_status: Label
var mana_status: Label
var status_flags: Label
var objective_label: Label
var prompt_label: Label
var notice_label: Label
var end_screen: CenterContainer
var camp_menu: CenterContainer
var camp_closed_frame := -1
@onready var npc_layer := get_node_or_null("Landscape/NPC") as NpcTileMap
var npc_balloon: Node
var npc_gift_claimed := false
var letter_quest := LetterQuest.AVAILABLE
var npc_feedback := ""
var camp_stock: Label
var camp_rest: Button
var camp_knife: Button
var camp_bow: Button
var camp_level_up: Button
var camp_rank_items: ItemList
var camp_selected_item: Label
var camp_leave: Button
var camp_save_exit: Button
var camp_rank_up: Button
var camp_salvage: Button
var pause_menu: CenterContainer
var pause_volume: HSlider
var pause_fullscreen: CheckButton
var gear_menu: CenterContainer
var gear_portrait: TextureRect
var gear_portrait_pose: Node2D
var gear_portrait_base: AtlasTexture
const GEAR_SLOT_ORDER := ["武器", "頭部", "身體", "手部", "腿部"]
const STAT_RISE := Color("#ff9890")
const STAT_FALL := Color("#85dba2")
var gear_stat_targets: Dictionary[String, Label] = {}
var gear_stat_values: Dictionary[String, Label] = {}
var gear_list: ItemList
var gear_slot_images: Dictionary = {}
var gear_name: Label
var gear_slot: Label
var gear_detail_scroll: ScrollContainer
var gear_values: Label
var gear_armor: Label
var gear_detail: Label
var gear_apply: Button
var gear_ids: Array[String] = []
var gear_uids: Array[int] = []
var bag_count: Label
var destroy_item: Button
var destroy_dialog: ConfirmationDialog
var pending_destroy_uid := 0
var font: SystemFont


func _ready() -> void:
	rng.randomize()
	loot_rng.randomize()
	loot_catalog = Equipment.catalog_ids()
	var level_width := STAGE_WIDTH if stage > 0 else int(Campaign.settings.entry_width)
	presentation = Campaign.settings.presentation.duplicate()
	presentation.merge(Campaign.regions[region].get("presentation", {}), true)
	landscape.brazier_spacing = presentation.brazier_spacing
	landscape.brazier_min_gap = presentation.brazier_min_gap
	landscape.initialize_props(level_width)
	_resize_backdrop()
	get_viewport().size_changed.connect(_resize_backdrop)

	hunter = Hunter.new()
	hunter.name = "Hunter"
	hunter.position = _camp_start()
	hunter.attacked.connect(_attack)
	hunter.cast.connect(_cast)
	hunter.damaged.connect(_on_hunter_damaged)
	hunter.defeated.connect(_on_hunter_defeated)
	add_child(hunter)
	_set_up_lighting()
	for id: String in Equipment.STARTING_WEAPONS:
		_grant_equipment(id)
	var listener := AudioListener2D.new()
	hunter.add_child(listener)
	listener.make_current()
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = level_width
	camera.limit_top = presentation.stage_camera_top if stage > 0 else presentation.entry_camera_top
	camera.limit_bottom = presentation.camera_bottom
	camera.position.y = presentation.stage_camera_y if stage > 0 else presentation.entry_camera_y
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = presentation.camera_smoothing
	hunter.add_child(camera)
	camera.reset_smoothing()
	if stage > 0 and stage < Campaign.BOSS_STAGE:
		var terrain: TileMapLayer = $Landscape/Terrain
		var ground_y := to_global(Vector2(0, Landscape.FLOOR_Y)).y
		var floor_visibility := FloorVisibility.new(terrain, hunter, level_width, ground_y)
		floor_visibility.name = "FloorVisibility"
		add_child(floor_visibility)
	hit_effects = HitEffects.new()
	hit_effects.camera = camera
	add_child(hit_effects)
	enemy_projectile_layer = Node2D.new()
	enemy_projectile_layer.z_index = 2
	enemy_projectile_layer.draw.connect(_draw_enemy_projectiles)
	add_child(enemy_projectile_layer)
	if get_tree().has_meta(CampSave.RESTORE_META):
		_restore_camp(get_tree().get_meta(CampSave.RESTORE_META))
		get_tree().remove_meta(CampSave.RESTORE_META)
	_sync_region_gate()
	_spawn_enemies()
	_play_level_music()
	_build_hud()
	if stage > 0:
		return
	match region:
		Campaign.Region.TEMPLE:
			_notice("前世的記憶停在墜落那一刻。神殿深處也許有回家的線索。", 5.0)
		Campaign.Region.CORRIDOR:
			_notice("暗水道的石閘需要光。留意石蟹舉起的提燈。", 5.0)
		Campaign.Region.COURT:
			_notice("沿王座外階走到主祭壇，找到古門封印者。", 5.0)


func _set_up_lighting() -> void:
	var ambient := CanvasModulate.new()
	ambient.name = "AmbientLight"
	var rgb: Array = presentation.ambient_rgb
	ambient.color = Color(rgb[0], rgb[1], rgb[2])
	add_child(ambient)
	# The parallax backdrop draws on its own canvas, outside the world lighting.
	background.self_modulate = ambient.color

	var nearby_light := PointLight2D.new()
	nearby_light.name = "NearbyLight"
	nearby_light.position.y = -24.0
	nearby_light.color = Color(1.0, 0.93, 0.80)
	nearby_light.energy = 0.9
	nearby_light.texture = SOFT_LIGHT
	nearby_light.texture_scale = 1.35
	nearby_light.shadow_enabled = true
	hunter.add_child(nearby_light)


func _process(delta: float) -> void:
	elapsed += delta
	while not pickup_feedback.is_empty() and elapsed - float(pickup_feedback.front().spawn) >= PICKUP_DURATION:
		pickup_feedback.pop_front()
	background.position.x = backdrop_origin.x - clampf((hunter.position.x - 950.0) * 0.050, -95, 95)
	notice_left = maxf(0.0, notice_left - delta)
	notice_label.visible = notice_left > 0 and not completed
	if not completed:
		_update_door_sight()
		_update_hud()
		var door := _find_door()
		var npc := _near_npc(door)
		if npc != null:
			prompt_label.text = "E　交談　%s" % npc.get_custom_data("npc_name")
		elif door != null:
			_update_door_prompt(door)
		if is_instance_valid(npc_balloon):
			prompt_label.text = ""
	enemy_projectile_layer.queue_redraw()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if completed or transitioning or restarting or camp_menu.visible or gear_menu.visible or pause_menu.visible or is_instance_valid(npc_balloon):
		return
	if hunter.position.y > 790:
		_on_hunter_defeated()
		return
	hunter.shallow_water = stage == 0 and region == Campaign.Region.CORRIDOR and hunter.position.y > 522.0 and hunter.position.x > 1580 and hunter.position.x < 2220
	_update_arrows(delta)
	_update_glyphs(delta)
	_collect_drops()
	if Input.is_action_just_pressed("hunt_equip"):
		_equip_next_soul()
	if Input.is_action_just_pressed("hunt_interact") and Engine.get_physics_frames() > camp_closed_frame:
		_interact()


func _input(event: InputEvent) -> void:
	if is_instance_valid(npc_balloon) or destroy_dialog.visible:
		return
	if gear_menu.visible and event is InputEventKey and event.pressed:
		var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if key == KEY_E or key == KEY_D:
			get_viewport().set_input_as_handled()
			if not event.echo:
				if key == KEY_E and not gear_apply.disabled:
					_apply_gear()
				elif key == KEY_D and not destroy_item.disabled:
					_ask_destroy_item()
			return
	if not completed and not restarting and not camp_menu.visible and not pause_menu.visible:
		if event.is_action_pressed("hunt_gear") or (gear_menu.visible and event.is_action_pressed("ui_cancel")):
			_set_gear_open(not gear_menu.visible)
			get_viewport().set_input_as_handled()
			return
	if camp_menu.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("hunt_interact")):
		_set_camp_open(false)
		get_viewport().set_input_as_handled()
		return
	if not completed and not restarting and event.is_action_pressed("ui_cancel"):
		_set_pause_open(not pause_menu.visible)
		get_viewport().set_input_as_handled()
		return
	if completed and event.is_action_pressed("hunt_interact"):
		# A scene change immediately detaches this node from its viewport.
		get_viewport().set_input_as_handled()
		if stage > 0 or region == Campaign.Region.COURT:
			get_tree().change_scene_to_file(Campaign.TITLE_SCENE)
		else:
			_queue_region(region + 1)


func _spawn_enemies() -> void:
	var monster_layer: TileMapLayer = $Landscape/Monster
	monster_layer.hide()
	if stage == Campaign.BOSS_STAGE and boss_felled:
		return
	# Scene tiles are normally instantiated at the end of the frame.
	monster_layer.update_internals()
	for marker in monster_layer.get_children(true):
		var species: String = marker.get_meta("monster_species", "")
		if not Bestiary.creatures.has(species):
			continue
		var loot: Dictionary = Bestiary.loot.monsters.get(species, {})
		var defeat_flag: String = loot.get("defeat_flag", "")
		if stage == 0 and not defeat_flag.is_empty() and bool(get(defeat_flag)):
			continue
		var spawn := to_local(marker.global_position)
		var cell := monster_layer.local_to_map(monster_layer.to_local(marker.global_position))
		_add_monster(species, spawn.x, spawn.y, Bestiary.tile_tier(monster_layer.get_cell_source_id(cell)))


func _add_monster(species: String, x: float, y: float = Landscape.FLOOR_Y, tier: int = 0) -> void:
	var monster := Monster.new()
	monster.configure(species, Vector2(x, y), hunter, tier)
	var combat: Dictionary = monster.design.get("combat", {})
	var unarmed_if: String = combat.get("unarmed_if", "")
	if not unarmed_if.is_empty() and bool(get(unarmed_if)):
		monster.armed = false
	if stage == Campaign.BOSS_STAGE:
		var profile: Dictionary = Campaign.regions[region].boss
		monster.promote_to_boss(profile.size, profile.level_bonus, profile.health_multiplier)
		boss = monster
		boss.phase_changed.connect(_play_level_music)
	monster.felled.connect(_on_monster_felled)
	monster.disarmed.connect(_on_monster_disarmed)
	monster.launched.connect(_launch_enemy_projectile)
	enemies.append(monster)
	add_child(monster)


func _attack(origin: Vector2, direction: float, ranged: bool, damage: int, weapon: String) -> void:
	if ranged:
		hit_effects.release_weapon(weapon)
		var bow: Dictionary = Armory.WEAPONS.get(weapon, Equipment.ITEMS.hunter_bow)
		var shot: Dictionary = Armory.catalog.projectiles[bow.projectile]
		arrows.append({"at": origin, "direction": direction, "damage": damage, "left": shot.lifetime,
			"speed": shot.speed, "height": shot.height,
			"weapon": weapon, "pierce": int(bow.get("pierce", 0)), "hit_ids": []})
		return
	var reach: float = Armory.WEAPONS[weapon].reach if Armory.WEAPONS.has(weapon) else Armory.catalog.items.hunter_knife.reach
	var is_short_blade := weapon in Hunter.SHORT_BLADES
	var blade_step := maxi(1, hunter.blade_step) if is_short_blade else 3
	var is_melee := is_short_blade or weapon in ["root_blade", "tide_hammer", "gate_halberd", "sluice_spear"]
	if is_melee:
		hit_effects.swing(origin, direction, reach, blade_step, weapon)
	else:
		hit_effects.release_weapon(weapon)
	var melee_box: Dictionary = Armory.catalog.melee_hitbox
	var hitbox := Rect2(origin.x if direction > 0 else origin.x - reach,
		origin.y + float(melee_box.top_offset), reach, melee_box.height)
	var candidates := enemies.duplicate()
	candidates.sort_custom(func(a, b): return absf(a.position.x - origin.x) < absf(b.position.x - origin.x))
	var hit_count := 0
	for monster: Monster in candidates:
		var weapon_hit := monster.armed and monster.windup > 0 and hitbox.intersects(monster.weapon_hitbox())
		var bounds := monster.weapon_hitbox() if weapon_hit else monster.body_hitbox()
		if not hitbox.intersects(bounds):
			continue
		var applied := damage
		if weapon == "fang_dagger":
			if not is_instance_valid(fang_target) or fang_target != monster:
				fang_target = monster
				fang_hits = 0
			fang_hits += 1
			applied += int(fang_hits % int(Armory.WEAPONS.fang_dagger.combo_hits) == 0)
		else:
			fang_hits = 0
		_hit_monster(monster, applied, weapon_hit, hitbox.intersection(bounds).get_center(),
			direction, false, weapon, blade_step)
		hit_count += 1
		if hit_count >= (int(Armory.WEAPONS.gate_halberd.max_targets) if weapon == "gate_halberd" else 1):
			break


func _cast(origin: Vector2, direction: float, weapon: String) -> void:
	hit_effects.release_weapon(weapon)
	if weapon == "scribe_staff":
		var glyph: Dictionary = Armory.WEAPONS.scribe_staff.glyph
		var x := clampf(origin.x + direction * float(glyph.forward_distance), glyph.min_x, glyph.max_x)
		var vertical_ray := PhysicsRayQueryParameters2D.create(Vector2(x, origin.y), Vector2(x, origin.y + float(glyph.ground_probe)), 1)
		var ground := get_world_2d().direct_space_state.intersect_ray(vertical_ray)
		if not ground.is_empty():
			glyphs.append({"at": ground.position, "left": glyph.delay, "damage": hunter.weapon_damage(weapon), "direction": direction})
		return
	# Sweep from just in front of the hunter on the first tick so the staff
	# cannot launch a fireball through a wall or enemy between the body and tip.
	var shot: Dictionary = Armory.catalog.projectiles[Equipment.ITEMS.ember_staff.projectile]
	var cast_start := Vector2(hunter.position.x + direction * float(shot.cast_start_offset), origin.y)
	arrows.append({"at": origin, "direction": direction, "damage": hunter.weapon_damage(weapon), "left": shot.lifetime,
		"speed": shot.speed, "height": shot.height,
		"spell": true, "weapon": weapon, "hit_ids": [], "cast_start": cast_start})


func _launch_enemy_projectile(origin: Vector2, direction: float, attack: Dictionary) -> void:
	var speed := float(attack.speed)
	arrows.append({"at": origin, "direction": direction, "damage": int(attack.damage),
		"left": (float(attack.trigger_range) + float(Bestiary.rules.combat.projectile_range_padding)) / speed, "hostile": attack.kind,
		"speed": speed, "radius": float(attack.extent), "element": attack.element, "origin_x": origin.x})
	var tint := EnemyEffects.element_color(attack.element)
	hit_effects.play_event("enemy_launch", origin, direction, tint)


func _update_glyphs(delta: float) -> void:
	for index in range(glyphs.size() - 1, -1, -1):
		var glyph := glyphs[index]
		glyph.left -= delta
		if glyph.left > 0:
			continue
		var area := Bestiary.rectangle(Armory.WEAPONS.scribe_staff.glyph.hitbox)
		area.position += Vector2(glyph.at)
		for enemy: Monster in enemies.duplicate():
			if enemy.body_hitbox().intersects(area):
				_hit_monster(enemy, glyph.damage, false, enemy.position - Vector2(0, 24), glyph.direction, true, "scribe_staff")
		glyphs.remove_at(index)


func _update_arrows(delta: float) -> void:
	for index in range(arrows.size() - 1, -1, -1):
		var arrow := arrows[index]
		var from: Vector2 = arrow.get("cast_start", arrow.at)
		arrow.erase("cast_start")
		var spell: bool = arrow.get("spell", false)
		var hostile: String = arrow.get("hostile", "")
		var velocity := Vector2(arrow.direction * arrow.speed, 0)
		var to: Vector2 = arrow.at + velocity * delta
		var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
		var wall := get_world_2d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty():
			to = wall.position
		var hitbox := Rect2()
		var hit := false
		if not hostile.is_empty():
			var height := Hunter.CROUCH_HEIGHT if hunter.crouching else Hunter.STANDING_HEIGHT
			var radius: float = arrow.radius
			hitbox = Rect2(from, Vector2.ZERO).expand(to).grow(radius)
			hit = hitbox.intersects(Rect2(hunter.position - Vector2(12, height), Vector2(24, height)))
			if hit:
				var sight := PhysicsRayQueryParameters2D.create(from, Vector2(hunter.position.x, from.y), 1)
				hit = get_world_2d().direct_space_state.intersect_ray(sight).is_empty()
				if hit:
					hunter.hurt(hunter.position.x - arrow.direction, arrow.damage, hostile)
		else:
			var height: float = arrow.height
			hitbox = Rect2(minf(from.x, to.x), from.y - height * 0.5, absf(to.x - from.x), height)
			var target_id := _arrow_hits_monster(hitbox, arrow)
			hit = target_id != 0
			if hit and int(arrow.get("pierce", 0)) > 0:
				arrow.pierce -= 1
				arrow.hit_ids.append(target_id)
				hit = false
		arrow.left -= delta
		if hit or not wall.is_empty() or arrow.left <= 0:
			if spell and not hit and not wall.is_empty():
				hit_effects.fire_impact(to)
			if not hostile.is_empty() and (hit or not wall.is_empty()):
				var point := to
				if hit:
					point.x = clampf(hunter.position.x, minf(from.x, to.x), maxf(from.x, to.x))
				var tint := EnemyEffects.element_color(arrow.element)
				hit_effects.play_event("enemy_impact", point, arrow.direction, tint, arrow.radius)
			arrows.remove_at(index)
		else:
			arrow.at = to


func _arrow_hits_monster(hitbox: Rect2, arrow: Dictionary) -> int:
	var direction: float = arrow.direction
	var nearest: Monster
	var nearest_x := INF
	var impact_point := Vector2.ZERO
	var hits_weapon := false
	for monster: Monster in enemies:
		if monster.get_instance_id() in arrow.hit_ids:
			continue
		var weapon_hit := monster.armed and monster.windup > 0 and hitbox.intersects(monster.weapon_hitbox())
		var bounds := monster.weapon_hitbox() if weapon_hit else monster.arrow_hitbox(hitbox.get_center().y)
		if arrow.get("spell", false) and not weapon_hit:
			bounds = monster.body_hitbox()
		var overlap := hitbox.intersection(bounds)
		if not overlap.has_area():
			continue
		var hit_x := overlap.position.x if direction > 0 else overlap.end.x
		if hit_x * direction < nearest_x:
			nearest = monster
			nearest_x = hit_x * direction
			impact_point = Vector2(hit_x, hitbox.get_center().y)
			hits_weapon = weapon_hit
	if nearest == null:
		return 0
	_hit_monster(nearest, arrow.damage, hits_weapon, impact_point, direction, true, arrow.weapon)
	return nearest.get_instance_id()


func _hit_monster(monster: Monster, damage: int, weapon_hit: bool, point: Vector2, direction: float,
		projectile: bool = false, weapon: String = "", blade_step: int = 0) -> void:
	var result := monster.receive_hit(damage, weapon_hit, projectile, weapon, direction)
	if not projectile and not monster.is_queued_for_deletion():
		var push: Dictionary = monster.combat.get("recovery_push", {})
		if not push.is_empty() and hunter.gear.get("手部") == push.gear and monster.recovery > 0.0:
			monster.apply_equipment_push(direction, float(push.force))
		elif hunter.gear.get("手部") == "hardroot_bracers" and not hunter.is_on_floor():
			monster.apply_equipment_push(direction, Armory.WEAR.hardroot_bracers.air_push)
	if result == Monster.HitResult.BLOCKED:
		hit_effects.guard_impact(point, direction)
		return
	if weapon == "ember_staff":
		hit_effects.fire_impact(point)
		return
	var is_short_blade := weapon in Hunter.SHORT_BLADES
	var effective_step := blade_step if is_short_blade else (3 if weapon in ["root_blade", "tide_hammer", "gate_halberd", "sluice_spear"] else 0)
	if effective_step == 0:
		hit_effects.impact(point, direction, weapon_hit)
		return
	hit_effects.blade_impact(point, direction, effective_step, result == Monster.HitResult.DISARMED)
	hunter.blade_recoil = -direction * (52.0 if effective_step == 3 else 34.0)
	if not monster.is_queued_for_deletion():
		monster.flash_blade_hit()


func _on_monster_felled(monster: Monster) -> void:
	enemies.erase(monster)
	var defeated_boss := monster == boss
	if defeated_boss:
		boss_felled = true
		boss = null
		_sync_region_gate()
		_play_level_music()
	var x := monster.position.x
	var y := monster.position.y
	var rules: Dictionary = Bestiary.loot.monsters.get(monster.species, {})
	for rule in rules.get("before_defeat", []):
		_apply_drop_rule(rule, x, 1.0, y, monster.tier)
	var reward := loot_rng.randi_range(int(monster.soul_reward[0]), int(monster.soul_reward[1]))
	var soul_currency: Dictionary = Bestiary.loot.soul_currency
	_drop(soul_currency.item, x + float(soul_currency.offset), reward, 1, false, y)
	var rank := Progression.drop_rank(loot_rng.randf(), monster.tier)
	if rank > 0:
		var item := loot_catalog[loot_rng.randi_range(0, loot_catalog.size() - 1)]
		_drop(item, x + float(Bestiary.loot.random_equipment.offset), 1, rank, true, y)
	for rule in rules.get("defeat", []):
		_apply_drop_rule(rule, x, 1.0, y, monster.tier)
	var flag: String = rules.get("defeat_flag", "")
	if not flag.is_empty():
		set(flag, true)
		_sync_region_gate()
	var materials_override = rules.get("materials", {})
	if materials_override != null:
		var material_rule: Dictionary = Bestiary.loot.material_default.duplicate()
		material_rule.merge(materials_override, true)
		_apply_drop_rule(material_rule, x, 1.0, y)
	var notice: String = rules.get("defeat_notice", "")
	if not notice.is_empty():
		_notice(notice, float(rules.get("defeat_notice_seconds", 4.0)))
	if defeated_boss:
		_notice("首領已倒下，出口開啟。", 4.0)


func _apply_drop_rule(rule: Dictionary, x: float, facing: float = 1.0, source_y := NAN, tier := 1) -> bool:
	var chance: float = rule.get("chance", 1.0)
	if chance < 1.0 and rng.randf() >= chance:
		return false
	var item: String = rule.item
	var at := x + float(rule.get("offset", 0.0)) * facing
	if owned_equipment.has(rule.get("unless_owned", "")):
		return false
	match rule.get("policy", "always"):
		"once_equipment":
			if obtained_equipment.has(item) or _has_drop(item):
				return false
		"once_soul":
			if collected_souls.has(item) or (rule.get("check_pending", false) and _has_drop(item)):
				return false
		"lantern":
			return _drop_corridor_lantern(at, source_y)
		"guardian_blade":
			if hunter.stolen_blade or _has_drop(item):
				return false
			unclaimed_blade_x = at
			unclaimed_blade_rank = tier
	var rank := tier if item == Bestiary.loot.guardian_blade.item or not Equipment.item(item).is_empty() else 1
	_drop(item, at, int(rule.get("amount", 1)), rank, false, source_y)
	return true


func _drop_corridor_lantern(x: float, source_y := NAN) -> bool:
	var rules: Dictionary = Bestiary.loot.lantern
	if Campaign.IDS[region] != rules.region or bool(get(rules.progress_flag)) or _has_drop(rules.item):
		return false
	for gate in landscape.light_gates:
		x = minf(x, to_local(gate.global_position).x + float(rules.gate_offset))
	_drop(rules.item, x, 1, 1, false, source_y)
	_notice(rules.notice, float(rules.notice_seconds))
	return true


func _on_monster_disarmed(monster: Monster) -> void:
	var rules: Dictionary = Bestiary.loot.monsters.get(monster.species, {})
	var notice: String = rules.get("disarm_notice", "")
	var disarm_rules: Array = rules.get("disarm", [])
	for rule in disarm_rules:
		if _apply_drop_rule(rule, monster.position.x, monster.facing, monster.position.y, monster.tier) and not notice.is_empty():
			if rule.get("policy", "") == "guardian_blade":
				var weapon: String = Bestiary.loot.guardian_blade.grants
				_notice(notice % _ranked_gear_name(weapon, monster.tier), float(rules.get("disarm_notice_seconds", 3.0)))
			else:
				_notice(notice, float(rules.get("disarm_notice_seconds", 3.0)))
	if disarm_rules.is_empty() and not notice.is_empty():
		_notice(notice, float(rules.get("disarm_notice_seconds", 3.0)))


func _has_drop(kind: String) -> bool:
	for drop: Dictionary in drops:
		if drop.kind == kind:
			return true
	return false


func _drop(kind: String, x: float, amount: int = 1, rank: int = 1, rolled: bool = false, source_y := NAN) -> void:
	var bounds: Dictionary = Bestiary.loot.drop_bounds
	var left: float = bounds.region_x_min.get(Campaign.IDS[region], bounds.default_x_min)
	var at := Vector2(clampf(x, left, float(bounds.x_max)), Landscape.FLOOR_Y + float(bounds.y_offset))
	if stage > 0:
		at.x = clampf(x, 40, STAGE_WIDTH - 40)
		if not is_nan(source_y):
			var start := to_global(Vector2(at.x, source_y - 8.0))
			var end := to_global(Vector2(at.x, Landscape.FLOOR_Y + 20.0))
			var query := PhysicsRayQueryParameters2D.create(start, end, 1)
			var floor_hit := get_world_2d().direct_space_state.intersect_ray(query)
			if not floor_hit.is_empty():
				at.y = to_local(floor_hit.position).y + float(bounds.y_offset)
	drops.append({"kind": kind, "at": at, "amount": amount, "spawn": elapsed, "rank": rank, "rolled": rolled})


func _collect_drops() -> void:
	for index in range(drops.size() - 1, -1, -1):
		var drop := drops[index]
		if elapsed - drop.spawn < 0.22 or (hunter.position - Vector2(0, 25)).distance_to(drop.at) > 43:
			continue
		if _bag_full() and (drop.kind == "blade" or not Equipment.item(drop.kind).is_empty()):
			_warn_full_bag()
			continue
		drops.remove_at(index)
		match drop.kind:
			"soul_currency":
				soul_balance += int(drop.amount)
				_show_pickup("魂 +%d" % int(drop.amount), DROP_COLORS["soul_currency"])
			"material":
				materials += int(drop.amount)
				_show_pickup("素材 +%d" % int(drop.amount), DROP_COLORS["material"])
			"blade":
				hunter.stolen_blade = true
				unclaimed_blade_x = -1.0
				var weapon: String = Bestiary.loot.guardian_blade.grants
				var rank := int(drop.rank)
				var item_name := _ranked_gear_name(weapon, rank)
				if _grant_equipment(weapon, rank):
					_show_pickup(item_name)
				_notice("取得%s。按 I 換裝。" % item_name, 3.0)
			"fang_material":
				fangs += 1
				_show_pickup("蛛牙 +1", DROP_COLORS["material"])
				_notice("取得蛛牙。回營火可製作蛛牙短刃。", 3.0)
			"lantern":
				lantern_found = true
				_sync_region_gate()
				_show_pickup("潮火提燈")
				_notice("取得潮火提燈，暗水道已照亮。", 4.0)
			_:
				if not Bestiary.soul(drop.kind).is_empty():
					var soul_name := "%s之魂" % Bestiary.soul(drop.kind).name
					if not collected_souls.has(drop.kind):
						collected_souls.append(drop.kind)
						_show_pickup(soul_name, DROP_COLORS[drop.kind])
					_notice("拾得%s。按 F 裝備，按住 Shift 使用魂技。" % soul_name, 4.0)
				elif not Equipment.item(drop.kind).is_empty():
					var rank := int(drop.rank)
					if _grant_equipment(drop.kind, rank, drop.rolled):
						var item_name := _ranked_gear_name(drop.kind, rank)
						_show_pickup(item_name)
						_notice("取得%s。按 I 看裝備。" % item_name, 3.0)


func _show_pickup(text: String, color: Color = Color("#ffe0a1")) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PICKUP_FONT_SIZE).x
	pickup_feedback.append({"text": text, "width": width, "color": color, "spawn": elapsed})


func _equip_next_soul() -> void:
	if collected_souls.is_empty():
		_notice("目前沒有可裝備的靈魂。先狩獵滑翔蜥蜴，取得蜥翼之魂。", 2.8)
		return
	var slot := collected_souls.find(hunter.equipped_soul)
	hunter.equipped_soul = collected_souls[(slot + 1) % collected_souls.size()]
	var soul := Bestiary.soul(hunter.equipped_soul)
	_notice("已裝備%s。%s" % [soul.name, soul.hint], 3.0)


func _interact() -> void:
	if hunter.door_action:
		return
	var door := _find_door()
	var npc := _near_npc(door)
	if npc != null:
		_open_npc_dialogue(npc.get_custom_data("dialogue_cue"))
		return
	if door != null:
		_interact_with_door(door)
		return
	var chest := _near_equipment_chest()
	if chest != null:
		if _bag_full():
			_warn_full_bag()
			return
		var random_loot := chest.loot_rank > 0
		var loot := chest.equipment_id
		var rank := maxi(1, chest.loot_rank)
		if random_loot:
			loot = loot_catalog[loot_rng.randi_range(0, loot_catalog.size() - 1)]
		if _grant_equipment(loot, rank, random_loot):
			if random_loot:
				opened_treasure[_treasure_key(chest)] = true
				chest.set_opened(true)
			_notice("寶箱內有%s。按 I 看裝備。" % _ranked_gear_name(loot, rank), 4.0)
	elif _near_prop(landscape.campfires):
		for id: String in reward_rules.camp_equipment:
			if not obtained_equipment.has(id):
				_grant_equipment(id)
		_set_camp_open(true)
	elif _near_legacy_exit():
		_use_exit()
	elif _near_cache() and not landscape.cache_open:
		var configured: Array = reward_rules.cache_equipment_by_region.get(Campaign.IDS[region], [])
		var pending := configured.filter(func(id: String) -> bool: return not obtained_equipment.has(id))
		if not pending.is_empty() and inventory.size() + pending.size() > Progression.bag_capacity(hunter.level):
			_warn_full_bag()
			return
		landscape.cache_open = true
		var amount: int = reward_rules.cache_materials
		materials += amount
		var rewards := PackedStringArray()
		for id: String in pending:
			if _grant_equipment(id):
				rewards.append(_ranked_gear_name(id, 1))
		if not rewards.is_empty():
			_notice("取得%s和 %d 份素材。按 I 看裝備。" % ["、".join(rewards), amount], 4.0)
		else:
			_notice("從石匣取得 %d 份工坊素材。" % amount, 4.0)


func _near_npc(door: Door) -> TileData:
	if npc_layer == null or _near_prop(landscape.campfires) or _near_equipment_chest() != null:
		return null
	# Give NPCs beside a doorway a shorter reach so the door stays usable.
	var radius := 24.0 if door != null else NpcTileMap.TALK_RADIUS
	return npc_layer.nearest_to(hunter.global_position, radius)


func _open_npc_dialogue(cue: String) -> void:
	if hunter.health <= 0 or is_instance_valid(npc_balloon) or not NPC_DIALOGUE.cues.has(cue):
		return
	_set_world_locked(true)
	npc_balloon = Engine.get_singleton("DialogueManager").show_dialogue_balloon_scene(
		NPC_DIALOGUE_BALLOON, NPC_DIALOGUE, cue, [self])
	npc_balloon.tree_exited.connect(_close_npc_dialogue, CONNECT_ONE_SHOT)


func _close_npc_dialogue() -> void:
	npc_balloon = null
	if is_inside_tree() and is_instance_valid(hunter) and not (restarting or transitioning or completed):
		_set_world_locked(false)
		camp_closed_frame = Engine.get_physics_frames() + 1


func npc_claim_gift() -> void:
	if npc_gift_claimed:
		npc_feedback = "護手已經交給你了。路上小心。"
	elif _grant_equipment(NPC_GIFT, 1, true):
		npc_gift_claimed = true
		npc_feedback = "拿去吧。壓石手套已放進背包，按 I 可以查看。"
	else:
		npc_feedback = "你的背包滿了。騰出空間後再回來吧。"


func npc_buy_hood() -> void:
	if soul_balance < NPC_SHOP_PRICE:
		npc_feedback = "魂幣不夠。攢到 8 枚再來吧。"
	elif _grant_equipment(NPC_SHOP_ITEM, 1, true):
		soul_balance -= NPC_SHOP_PRICE
		npc_feedback = "成交。鱗紗兜帽已放進背包。"
	else:
		npc_feedback = "背包沒有空位。我先替你留著。"


func npc_accept_letter() -> void:
	match letter_quest:
		LetterQuest.AVAILABLE:
			letter_quest = LetterQuest.CARRYING
			npc_feedback = "信就交給你了。艾德會在這條路的東邊等。"
		LetterQuest.CARRYING:
			npc_feedback = "信在你手上喔，記得交給艾德。"
		LetterQuest.DELIVERED:
			npc_feedback = "艾德已經收到信了。謝謝你！"


func npc_deliver_letter() -> void:
	match letter_quest:
		LetterQuest.AVAILABLE:
			npc_feedback = "先去找皮普拿信吧。"
		LetterQuest.CARRYING:
			letter_quest = LetterQuest.DELIVERED
			soul_balance += LETTER_REWARD
			npc_feedback = "我收到信了。這 8 枚魂幣是你的跑腿費。"
		LetterQuest.DELIVERED:
			npc_feedback = "信已經放在書裡了。謝謝你跑這一趟。"


func npc_heal() -> void:
	var recovered := hunter.max_health() - hunter.health
	hunter.health = hunter.max_health()
	npc_feedback = "傷口包好了，恢復了 %d 點體力。" % recovered if recovered > 0 else "你的體力已經全滿了。"


func _find_door() -> Door:
	var nearest: Door
	var distance := INF
	for door: Door in get_tree().get_nodes_in_group("interactive_door"):
		if not is_ancestor_of(door) or not door.can_reach(hunter):
			continue
		var separation := hunter.global_position.distance_squared_to(door.global_position)
		if separation < distance:
			nearest = door
			distance = separation
	return nearest


func _update_door_sight() -> void:
	var eye := hunter.to_global(Vector2(0, -36))
	for door: Door in get_tree().get_nodes_in_group("interactive_door"):
		if is_ancestor_of(door):
			door.update_sight(eye)
	for sight: Door.DoorSight in get_tree().get_nodes_in_group("door_stop_sight"):
		if is_ancestor_of(sight):
			sight.project(eye)


func _update_door_prompt(door: Door) -> void:
	if door.motion != null:
		prompt_label.text = "%s移動中…" % door.door_name
	elif door.scene_exit and not _exit_unlocked():
		prompt_label.text = "%s已封鎖" % door.door_name
	elif door.scene_exit:
		prompt_label.text = "E　開門並前往下一關" if not door.opened else "E　前往下一關"
	else:
		prompt_label.text = ("E　關閉%s" if door.opened else "E　開啟%s") % door.door_name


func _doorway_clear(door: Door) -> bool:
	var slab := Rect2(door.global_position - Vector2(Door.HALF_WIDTH, Door.HEIGHT),
		Vector2(Door.HALF_WIDTH * 2.0, Door.HEIGHT))
	var hunter_bounds := hunter.collider.global_transform * hunter.collider.shape.get_rect()
	if slab.intersects(hunter_bounds):
		return false
	for monster: Monster in enemies:
		if monster.health > 0 and slab.intersects(global_transform * monster.body_hitbox()):
			return false
	return true


func _interact_with_door(door: Door) -> void:
	if door.motion != null or hunter.health <= 0 or hunter.attack_left > 0.0 or hunter.hurt_left > 0.0:
		return
	if door.scene_exit:
		if not _exit_unlocked() or door.opened:
			_use_exit()
			return
	var motion := door.toggle(hunter, _doorway_clear)
	if motion == null:
		_notice("門口有人，無法關門。", 1.5)
	elif door.scene_exit:
		motion.tween_callback(_leave_through_door.bind(door))


func _leave_through_door(door: Door) -> void:
	if (hunter.health > 0 and not restarting and not completed and door.can_reach(hunter)
			and not camp_menu.visible and not gear_menu.visible and not pause_menu.visible):
		_use_exit()


func _exit_unlocked() -> bool:
	if stage > 0:
		return landscape.portal_open
	match region:
		Campaign.Region.TEMPLE:
			return guardian_felled
		Campaign.Region.CORRIDOR:
			return lantern_found
		Campaign.Region.COURT:
			return keeper_felled
	return false


func _use_exit() -> void:
	if stage > 0:
		_advance_stage()
		return
	match region:
		Campaign.Region.TEMPLE:
			if guardian_felled:
				_finish()
			else:
				_notice("石門上的枝紋在發光。還有一名守門者活著。", 3.0)
		Campaign.Region.CORRIDOR:
			if lantern_found:
				_queue_region(Campaign.Region.COURT)
			else:
				_notice("先取得潮火提燈，才能照出出口。", 3.0)
		Campaign.Region.COURT:
			if keeper_felled:
				_finish()
				if CampSave.write(_checkpoint_state()) != OK:
					end_prompt.text = "E　返回開始頁面（進度未能保存）"
			else:
				_notice("主祭壇被封印者封鎖。", 3.0)


func _near_legacy_exit() -> bool:
	for portal in landscape.portals:
		if is_instance_valid(portal) and not portal is Door and _in_prop_range(portal):
			return true
	return false


func _in_prop_range(prop: Node2D) -> bool:
	var separation := hunter.global_position - prop.global_position
	return absf(separation.x) < interaction.prop_half_width and absf(separation.y) < interaction.prop_half_height


func _near_prop(props: Array[Node2D]) -> bool:
	for prop in props:
		if _in_prop_range(prop):
			return true
	return false


func _near_treasure() -> String:
	var chest := _near_equipment_chest()
	return chest.equipment_id if chest != null else ""


func _near_equipment_chest() -> Landscape.EquipmentChest:
	var nearest: Landscape.EquipmentChest
	var radius: float = interaction.chest_radius
	for chest in landscape.equipment_chests:
		var distance := hunter.global_position.distance_to(chest.global_position)
		if not chest.opened and distance < radius:
			nearest = chest
			radius = distance
	return nearest


func _treasure_key(chest: Landscape.EquipmentChest) -> String:
	var cell := Vector2i(landscape.to_local(chest.global_position))
	return "%d:%d:%d:%d" % [stage, region, cell.x, cell.y]


func _near_cache() -> bool:
	for cache in landscape.reliquaries:
		if hunter.global_position.distance_to(cache.global_position) < interaction.cache_radius:
			return true
	return false


func _on_hunter_damaged(source_x: float, damage: int, effect: String) -> void:
	var dir := signf(hunter.position.x - source_x)
	if dir == 0.0:
		dir = 1.0
	var heavy := damage >= 2 or effect in ["ram", "slam", "crush", "hammer", "shards", "heavy"]
	var hit_pt := hunter.position + Vector2(0, -28)
	hit_effects.play_event("hurt_heavy" if heavy else "hurt_light", hit_pt, dir)
	hit_effects._punctuate_hit(dir, heavy, 11.0 if heavy else 6.2)


func _on_hunter_defeated() -> void:
	if restarting:
		return
	restarting = true
	_retry.call_deferred()


func _retry() -> void:
	var lost := ceili(materials * 0.5)
	materials -= lost
	for monster: Monster in enemies:
		monster.queue_free()
	enemies.clear()
	boss = null
	arrows.clear()
	glyphs.clear()
	hit_effects.clear()
	# A disarmed guardian stays dead after victory. Keep its unclaimed weapon reachable.
	var blade: Dictionary = Bestiary.loot.guardian_blade
	drops = drops.filter(func(drop: Dictionary) -> bool: return bool(get(blade.defeat_flag)) and drop.kind == blade.item)
	hunter.respawn(_camp_start())
	camera.reset_smoothing()
	_spawn_enemies()
	_play_level_music()
	restarting = false
	_notice("在營火旁醒來。這次遺失了 %d 份素材。" % lost, 3.8)


func _finish() -> void:
	completed = true
	hunter.set_physics_process(false)
	for monster: Monster in enemies:
		monster.set_physics_process(false)
	end_screen.show()


func _camp_start() -> Vector2:
	if (stage == 0 and region == Campaign.Region.TEMPLE) or landscape.campfires.is_empty():
		return START
	return to_local(landscape.campfires[0].global_position) + Campaign.Config.vector(Campaign.settings.camp_spawn_offset)


func _sync_region_gate() -> void:
	if stage > 0:
		landscape.portal_open = stage != Campaign.BOSS_STAGE or boss_felled
		return
	match region:
		Campaign.Region.TEMPLE:
			landscape.portal_open = guardian_felled
		Campaign.Region.CORRIDOR:
			landscape.portal_open = lantern_found
			landscape.get_node("Darkness").visible = not lantern_found
			for gate in landscape.light_gates:
				gate.get_node("Bar").visible = not lantern_found
				gate.get_node("Collision").set_deferred("disabled", lantern_found)
		Campaign.Region.COURT:
			landscape.portal_open = keeper_felled


func _advance_stage() -> void:
	if not landscape.portal_open:
		_notice("擊倒首領後，出口才會開啟。", 3.0)
		return
	var destination := Campaign.next_stage(region, stage)
	if not destination.is_empty():
		_queue_region(destination.region, destination.stage)
	elif CampSave.write(_checkpoint_state()) == OK:
		_finish()
	else:
		_notice("無法保存通關進度，請重試。", 4.0)


func _queue_region(destination: int, next_stage := 0) -> void:
	if not transitioning:
		transitioning = true
		_change_region.call_deferred(destination, next_stage)


func _change_region(destination: int, next_stage := 0) -> void:
	var checkpoint := _checkpoint_state()
	checkpoint["region"] = destination
	checkpoint["stage"] = next_stage
	checkpoint.erase("boss_felled")
	var next := load(Campaign.scene_path(checkpoint)) as PackedScene
	if next == null or CampSave.write(checkpoint) != OK:
		transitioning = false
		_notice("無法保存下一關的進度，請重試。", 4.0)
		return
	get_tree().set_meta(CampSave.RESTORE_META, checkpoint)
	if get_tree().change_scene_to_packed(next) != OK:
		get_tree().remove_meta(CampSave.RESTORE_META)
		transitioning = false
		_notice("無法開啟下一關，請重試。", 4.0)


func _play_level_music() -> void:
	var music := get_node("/root/GameMusic")
	if is_instance_valid(boss):
		music.play_boss(region, region == Campaign.Region.VOLCANO and boss.second_phase)
	else:
		music.play_region(region)


func _notice(message: String, seconds: float) -> void:
	notice_label.text = message
	notice_left = seconds


func _resize_backdrop() -> void:
	var texture_size := background.texture.get_size()
	var visible_size := get_viewport_rect().size + Vector2(220, 10)
	var cover := maxf(visible_size.x / texture_size.x, visible_size.y / texture_size.y)
	var editor_cover := 1372.0 / texture_size.x
	background.scale = backdrop_scale * (cover / editor_cover)


func _draw_enemy_projectiles() -> void:
	for projectile: Dictionary in arrows:
		if projectile.has("hostile"):
			var distance := absf(projectile.at.x - float(projectile.origin_x))
			EnemyEffects.bolt(enemy_projectile_layer, projectile.at, projectile.direction, projectile.element,
				projectile.hostile, projectile.radius, distance, elapsed)


func _draw() -> void:
	for glyph in glyphs:
		var center: Vector2 = glyph.at - Vector2(0, 9)
		var charge := 1.0 - float(glyph.left) / float(Armory.WEAPONS.scribe_staff.glyph.delay)
		draw_circle(center, 26.0, Color(0.31, 0.64, 0.92, 0.08 + charge * 0.15))
		draw_arc(center, 22.0, -PI * 0.5, TAU * charge - PI * 0.5, 32, Color("#bbebff"), 2.2, true)
		draw_arc(center, 33.0, 0, TAU, 32, Color("#9cc9ee"), 1.1, true)
		for mark in range(6):
			var ray := Vector2.from_angle(TAU * mark / 6.0 + charge)
			draw_line(center + ray * 27.0, center + ray * 32.0, Color("#9cc9ee"), 2.0, true)
	for projectile: Dictionary in arrows:
		var at: Vector2 = projectile.at
		if projectile.get("spell", false):
			var heading := Vector2(projectile.direction, 0)
			for spark in range(8):
				var sway := sin(elapsed * 37.0 + spark * 2.6)
				var trail := at - heading * (7.0 + spark * 3.8) + Vector2(0, sway * (2 + spark * 0.7))
				draw_circle(trail, 3.6 - spark * 0.37, Color(1, 0.26 + 0.06 * (7 - spark), 0.07, 0.85 - spark * 0.09), true, -1, true)
			draw_circle(at, 15, Color(1, 0.24, 0.05, 0.22), true, -1, true)
			draw_circle(at, 8, Color("#ff6b25"), true, -1, true)
			draw_circle(at + heading * 2.0, 5.5, Color("#ffbe55"), true, -1, true)
			draw_circle(at + heading * 3.5, 3.5, Color("#fff5c0"), true, -1, true)
			continue
		if projectile.has("hostile"):
			continue
		var thorn: bool = projectile.weapon == "thorn_bow"
		draw_line(at - Vector2(projectile.direction * 26, 0), at,
			Color("#cbd98d") if thorn else Color("#ffe7a6"), 2, true)
		draw_circle(at, 2, Color("#efffc4") if thorn else Color("#fff7d7"))
	for drop: Dictionary in drops:
		var at: Vector2 = drop.at + Vector2(0, sin(elapsed * 4.8 + float(drop.at.x)) * 5.0)
		var color: Color = DROP_COLORS.get(drop.kind, Color("#dfb9ff"))
		var atlas_cell: int = DROP_SPRITES.get(drop.kind, -1)
		if atlas_cell >= 0:
			draw_texture_rect(SOFT_LIGHT, Rect2(at - Vector2(15, 15), Vector2(30, 30)),
				false, Color(color, 0.24))
			draw_texture_rect_region(DROP_ATLAS, Rect2(at - Vector2(11, 11), Vector2(22, 22)),
				Rect2(atlas_cell * DROP_ATLAS_CELL, 0, DROP_ATLAS_CELL, DROP_ATLAS_CELL))
			continue
		draw_circle(at, 15, Color(color, 0.16))
		if drop.kind == "lantern":
			var lantern: Dictionary = Bestiary.loot.lantern
			draw_texture_rect_region(lantern_icon,
				Rect2(at - Vector2(10, 14), Vector2(20, 28)), Bestiary.rectangle(lantern.icon_region))
		elif drop.kind == "blade":
			draw_texture_rect(Equipment.icon(Bestiary.loot.guardian_blade.grants),
				Rect2(at - Vector2(13, 13), Vector2(26, 26)), false)
		elif not Equipment.item(drop.kind).is_empty():
			draw_texture_rect(Equipment.ranked_icon(drop.kind, int(drop.rank)),
				Rect2(at - Vector2(13, 13), Vector2(26, 26)), false)
	for index in range(pickup_feedback.size() - 1, -1, -1):
		var popup := pickup_feedback[index]
		var age := elapsed - float(popup.spawn)
		var row := pickup_feedback.size() - 1 - index
		var at := hunter.position - Vector2(float(popup.width) * 0.5, 78.0 + row * 23.0 + age * 25.0)
		var alpha := 1.0 - smoothstep(0.85, PICKUP_DURATION, age)
		var color: Color = popup.color
		color.a = alpha
		draw_string_outline(font, at, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, PICKUP_FONT_SIZE, 6, Color(0.05, 0.10, 0.11, alpha))
		draw_string(font, at, popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, PICKUP_FONT_SIZE, color)


func _build_hud() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK TC", "Microsoft JhengHei", "PingFang TC", "sans-serif"])
	var hud := CanvasLayer.new()
	hud.layer = 2
	add_child(hud)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var status := _panel(root)
	status.position = Vector2(24, 24)
	var status_style: StyleBoxFlat = status.get_theme_stylebox("panel").duplicate()
	status_style.bg_color = Color(0.038, 0.084, 0.095, 0.96)
	status_style.border_color = Color("#627c74")
	status_style.set_corner_radius_all(9)
	status.add_theme_stylebox_override("panel", status_style)
	var status_rows := VBoxContainer.new()
	status_rows.add_theme_constant_override("separation", 8)
	status.add_child(status_rows)

	var life_row := HBoxContainer.new()
	life_row.add_theme_constant_override("separation", 12)
	status_rows.add_child(life_row)
	level_label = _label(15, Color("#eac48c"))
	life_row.add_child(level_label)
	health_label = _label(16, Color("#ffaca0"))
	life_row.add_child(health_label)
	health_hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	life_row.add_child(health_hearts)

	var loadout := HBoxContainer.new()
	loadout.add_theme_constant_override("separation", 23)
	status_rows.add_child(loadout)
	weapon_status = _status_field(loadout, "武器")
	spirit_status = _status_field(loadout, "魂技")
	soul_status = _status_field(loadout, "持有魂")
	mana_status = _status_field(loadout, "法力")
	status_flags = _label(12, Color("#e2c799"))
	status_rows.add_child(status_flags)

	var journal := _panel(root)
	journal.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	journal.offset_left = -355
	journal.offset_right = -24
	journal.offset_top = 24
	objective_label = _label(16, Color("#e1e9d7"))
	journal.add_child(objective_label)
	if stage == Campaign.BOSS_STAGE:
		_build_boss_hud(root)

	notice_label = _label(19, Color("#fff0c1"))
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_constant_override("outline_size", 7)
	notice_label.add_theme_color_override("font_outline_color", Color("#152225"))
	root.add_child(notice_label)
	notice_label.anchor_right = 1.0
	notice_label.offset_top = 118
	notice_label.offset_bottom = 147

	var footer := _panel(root)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24
	footer.offset_right = -24
	footer.offset_top = -94
	footer.offset_bottom = -20
	var footer_rows := VBoxContainer.new()
	footer.add_child(footer_rows)
	prompt_label = _label(17, Color("#ffda9b"))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_rows.add_child(prompt_label)
	var help := _label(15, Color("#b6c9bc"))
	help.text = "A / D 跑步　 Ctrl 慢走　 S 蹲下　 空白鍵 跳躍　 J 攻擊　 Q 換武器　 F 裝魂　 Shift 魂技　 E 互動　 I 裝備　 Esc 暫停"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_rows.add_child(help)

	end_screen = CenterContainer.new()
	root.add_child(end_screen)
	end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := _panel(end_screen)
	var card_rows := VBoxContainer.new()
	card_rows.add_theme_constant_override("separation", 12)
	card.add_child(card_rows)
	end_title = _label(32, Color("#ffe0a1"))
	end_title.text = "封印的另一面" if region == Campaign.Region.COURT else "斷橋另一端"
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_rows.add_child(end_title)
	end_story = _label(18, Color("#e1e9d7"))
	end_story.text = ("古門記起你的名字，鬆開了最後一道封印。\n"
		+ "獵人把提燈留在祭壇，沿晨光下的石階回到地面。") if region == Campaign.Region.COURT else (
		"石門認得你前世的名字。\n門後的水聲沿著石階傳來。")
	end_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_rows.add_child(end_story)
	end_prompt = _label(16, Color("#b6c9bc"))
	end_prompt.text = "E　返回開始頁面" if region == Campaign.Region.COURT else "E　進入淹沒的迴廊"
	if stage > 0:
		end_title.text = "四區通關"
		end_story.text = "獵人擊敗了熔爐深處的守衛。"
		end_prompt.text = "E　返回開始頁面"
	end_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_rows.add_child(end_prompt)
	end_screen.hide()
	_build_camp_menu(root)
	_build_gear_menu(root)
	_build_pause_menu(root)


func _build_boss_hud(root: Control) -> void:
	boss_panel = _panel(root)
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_left = -178
	boss_panel.offset_right = 178
	boss_panel.offset_top = 18
	var rows := VBoxContainer.new()
	boss_panel.add_child(rows)
	boss_caption = _label(18, Color("#ffe0a1"))
	boss_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(boss_caption)
	boss_health = ProgressBar.new()
	boss_health.custom_minimum_size.y = 20
	boss_health.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#bb3730")
	boss_health.add_theme_stylebox_override("fill", fill)
	rows.add_child(boss_health)
	_update_boss_hud()


func _update_boss_hud() -> void:
	boss_panel.visible = is_instance_valid(boss)
	if not boss_panel.visible:
		return
	boss_health.max_value = boss.max_health
	boss_health.value = boss.health
	boss_caption.text = "%s　Lv.%d　%d / %d" % [
		boss.design.name, boss.level, boss.health, boss.max_health]


func _build_camp_menu(root: Control) -> void:
	camp_menu = CenterContainer.new()
	root.add_child(camp_menu)
	camp_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := _panel(camp_menu)
	panel.add_theme_stylebox_override("panel", EquipmentTheme.frame())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	var title := _label(26, Color("#ffe0a1"))
	title.text = "營火與工坊"
	rows.add_child(title)
	camp_stock = _label(15, Color("#d8e4d4"))
	rows.add_child(camp_stock)
	var divider := TextureRect.new()
	divider.name = "CampDivider"
	divider.texture = preload("res://assets/ui/camp/ember_divider.png")
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.custom_minimum_size.y = 18
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(divider)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	rows.add_child(columns)
	var hearth := VBoxContainer.new()
	hearth.add_theme_constant_override("separation", 8)
	columns.add_child(hearth)
	var services := _camp_section(hearth, "營火服務")
	camp_rest = _camp_card(services, preload("res://assets/ui/camp/hearth.png"), "休息與存檔", _camp_heal)
	var growth := _camp_section(hearth, "能力升級")
	camp_level_up = _camp_card(growth, preload("res://assets/ui/camp/growth.png"), "", _level_up)

	var smithy := _camp_section(columns, "武器改造")
	camp_knife = _camp_card(smithy, Equipment.icon("hunter_knife"), "", _upgrade_weapon.bind(false))
	camp_bow = _camp_card(smithy, Equipment.icon("hunter_bow"), "", _upgrade_weapon.bind(true))
	forge_fang = _camp_card(smithy, Equipment.icon("fang_dagger"), "製作蛛牙短刃", _forge_fang_dagger)

	var workshop := _camp_section(columns, "裝備強化")
	camp_rank_items = ItemList.new()
	camp_rank_items.custom_minimum_size = Vector2(292, 166)
	camp_rank_items.add_theme_stylebox_override("panel", EquipmentTheme.frame())
	camp_rank_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	camp_rank_items.icon_mode = ItemList.ICON_MODE_TOP
	camp_rank_items.fixed_icon_size = Vector2i(38, 38)
	camp_rank_items.max_columns = 3
	camp_rank_items.fixed_column_width = 88
	camp_rank_items.add_theme_font_override("font", font)
	camp_rank_items.add_theme_font_size_override("font_size", 12)
	var selected_tile := StyleBoxFlat.new()
	selected_tile.bg_color = Color("#304742")
	selected_tile.border_color = Color("#b8965f")
	selected_tile.set_border_width_all(1)
	selected_tile.set_corner_radius_all(5)
	camp_rank_items.add_theme_stylebox_override("selected", selected_tile)
	camp_rank_items.add_theme_stylebox_override("selected_focus", selected_tile)
	camp_rank_items.item_selected.connect(_show_camp_rank_cost.unbind(1))
	workshop.add_child(camp_rank_items)
	camp_selected_item = _label(16, Color("#f1d294"))
	workshop.add_child(camp_selected_item)
	var item_actions := HBoxContainer.new()
	item_actions.add_theme_constant_override("separation", 8)
	workshop.add_child(item_actions)
	camp_rank_up = _camp_button(item_actions, "", _rank_up)
	camp_rank_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	camp_salvage = _camp_button(item_actions, "", _salvage_item)

	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_END
	navigation.add_theme_constant_override("separation", 8)
	rows.add_child(navigation)
	camp_leave = _camp_button(navigation, "返回探索　Esc", _set_camp_open.bind(false))
	if region > Campaign.Region.TEMPLE:
		_camp_button(navigation, "上一區營火", _queue_region.bind(region - 1))
	camp_save_exit = _camp_button(navigation, "存檔並返回開始頁面", _camp_return_to_title)
	for button: Button in navigation.get_children():
		EquipmentTheme.style_button(button)
	EquipmentTheme.style_button(camp_rank_up)
	EquipmentTheme.style_button(camp_salvage)
	camp_menu.hide()


func _camp_section(parent: Container, heading: String) -> VBoxContainer:
	var section := _panel(parent)
	section.add_theme_stylebox_override("panel", EquipmentTheme.frame())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	section.add_child(rows)
	var title := _label(17, Color("#f1d294"))
	title.text = heading
	rows.add_child(title)
	return rows


func _camp_card(parent: Container, artwork: Texture2D, caption: String, action: Callable) -> Button:
	var button := _camp_button(parent, caption, action)
	button.custom_minimum_size = Vector2(180, 68)
	button.icon = artwork
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", 36)
	button.add_theme_constant_override("h_separation", 8)
	button.add_theme_font_size_override("font_size", 14)
	EquipmentTheme.style_button(button)
	return button


func _camp_button(rows: Container, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 40
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(action)
	rows.add_child(button)
	return button


func _set_camp_open(open: bool) -> void:
	camp_menu.visible = open
	_set_world_locked(open)
	if open:
		_update_camp_menu()
		camp_rest.grab_focus()
	else:
		camp_closed_frame = Engine.get_physics_frames() + 1


func _camp_heal() -> void:
	hunter.rest()
	_save_camp()


func _camp_return_to_title() -> void:
	if _save_camp():
		get_tree().change_scene_to_file(Campaign.TITLE_SCENE)


func _save_camp() -> bool:
	_update_camp_menu()
	var saved := CampSave.write(_checkpoint_state()) == OK
	camp_stock.text += "\n" + ("已保存營火進度" if saved else "存檔失敗，請重試")
	return saved


func _checkpoint_state() -> Dictionary:
	cache_flags[_cache_key()] = landscape.cache_open
	var state := {
		"region": region,
		"stage": stage,
		"boss_felled": boss_felled,
		"lantern_found": lantern_found,
		"keeper_felled": keeper_felled,
		"cache_flags": cache_flags,
		"materials": materials,
		"fangs": fangs,
		"soul_balance": soul_balance,
		"npc_gift_claimed": npc_gift_claimed,
		"letter_quest": letter_quest,
		"player_level": hunter.level,
		"inventory": inventory,
		"next_item_uid": next_item_uid,
		"obtained_equipment": obtained_equipment,
		"opened_treasure": opened_treasure,
		"armor_equipped": armor_equipped,
		"preferred_weapons": preferred_weapons,
		"souls": collected_souls,
		"equipped_soul": hunter.equipped_soul,
		"with_bow": hunter.with_bow,
		"weapon": hunter.selected_weapon(),
		"owned_equipment": owned_equipment,
		"gear": hunter.gear,
		"knife_level": hunter.knife_level,
		"bow_level": hunter.bow_level,
		"stolen_blade": hunter.stolen_blade,
		"guardian_felled": guardian_felled,
		"cache_open": cache_flags.get(Campaign.Region.TEMPLE, false),
	}
	if bool(get(Bestiary.loot.guardian_blade.defeat_flag)) and unclaimed_blade_x >= 0.0:
		state["blade_x"] = unclaimed_blade_x
		state["blade_rank"] = unclaimed_blade_rank
	return state


func _cache_key() -> int:
	return region if stage <= 1 else region + stage * Campaign.IDS.size()


func _restore_camp(state: Dictionary) -> void:
	soul_balance = maxi(0, int(state.get("soul_balance", 0)))
	npc_gift_claimed = bool(state.get("npc_gift_claimed", false))
	letter_quest = clampi(int(state.get("letter_quest", LetterQuest.AVAILABLE)), LetterQuest.AVAILABLE, LetterQuest.DELIVERED) as LetterQuest
	hunter.level = clampi(int(state.get("player_level", 0)), 0, Progression.MAX_LEVEL)
	materials = maxi(0, state.get("materials", 0))
	fangs = maxi(0, state.get("fangs", 0))
	hunter.stolen_blade = state.get("stolen_blade", false)
	for soul in state.get("souls", []):
		if not Bestiary.soul(soul).is_empty() and not collected_souls.has(soul):
			collected_souls.append(soul)
	var equipped: String = state.get("equipped_soul", "")
	if collected_souls.has(equipped):
		hunter.equipped_soul = equipped
	_restore_inventory(state)
	opened_treasure = state.get("opened_treasure", {}).duplicate()
	var previous_weapon: String = state.get("weapon", "hunter_bow" if state.get("with_bow", false) else "hunter_knife")
	if not state.has("inventory") and hunter.stolen_blade and previous_weapon == "hunter_knife" and not state.get("owned_equipment", []).has("root_blade"):
		previous_weapon = "root_blade"
	_sync_equipment(previous_weapon)
	hunter.rest()
	hunter.knife_level = clampi(state.get("knife_level", 0), 0, 2)
	hunter.bow_level = clampi(state.get("bow_level", 0), 0, 2)
	guardian_felled = state.get("guardian_felled", false)
	lantern_found = state.get("lantern_found", false)
	keeper_felled = state.get("keeper_felled", false)
	boss_felled = stage == Campaign.BOSS_STAGE and state.get("boss_felled", false)
	cache_flags = state.get("cache_flags", {Campaign.Region.TEMPLE: state.get("cache_open", false)})
	landscape.cache_open = cache_flags.get(_cache_key(), false)
	unclaimed_blade_rank = clampi(int(state.get("blade_rank", 1)), 1, Progression.MAX_RANK)
	unclaimed_blade_x = state.get("blade_x", -1.0)
	var blade: Dictionary = Bestiary.loot.guardian_blade
	if (stage == 0 or stage == Campaign.BOSS_STAGE) and Campaign.IDS[region] == blade.region and bool(get(blade.defeat_flag)) and not hunter.stolen_blade and unclaimed_blade_x >= 0.0:
		_drop(blade.item, unclaimed_blade_x, 1, unclaimed_blade_rank)


func _forge_fang_dagger() -> void:
	if fangs > 0 and not owned_equipment.has("fang_dagger") and not _bag_full():
		fangs -= 1
		_grant_equipment("fang_dagger")
		_update_camp_menu()
		camp_rest.grab_focus()


func _upgrade_weapon(bow: bool) -> void:
	var level := hunter.bow_level if bow else hunter.knife_level
	var cost := 2 + level
	if level >= 2 or materials < cost:
		return
	materials -= cost
	if bow:
		hunter.bow_level += 1
	else:
		hunter.knife_level += 1
	_update_camp_menu()
	if (camp_bow if bow else camp_knife).disabled:
		camp_rest.grab_focus()


func _level_up() -> void:
	var level := hunter.level
	var cost := Progression.level_cost(level)
	if not camp_menu.visible or level >= Progression.MAX_LEVEL or soul_balance < cost:
		return
	var previous_health := hunter.health
	soul_balance -= cost
	hunter.level += 1
	hunter.health += 1
	if not _save_camp():
		hunter.level = level
		hunter.health = previous_health
		soul_balance += cost
		_show_failed_upgrade()


func _rank_up() -> void:
	var entry := _inventory_item(_selected_camp_item())
	if not camp_menu.visible or entry.is_empty():
		return
	var rank := int(entry.rank)
	var cost := Progression.gear_cost(rank)
	if rank >= Progression.MAX_RANK or soul_balance < cost:
		return
	soul_balance -= cost
	entry.rank = rank + 1
	_sync_equipment()
	if not _save_camp():
		entry.rank = rank
		soul_balance += cost
		_sync_equipment()
		_show_failed_upgrade()


func _salvage_item() -> void:
	var uid := _selected_camp_item()
	var entry := _inventory_item(uid)
	if not camp_menu.visible or entry.is_empty() or _is_equipped(entry):
		return
	var index := inventory.find(entry)
	var old_armor := armor_equipped.duplicate()
	var old_preferences := preferred_weapons.duplicate()
	var old_weapon := hunter.selected_weapon()
	var old_health := hunter.health
	var value := Progression.salvage_value(int(entry.rank))
	soul_balance += value
	_remove_inventory_item(uid)
	if not _save_camp():
		inventory.insert(index, entry)
		armor_equipped = old_armor
		preferred_weapons = old_preferences
		_sync_equipment(old_weapon)
		hunter.health = old_health
		soul_balance -= value
		_show_failed_upgrade()


func _show_failed_upgrade() -> void:
	_update_camp_menu()
	camp_stock.text += "\n存檔失敗，保留原等級與魂量"


func _selected_camp_item() -> int:
	var selection := camp_rank_items.get_selected_items()
	return 0 if selection.is_empty() else int(camp_rank_items.get_item_metadata(selection[0]))


func _show_camp_rank_cost() -> void:
	var entry := _inventory_item(_selected_camp_item())
	camp_selected_item.text = "背包沒有裝備" if entry.is_empty() else _equipment_label(entry)
	var can_salvage := not entry.is_empty() and not _is_equipped(entry)
	camp_salvage.visible = can_salvage
	camp_salvage.disabled = not can_salvage
	camp_salvage.text = "換取 %d 魂" % Progression.salvage_value(int(entry.rank)) if can_salvage else ""
	if entry.is_empty():
		camp_rank_up.disabled = true
		camp_rank_up.text = "背包沒有裝備"
		return
	var rank := int(entry.rank)
	var cost := Progression.gear_cost(rank)
	camp_rank_up.disabled = rank >= Progression.MAX_RANK or soul_balance < cost
	camp_rank_up.text = "已達 %s" % Progression.rank_name(Progression.MAX_RANK) if rank >= Progression.MAX_RANK else (
		"%s → %s　花費 %d 魂" % [Progression.rank_name(rank), Progression.rank_name(rank + 1), cost])


func _update_camp_menu() -> void:
	camp_stock.text = "Lv.%d　｜　魂 %d　｜　體力 %d/%d　｜　素材 %d　｜　背包 %d/%d" % [
		hunter.level, soul_balance, hunter.health, hunter.max_health(), materials,
		inventory.size(), Progression.bag_capacity(hunter.level)]
	var cost := Progression.level_cost(hunter.level)
	camp_level_up.disabled = hunter.level >= Progression.MAX_LEVEL or soul_balance < cost
	camp_level_up.text = "角色成長\n已達 Lv.%d" % Progression.MAX_LEVEL if hunter.level >= Progression.MAX_LEVEL else (
		"Lv.%d → Lv.%d  ·  %d 魂\n體力 +1  ·  背包 +%d" % [
			hunter.level, hunter.level + 1, cost,
			Progression.bag_capacity(hunter.level + 1) - Progression.bag_capacity(hunter.level)])
	var selected := _selected_camp_item()
	if selected == 0:
		selected = _equipped_uid("武器")
	camp_rank_items.clear()
	for entry in inventory:
		var item_name := _entry_name(entry)
		camp_rank_items.add_item(_equipment_label(entry), Equipment.ranked_icon(entry.item, int(entry.rank)))
		var index := camp_rank_items.item_count - 1
		camp_rank_items.set_item_metadata(index, entry.uid)
		camp_rank_items.set_item_tooltip(index, item_name)
		if entry.uid == selected:
			camp_rank_items.select(index)
	if camp_rank_items.item_count > 0 and camp_rank_items.get_selected_items().is_empty():
		camp_rank_items.select(0)
	_show_camp_rank_cost()
	_update_upgrade_button(camp_knife, "近戰改造", hunter.knife_level)
	_update_upgrade_button(camp_bow, "獵弓改造", hunter.bow_level)
	forge_fang.visible = fangs > 0 and not owned_equipment.has("fang_dagger")
	forge_fang.disabled = _bag_full()


func _update_upgrade_button(button: Button, weapon: String, level: int) -> void:
	button.disabled = level >= 2 or materials < 2 + level
	button.text = "%s +%d\n已達上限" % [weapon, level] if level >= 2 else (
		"%s +%d → +%d\n消耗 %d 素材" % [weapon, level, level + 1, 2 + level]
	)


func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	var art := StyleBoxFlat.new()
	art.bg_color = Color(0.05, 0.10, 0.11, 0.91)
	art.border_color = Color("#557069")
	art.set_border_width_all(1)
	art.set_corner_radius_all(6)
	art.content_margin_left = 17
	art.content_margin_right = 17
	art.content_margin_top = 10
	art.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", art)
	parent.add_child(panel)
	return panel


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _status_field(parent: Container, title: String) -> Label:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	parent.add_child(rows)
	var caption := _label(11, Color("#a8c3ba"))
	caption.text = title
	rows.add_child(caption)
	var value := _label(15, Color("#f0e5cb"))
	rows.add_child(value)
	return value


func _update_hud() -> void:
	var weapon := hunter.selected_weapon()
	var max_health := hunter.max_health()
	level_label.text = "Lv.%d" % hunter.level
	health_label.text = "體力 %d/%d" % [hunter.health, max_health]
	health_hearts.update_health(hunter.health, max_health)
	weapon_status.text = _ranked_gear_name(weapon, hunter.item_rank(weapon))
	spirit_status.text = Bestiary.soul(hunter.equipped_soul).get("name", "未裝備")
	soul_status.text = str(soul_balance)
	mana_status.get_parent().visible = hunter.staff_unlocked
	mana_status.text = "%d/%d" % [hunter.mana, Hunter.MAX_MANA]
	var flags := PackedStringArray()
	if letter_quest == LetterQuest.CARRYING:
		flags.append("送信委託：把皮普的信交給艾德")
	if _bag_full():
		flags.append("背包已滿")
	if hunter.pollen_left > 0:
		flags.append("鱗粉緩速")
	if region == Campaign.Region.CORRIDOR and lantern_found:
		flags.append("潮火提燈")
	status_flags.text = "    ".join(flags)
	status_flags.visible = not flags.is_empty()
	if stage > 0:
		_update_stage_hud()
		return
	if region != Campaign.Region.TEMPLE:
		_update_region_hud()
		return
	if not collected_souls.has("lizard"):
		objective_label.text = "崩塌神殿\n往東狩獵滑翔蜥蜴，取得蜥翼之魂。"
	elif not guardian_felled:
		objective_label.text = "崩塌神殿\n穿過地下通道，打倒東側的樹靈。"
	else:
		objective_label.text = "崩塌神殿\n回到西側斷橋，用蜥翼抵達石門。"

	prompt_label.text = ""
	if _near_prop(landscape.campfires):
		prompt_label.text = "E　打開營火與工坊選單"
	elif _near_legacy_exit():
		prompt_label.text = "E　查看石門"
	elif _near_cache() and not landscape.cache_open:
		prompt_label.text = "E　查看觀景台上的石匣"
	elif not _near_treasure().is_empty():
		prompt_label.text = "E　打開補給石匣"
	elif hunter.position.x > 677 and hunter.position.x < 805:
		prompt_label.text = "斷橋　／　裝備蜥翼，跳起後按住 Shift 滑翔"
	else:
		prompt_label.text = _monster_hint()


func _update_stage_hud() -> void:
	var objective := "沿平台上行，尋找最上層的出口。"
	if stage == Campaign.BOSS_STAGE:
		_update_boss_hud()
		objective = "前往出口。" if boss_felled else "擊倒首領以開啟出口。"
	objective_label.text = "%s　%d / %d\n%s" % [Campaign.NAMES[region], stage, Campaign.BOSS_STAGE, objective]
	prompt_label.text = ""
	if _near_prop(landscape.campfires):
		prompt_label.text = "E　打開營火與工坊選單"
	elif _near_legacy_exit():
		if not landscape.portal_open:
			prompt_label.text = "首領仍在，出口封鎖"
		elif stage == Campaign.BOSS_STAGE:
			prompt_label.text = "E　完成戰役" if region == Campaign.Region.VOLCANO else "E　前往下一區"
		else:
			prompt_label.text = "E　挑戰首領" if stage == Campaign.BOSS_STAGE - 1 else "E　前往下一關"
	elif _near_equipment_chest() != null:
		prompt_label.text = "E　打開寶箱"
	elif _near_cache() and not landscape.cache_open:
		prompt_label.text = "E　打開石匣"
	else:
		prompt_label.text = _monster_hint()


func _monster_hint() -> String:
	for monster in enemies:
		var hint: Dictionary = monster.design.get("encounter_hint", {})
		if hint.is_empty() or owned_equipment.has(hint.get("unless_owned", "")):
			continue
		var distance := hunter.position.x - monster.home.x
		if distance > float(hint.get("from_offset", -INF)) and absf(distance) < float(hint.get("radius", INF)):
			return hint.text
	return ""


func _update_region_hud() -> void:
	if region == Campaign.Region.CORRIDOR:
		objective_label.text = Campaign.NAMES[region] + "\n" + (
			"穿過暗水道，往東走到排水出口。" if lantern_found else "擊倒石蟹，或在牠舉起提燈時射落提燈。")
	else:
		objective_label.text = Campaign.NAMES[region] + "\n" + (
			"調查東側主祭壇。" if keeper_felled else "避開雙段橫掃，蓄力時擊破護印。")
	prompt_label.text = ""
	if _near_prop(landscape.campfires):
		prompt_label.text = "E　打開營火與工坊選單"
	elif _near_legacy_exit():
		prompt_label.text = "E　查看排水出口" if region == Campaign.Region.CORRIDOR else "E　調查主祭壇"
	elif (_near_cache() and not landscape.cache_open) or not _near_treasure().is_empty():
		prompt_label.text = "E　打開石匣"


func _bag_full() -> bool:
	return inventory.size() >= Progression.bag_capacity(hunter.level)


func _warn_full_bag() -> void:
	if notice_left <= 0.0:
		_notice("背包已滿。按 I 銷毀裝備，或回營火換魂。", 2.7)


func _inventory_item(uid: int) -> Dictionary:
	for entry in inventory:
		if int(entry.uid) == uid:
			return entry
	return {}


func _first_item(id: String) -> int:
	for entry in inventory:
		if entry.item == id:
			return int(entry.uid)
	return 0


func _grant_equipment(id: String, rank: int = 1, allow_duplicate: bool = false) -> bool:
	if Equipment.item(id).is_empty() or _bag_full() or (not allow_duplicate and _first_item(id) != 0):
		return false
	inventory.append({"uid": next_item_uid, "item": id, "rank": clampi(rank, 1, Progression.MAX_RANK)})
	next_item_uid += 1
	obtained_equipment[id] = true
	_sync_equipment()
	return true


func _remove_inventory_item(uid: int) -> void:
	var entry := _inventory_item(uid)
	if entry.is_empty():
		return
	inventory.erase(entry)
	_sync_equipment()


func _sync_equipment(desired_weapon: String = "") -> void:
	for chest in landscape.equipment_chests:
		if chest.loot_rank > 0:
			chest.set_opened(opened_treasure.has(_treasure_key(chest)))
		else:
			chest.set_opened(obtained_equipment.has(chest.equipment_id))
	var weapon := desired_weapon if not desired_weapon.is_empty() else hunter.selected_weapon()
	var known := {}
	hunter.unlocked_weapons.clear()
	owned_equipment.clear()
	for entry in inventory:
		var id: String = entry.item
		if known.has(id):
			continue
		known[id] = true
		if id not in Equipment.STARTING_WEAPONS:
			owned_equipment.append(id)
		if Equipment.item(id)[1] == "武器":
			hunter.unlocked_weapons.append(id)
	hunter.staff_unlocked = hunter.unlocked_weapons.has("ember_staff") or hunter.unlocked_weapons.has("scribe_staff")
	hunter.item_ranks.clear()
	for id in preferred_weapons.keys():
		if not hunter.unlocked_weapons.has(id):
			preferred_weapons.erase(id)
	for id in hunter.unlocked_weapons:
		var entry := _inventory_item(int(preferred_weapons.get(id, 0)))
		if entry.is_empty() or entry.item != id:
			entry = _inventory_item(_first_item(id))
		preferred_weapons[id] = entry.uid
		hunter.item_ranks[id] = entry.rank
	hunter.gear.clear()
	for slot in armor_equipped.keys():
		var entry := _inventory_item(int(armor_equipped[slot]))
		if entry.is_empty() or Equipment.item(entry.item)[1] != slot or slot == "武器":
			armor_equipped.erase(slot)
		else:
			hunter.gear[slot] = entry.item
			hunter.item_ranks[entry.item] = entry.rank
	hunter.select_weapon(weapon)
	hunter.health = mini(hunter.health, hunter.max_health())


func _restore_inventory(state: Dictionary) -> void:
	if state.has("inventory"):
		inventory.clear()
		var used := {}
		next_item_uid = maxi(1, int(state.get("next_item_uid", 1)))
		for value in state.inventory:
			if value is not Dictionary:
				continue
			var uid := int(value.get("uid", 0))
			var id := String(value.get("item", ""))
			if uid <= 0 or used.has(uid) or Equipment.item(id).is_empty():
				continue
			inventory.append({"uid": uid, "item": id, "rank": clampi(int(value.get("rank", 1)), 1, Progression.MAX_RANK)})
			used[uid] = true
			next_item_uid = maxi(next_item_uid, uid + 1)
		obtained_equipment = state.get("obtained_equipment", {}).duplicate()
		for entry in inventory:
			obtained_equipment[entry.item] = true
		armor_equipped = state.get("armor_equipped", {}).duplicate()
		preferred_weapons = state.get("preferred_weapons", {}).duplicate()
	else:
		if state.get("stolen_blade", false):
			_append_legacy_item("root_blade", state)
		for id in state.get("owned_equipment", []):
			_append_legacy_item(id, state)
		if state.get("cache_open", false):
			_append_legacy_item("moss_vest", state)
			_append_legacy_item("ember_staff", state)
		for slot in state.get("gear", {}):
			var uid := _first_item(state.gear[slot])
			if uid != 0:
				armor_equipped[slot] = uid
		for id: String in Equipment.STARTING_WEAPONS:
			var entry := _inventory_item(_first_item(id))
			entry.rank = clampi(int(state.get("item_ranks", {}).get(id, 1)), 1, Progression.MAX_RANK)


func _append_legacy_item(id: String, state: Dictionary) -> void:
	if Equipment.item(id).is_empty() or _first_item(id) != 0:
		return
	var rank := clampi(int(state.get("item_ranks", {}).get(id, 1)), 1, Progression.MAX_RANK)
	inventory.append({"uid": next_item_uid, "item": id, "rank": rank})
	next_item_uid += 1
	obtained_equipment[id] = true


func _equipped_uid(slot: String) -> int:
	return int(preferred_weapons.get(hunter.selected_weapon(), 0)) if slot == "武器" else int(armor_equipped.get(slot, 0))


func _build_gear_menu(root: Control) -> void:
	gear_menu = CenterContainer.new()
	root.add_child(gear_menu)
	gear_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := _panel(gear_menu)
	panel.add_theme_stylebox_override("panel", EquipmentTheme.frame())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	var heading := _label(24, Color("#ffe0a1"))
	heading.text = "裝備"
	rows.add_child(heading)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	rows.add_child(columns)
	_build_gear_portrait(columns)

	var bag_column := VBoxContainer.new()
	bag_column.custom_minimum_size.x = 410
	bag_column.add_theme_constant_override("separation", 8)
	columns.add_child(bag_column)
	bag_count = _label(16, Color("#d8e4d4"))
	bag_column.add_child(bag_count)
	gear_list = ItemList.new()
	gear_list.add_theme_stylebox_override("panel", EquipmentTheme.frame())
	gear_list.custom_minimum_size.y = 252
	gear_list.icon_mode = ItemList.ICON_MODE_TOP
	gear_list.fixed_icon_size = Vector2i(40, 40)
	gear_list.max_columns = 4
	gear_list.fixed_column_width = 86
	gear_list.same_column_width = true
	gear_list.max_text_lines = 1
	gear_list.add_theme_font_override("font", font)
	gear_list.add_theme_font_size_override("font_size", 14)
	gear_list.add_theme_constant_override("h_separation", 5)
	gear_list.add_theme_constant_override("v_separation", 5)
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color("#344640")
	selected.border_color = Color("#bba272")
	selected.set_border_width_all(1)
	selected.set_corner_radius_all(4)
	gear_list.add_theme_stylebox_override("selected", selected)
	gear_list.add_theme_stylebox_override("selected_focus", selected)
	gear_list.item_selected.connect(_show_gear)
	gear_list.item_activated.connect(func(_index): _apply_gear())
	bag_column.add_child(gear_list)

	var details := _panel(bag_column)
	details.add_theme_stylebox_override("panel", EquipmentTheme.frame())
	gear_detail_scroll = ScrollContainer.new()
	gear_detail_scroll.custom_minimum_size.y = 140
	gear_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(gear_detail_scroll)
	var detail_rows := VBoxContainer.new()
	detail_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_rows.add_theme_constant_override("separation", 6)
	gear_detail_scroll.add_child(detail_rows)
	var item_header := HBoxContainer.new()
	item_header.add_theme_constant_override("separation", 12)
	detail_rows.add_child(item_header)
	gear_name = _label(20, Color("#f4d698"))
	gear_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item_header.add_child(gear_name)
	gear_slot = _label(13, Color("#adbfba"))
	item_header.add_child(gear_slot)
	_add_gear_divider(detail_rows)
	gear_values = _label(15, Color("#f2e9d2"))
	gear_values.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_rows.add_child(gear_values)
	gear_armor = _label(15, Color("#f2e9d2"))
	detail_rows.add_child(gear_armor)
	gear_detail = _label(14, Color("#adbfba"))
	gear_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_rows.add_child(gear_detail)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	bag_column.add_child(actions)
	actions.alignment = BoxContainer.ALIGNMENT_END
	gear_apply = _camp_button(actions, "裝備　E", _apply_gear)
	gear_apply.custom_minimum_size.x = 88
	destroy_item = _camp_button(actions, "銷毀　D", _ask_destroy_item)
	destroy_item.custom_minimum_size.x = gear_apply.custom_minimum_size.x
	var group_gap := Control.new()
	group_gap.custom_minimum_size.x = 8
	group_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(group_gap)
	destroy_dialog = ConfirmationDialog.new()
	destroy_dialog.title = "銷毀裝備"
	destroy_dialog.get_ok_button().text = "銷毀"
	destroy_dialog.get_cancel_button().text = "取消"
	destroy_dialog.confirmed.connect(_destroy_gear_item)
	gear_menu.add_child(destroy_dialog)
	var close := _camp_button(actions, "返回探索　I / Esc", _set_gear_open.bind(false))
	close.name = "ReturnToExploration"
	for button: Button in [gear_apply, destroy_item, close, destroy_dialog.get_ok_button(), destroy_dialog.get_cancel_button()]:
		EquipmentTheme.style_button(button)
	gear_menu.hide()


func _build_gear_portrait(parent: HBoxContainer) -> void:
	var panel := _panel(parent)
	panel.add_theme_stylebox_override("panel", EquipmentTheme.frame())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	rows.custom_minimum_size.x = 448
	_add_gear_heading(rows, "目前裝備")

	var portrait_row := HBoxContainer.new()
	portrait_row.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_row.add_theme_constant_override("separation", 8)
	portrait_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(portrait_row)
	var left := _gear_slot_column(portrait_row)
	_add_gear_slot(left, "頭部")
	_add_gear_slot(left, "手部")

	gear_portrait = TextureRect.new()
	gear_portrait.name = "HunterPortrait"
	gear_portrait_base = AtlasTexture.new()
	gear_portrait_base.atlas = HunterAnimation.FRAMES["idle"]
	gear_portrait_base.region = Rect2(151, 0, 133, 182)
	gear_portrait_base.filter_clip = true
	gear_portrait.texture = gear_portrait_base
	gear_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gear_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gear_portrait.custom_minimum_size = Vector2(144, 168)
	gear_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_portrait_pose = Node2D.new()
	gear_portrait.add_child(gear_portrait_pose)
	gear_portrait_pose.draw.connect(_draw_gear_portrait)
	gear_portrait.resized.connect(_layout_gear_portrait)
	var center := _gear_slot_column(portrait_row)
	center.add_child(gear_portrait)
	var weapon := _gear_slot_column(center)
	weapon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_add_gear_slot(weapon, "武器")

	var right := _gear_slot_column(portrait_row)
	_add_gear_slot(right, "身體")
	_add_gear_slot(right, "腿部")
	_add_gear_divider(rows)
	_add_gear_heading(rows, "目前狀態")
	var stats := GridContainer.new()
	stats.name = "HunterStats"
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 20)
	stats.add_theme_constant_override("v_separation", 5)
	rows.add_child(stats)
	for title in ["Level", "魂", "HP", "MP", "攻擊力", "護甲", "攻擊頻率", "防禦力"]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(row)
		var caption := _label(14, Color("#b3c4bc"))
		caption.text = title
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var value := _label(14, Color("#f2e9d2"))
		row.add_child(value)
		gear_stat_values[title] = value
		var comparison := HBoxContainer.new()
		row.add_child(comparison)
		var arrow := _label(14, Color("#b3c4bc"))
		arrow.text = "→"
		comparison.add_child(arrow)
		var target := _label(14, Color.WHITE)
		comparison.add_child(target)
		gear_stat_targets[title] = target
		comparison.hide()
	gear_stat_values["防禦力"].mouse_filter = Control.MOUSE_FILTER_PASS
	gear_stat_values["防禦力"].tooltip_text = "護甲提供的傷害減免"


func _add_gear_heading(parent: Container, title: String) -> void:
	var heading := _label(16, Color("#f4d698"))
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(heading)


func _add_gear_divider(parent: Container) -> void:
	var divider := TextureRect.new()
	divider.texture = preload("res://assets/ui/equipment_divider.png")
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	divider.custom_minimum_size.y = 12
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(divider)


func _refresh_gear_stats(entry: Dictionary = {}) -> void:
	var weapon := hunter.selected_weapon()
	gear_stat_values["Level"].text = str(hunter.level)
	gear_stat_values["HP"].text = "%d / %d" % [hunter.health, hunter.max_health()]
	gear_stat_values["MP"].text = "%d / %d" % [hunter.mana, Hunter.MAX_MANA]
	gear_stat_values["攻擊力"].text = str(hunter.weapon_damage(weapon))
	gear_stat_values["攻擊頻率"].text = "%.2f 次/秒" % (1.0 / hunter.weapon_period(weapon))
	gear_stat_values["護甲"].text = str(hunter.armor_points())
	gear_stat_values["防禦力"].text = "%d%%" % hunter.armor_reduction()
	gear_stat_values["魂"].text = str(soul_balance)

	for target in gear_stat_targets.values():
		target.get_parent().hide()
	if entry.is_empty():
		return
	var id: String = entry.item
	var slot: String = Equipment.item(id)[1]
	var loadout := hunter.gear.duplicate()
	var ranks := hunter.item_ranks.duplicate()
	ranks[id] = entry.rank
	if slot == "武器":
		weapon = id
	elif _is_equipped(entry):
		loadout.erase(slot)
	else:
		loadout[slot] = id
	var hp := hunter.max_health(loadout)
	_preview_stat("HP", hunter.max_health(), hp, "%d / %d" % [mini(hunter.health, hp), hp])
	var damage := hunter.weapon_damage(weapon, int(ranks.get(weapon, 1)))
	_preview_stat("攻擊力", hunter.weapon_damage(hunter.selected_weapon()), damage, str(damage))
	var rate := 1.0 / hunter.weapon_period(weapon, loadout)
	var current_rate := 1.0 / hunter.weapon_period(hunter.selected_weapon())
	if not is_equal_approx(current_rate, rate):
		gear_stat_values["攻擊頻率"].text = "%.2f" % current_rate
	_preview_stat("攻擊頻率", current_rate, rate, "%.2f 次/秒" % rate)
	var armor := hunter.armor_points(loadout, ranks)
	_preview_stat("護甲", hunter.armor_points(), armor, str(armor))
	var reduction := Progression.armor_percent(armor)
	_preview_stat("防禦力", hunter.armor_reduction(), reduction, "%d%%" % reduction)


func _preview_stat(title: String, current: float, projected: float, display: String) -> void:
	if is_equal_approx(current, projected):
		return
	var target := gear_stat_targets[title]
	target.text = display
	target.add_theme_color_override("font_color", STAT_RISE if projected > current else STAT_FALL)
	target.get_parent().show()


func _layout_gear_portrait() -> void:
	var size := gear_portrait.size
	var base_region := gear_portrait_base.region
	var fit := minf(size.x / base_region.size.x, size.y / base_region.size.y)
	# Match the centered short-knife portrait's pixel scale and foot position.
	var foot := Vector2(HunterAnimation.FRAME_WIDTH * 0.5, base_region.end.y)
	gear_portrait_pose.position = size * 0.5 + (foot - base_region.get_center()) * fit
	gear_portrait_pose.scale = Vector2.ONE * (fit / HunterAnimation.SCALE)


func _draw_gear_portrait() -> void:
	WeaponArt.draw_portrait(gear_portrait_pose, hunter.selected_weapon())


func _gear_slot_column(parent: Container) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	return column


func _add_gear_slot(parent: VBoxContainer, slot: String) -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	parent.add_child(rows)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(54, 54)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0d1d1e")
	style.border_color = Color("#637569")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	tile.add_theme_stylebox_override("panel", style)
	rows.add_child(tile)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.add_child(icon)
	gear_slot_images[slot] = icon
	var caption := _label(13, Color("#b3c4bc"))
	caption.text = slot
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(caption)


func _set_gear_open(open: bool) -> void:
	gear_menu.visible = open
	_set_world_locked(open)
	if open:
		_refresh_gear(_equipped_uid("武器"))
		gear_list.grab_focus()
	else:
		camp_closed_frame = Engine.get_physics_frames() + 1


func _refresh_gear(selected: int) -> void:
	var default_portrait := hunter.selected_weapon() == "hunter_knife"
	gear_portrait.texture = gear_portrait_base if default_portrait else null
	gear_portrait_pose.visible = not default_portrait
	gear_portrait_pose.queue_redraw()
	for slot in gear_slot_images:
		var entry := _inventory_item(_equipped_uid(slot))
		var icon: TextureRect = gear_slot_images[slot]
		icon.texture = null if entry.is_empty() else Equipment.ranked_icon(entry.item, int(entry.rank))
		icon.tooltip_text = "%s　%s" % [slot, "未裝備" if entry.is_empty() else _entry_name(entry)]
	bag_count.text = "背包　%d / %d" % [inventory.size(), Progression.bag_capacity(hunter.level)]
	gear_list.clear()
	gear_ids.clear()
	gear_uids.clear()
	var sorted_items := inventory.duplicate()
	sorted_items.sort_custom(_gear_display_order)
	for entry in sorted_items:
		gear_ids.append(entry.item)
		gear_uids.append(int(entry.uid))
		var rank := int(entry.rank)
		var item_name := _entry_name(entry)
		var item_index := gear_list.add_item(_equipment_label(entry), Equipment.ranked_icon(entry.item, rank))
		gear_list.set_item_tooltip(item_index, item_name)
	if gear_uids.is_empty():
		_refresh_gear_stats()
		gear_name.text = "背包沒有裝備"
		gear_slot.text = ""
		gear_values.text = ""
		gear_armor.hide()
		gear_detail.text = ""
		destroy_item.disabled = true
		gear_apply.disabled = true
		return
	var index := maxi(0, gear_uids.find(selected))
	gear_list.select(index)
	gear_list.ensure_current_is_visible()
	_show_gear(index)


func _gear_display_order(first: Dictionary, second: Dictionary) -> bool:
	var a := GEAR_SLOT_ORDER.find(Equipment.item(first.item)[1])
	var b := GEAR_SLOT_ORDER.find(Equipment.item(second.item)[1])
	if a != b:
		return a < b
	if first.rank != second.rank:
		return first.rank > second.rank
	return first.uid < second.uid


func _equipment_label(entry: Dictionary) -> String:
	var item_name := _entry_name(entry)
	return "E " + item_name if _is_equipped(entry) else item_name


func _entry_name(entry: Dictionary) -> String:
	return _ranked_gear_name(entry.item, int(entry.rank))


func _ranked_gear_name(id: String, rank: int) -> String:
	var name_text := _gear_item_name(id)
	return name_text if id == "unarmed" else "%s %s" % [Progression.rank_name(rank), name_text]


func _is_equipped(entry: Dictionary) -> bool:
	var slot: String = Equipment.item(entry.item)[1]
	return _equipped_uid(slot) == int(entry.uid)


func _show_gear(index: int) -> void:
	gear_detail_scroll.scroll_vertical = 0
	var entry := _inventory_item(gear_uids[index])
	var id: String = entry.item
	var rank := int(entry.rank)
	var slot: String = Equipment.item(id)[1]
	var equipped := _is_equipped(entry)
	_refresh_gear_stats(entry)
	gear_name.text = _entry_name(entry)
	gear_slot.text = "%s  ·  %s" % [slot, "已裝備" if equipped else "未裝備"]
	gear_values.text = _gear_item_values(id, rank)
	gear_values.visible = not gear_values.text.is_empty()
	gear_armor.visible = slot != "武器"
	gear_armor.text = "護甲 +%d　｜　目前減傷 %d%%" % [rank, hunter.armor_reduction()]
	gear_detail.text = "效果　" + str(Equipment.item(id)[2])
	gear_apply.disabled = slot == "武器" and equipped
	gear_apply.text = "卸下　E" if equipped and not gear_apply.disabled else "裝備　E"
	destroy_item.disabled = false


func _gear_item_name(id: String) -> String:
	if id == "unarmed":
		return "徒手"
	if id == "hunter_knife":
		return "短刀"
	return Equipment.item(id)[0]


func _gear_item_values(id: String, rank: int) -> String:
	match id:
		"linen_hood":
			var base := Hunter.MAX_HEALTH + hunter.level
			return "最大體力　%d → %d" % [base, base + int(Equipment.ITEMS.linen_hood.bonus_health)]
		"scaleveil_hood":
			return "鱗粉緩速　%.1f 秒 → %.1f 秒" % [Hunter.POLLEN_DURATION, Hunter.POLLEN_DURATION * float(Equipment.ITEMS.scaleveil_hood.pollen_multiplier)]
		"moss_vest":
			return "每次休息後　格擋 1 次傷害"
		"hunter_wraps":
			return "近戰攻擊週期　%.2f 秒 → %.2f 秒" % [Hunter.KNIFE_DURATION, Hunter.WRAPS_KNIFE_DURATION]
		_:
			if Equipment.item(id)[1] != "武器":
				return ""
			var stats := "傷害 %d　｜　攻擊週期 %.2f 秒" % [hunter.weapon_damage(id, rank), hunter.weapon_period(id)]
			if id in ["ember_staff", "scribe_staff"]:
				stats += "　｜　法力 %d" % Hunter.STAFF_MANA_COST
			return stats


func _selected_gear_uid() -> int:
	var selection := gear_list.get_selected_items()
	return 0 if selection.is_empty() else gear_uids[selection[0]]


func _apply_gear() -> void:
	var uid := _selected_gear_uid()
	var entry := _inventory_item(uid)
	if entry.is_empty():
		return
	var id: String = entry.item
	var slot: String = Equipment.item(id)[1]
	if slot == "武器":
		preferred_weapons[id] = uid
		_sync_equipment(id)
	else:
		if _is_equipped(entry):
			armor_equipped.erase(slot)
		else:
			armor_equipped[slot] = uid
		_sync_equipment()
	_refresh_gear(uid)
	gear_list.grab_focus()


func _ask_destroy_item() -> void:
	pending_destroy_uid = _selected_gear_uid()
	var entry := _inventory_item(pending_destroy_uid)
	if entry.is_empty():
		return
	destroy_dialog.dialog_text = "確定銷毀%s？這件裝備將永久消失。" % _entry_name(entry)
	destroy_dialog.popup_centered()


func _destroy_gear_item() -> void:
	_remove_inventory_item(pending_destroy_uid)
	pending_destroy_uid = 0
	_refresh_gear(_equipped_uid("武器"))
	gear_list.grab_focus()


func _build_pause_menu(root: Control) -> void:
	pause_menu = CenterContainer.new()
	root.add_child(pause_menu)
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := _panel(pause_menu)
	panel.custom_minimum_size.x = 320
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	var heading := _label(24, Color("#ffe0a1"))
	heading.text = "暫停"
	rows.add_child(heading)
	var volume_label := _label(16, Color("#d8e4d4"))
	volume_label.text = "主音量"
	rows.add_child(volume_label)
	pause_volume = HSlider.new()
	pause_volume.max_value = 100.0
	pause_volume.step = 1.0
	pause_volume.custom_minimum_size.y = 30
	rows.add_child(pause_volume)
	pause_fullscreen = CheckButton.new()
	pause_fullscreen.text = "全螢幕"
	pause_fullscreen.add_theme_font_override("font", font)
	rows.add_child(pause_fullscreen)
	pause_volume.value_changed.connect(_apply_pause_settings.unbind(1))
	pause_fullscreen.toggled.connect(_apply_pause_settings.unbind(1))
	_camp_button(rows, "繼續探索　Esc", _set_pause_open.bind(false))
	pause_menu.hide()


func _set_pause_open(open: bool) -> void:
	pause_menu.visible = open
	_set_world_locked(open)
	if open:
		var file := Preferences.read()
		pause_volume.set_value_no_signal(float(file.get_value("audio", "volume", 100)))
		pause_fullscreen.set_pressed_no_signal(bool(file.get_value("display", "fullscreen", false)))
		pause_volume.grab_focus()
	else:
		camp_closed_frame = Engine.get_physics_frames() + 1


func _apply_pause_settings() -> void:
	Preferences.apply(get_window(), pause_volume.value, pause_fullscreen.button_pressed)
	if Preferences.write(pause_volume.value, pause_fullscreen.button_pressed) != OK:
		_notice("無法儲存設定。", 4.0)


func _set_world_locked(locked: bool) -> void:
	hunter.set_physics_process(not locked)
	for monster: Monster in enemies:
		monster.set_physics_process(not locked)
