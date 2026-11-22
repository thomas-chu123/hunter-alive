extends Node2D

const Hunter := preload("res://scripts/ruin_hunter.gd")
const Monster := preload("res://scripts/ruin_monster.gd")
const EnemyEffects := preload("res://scripts/ruin_enemy_effects.gd")
const HitEffects := preload("res://scripts/ruin_hit_effects.gd")
const Landscape := preload("res://scripts/ruin_landscape.gd")
const CampSave := preload("res://scripts/camp_save.gd")
const Preferences := preload("res://scripts/game_preferences.gd")
const HunterAnimation := preload("res://scripts/hunter_animation.gd")
const WeaponArt := preload("res://scripts/hunter_weapon_art.gd")
const Equipment := preload("res://scripts/ruin_equipment.gd")
const Bestiary := preload("res://scripts/ruin_bestiary.gd")
const Progression := preload("res://scripts/ruin_progression.gd")
const Armory := preload("res://scripts/ruin_armory.gd")
const CacheTexture := preload("res://assets/environment/ruins/reliquary.png")
const Campaign := preload("res://scripts/campaign.gd")
const MonsterArt := preload("res://scripts/ruin_sprite_art.gd")
const START := Vector2(950, 526)
const MOTH_X := 2330.0
const SOUL_NAMES := {"lizard": "蜥翼", "spider": "蛛步"}
const DROP_COLORS := {
	"material": Color("#eac18c"), "lizard": Color("#a4f2d0"),
	"spider": Color("#ed9e96"), "blade": Color("#ffda84"), "soul_currency": Color("#8de7fb"),
}
const PICKUP_DURATION := 1.3
const PICKUP_FONT_SIZE := 19

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
var armor_equipped: Dictionary = {}
var preferred_weapons: Dictionary = {}
var next_item_uid := 1
@export_enum("Temple", "Flooded Corridor", "Buried Court") var region := 0

var guardian_felled := false
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
var health_hearts := preload("res://scripts/ruin_health_hearts.gd").new()
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
	_resize_backdrop()
	get_viewport().size_changed.connect(_resize_backdrop)

	hunter = Hunter.new()
	hunter.name = "Hunter"
	hunter.position = _camp_start()
	hunter.attacked.connect(_attack)
	hunter.cast.connect(_cast)
	hunter.defeated.connect(_on_hunter_defeated)
	add_child(hunter)
	for id: String in Equipment.STARTING_WEAPONS:
		_grant_equipment(id)
	var listener := AudioListener2D.new()
	hunter.add_child(listener)
	listener.make_current()
	get_node("/root/GameMusic").play_region(region)
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = 3330
	camera.limit_top = -10
	camera.limit_bottom = 662
	camera.position.y = -204
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	hunter.add_child(camera)
	camera.reset_smoothing()
	hit_effects = HitEffects.new()
	hit_effects.camera = camera
	add_child(hit_effects)
	if get_tree().has_meta(CampSave.RESTORE_META):
		_restore_camp(get_tree().get_meta(CampSave.RESTORE_META))
		get_tree().remove_meta(CampSave.RESTORE_META)
	_sync_region_gate()
	_spawn_enemies()
	_build_hud()
	match region:
		Campaign.Region.TEMPLE:
			_notice("前世的記憶停在墜落那一刻。神殿深處也許有回家的線索。", 5.0)
		Campaign.Region.CORRIDOR:
			_notice("暗水道的石閘需要光。留意石蟹舉起的提燈。", 5.0)
		Campaign.Region.COURT:
			_notice("沿王座外階走到主祭壇，找到古門封印者。", 5.0)


func _process(delta: float) -> void:
	elapsed += delta
	while not pickup_feedback.is_empty() and elapsed - float(pickup_feedback.front().spawn) >= PICKUP_DURATION:
		pickup_feedback.pop_front()
	background.position.x = backdrop_origin.x - clampf((hunter.position.x - 950.0) * 0.050, -95, 95)
	notice_left = maxf(0.0, notice_left - delta)
	notice_label.visible = notice_left > 0 and not completed
	if not completed:
		_update_hud()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if completed or transitioning or restarting or camp_menu.visible or gear_menu.visible or pause_menu.visible:
		return
	if hunter.position.y > 790:
		_on_hunter_defeated()
		return
	hunter.shallow_water = region == Campaign.Region.CORRIDOR and hunter.position.y > 522.0 and hunter.position.x > 1580 and hunter.position.x < 2220
	_update_arrows(delta)
	_update_glyphs(delta)
	_collect_drops()
	if Input.is_action_just_pressed("hunt_equip"):
		_equip_next_soul()
	if Input.is_action_just_pressed("hunt_interact") and Engine.get_physics_frames() > camp_closed_frame:
		_interact()


func _input(event: InputEvent) -> void:
	if gear_menu.visible and not destroy_dialog.visible and event is InputEventKey and event.pressed:
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
		if region == Campaign.Region.COURT:
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		else:
			_queue_region(region + 1)


func _spawn_enemies() -> void:
	match region:
		Campaign.Region.TEMPLE:
			_add_monster("spider", 1310)
			_add_monster("lizard", 1880)
			_add_monster("spider", 2240)
			if not guardian_felled:
				_add_monster("treant", 2840)
			_add_monster("bell_moth", MOTH_X)
		Campaign.Region.COURT:
			if not keeper_felled:
				_add_monster("seal_keeper", 2850)
	for encounter in Bestiary.ENCOUNTERS[region]:
		_add_monster(encounter[0], encounter[1])


func _add_monster(species: String, x: float) -> void:
	var monster := Monster.new()
	monster.configure(species, Vector2(x, Landscape.FLOOR_Y), hunter)
	if species == "lantern_crab" and lantern_found:
		monster.armed = false
	monster.felled.connect(_on_monster_felled)
	monster.disarmed.connect(_on_monster_disarmed)
	monster.launched.connect(_launch_enemy_projectile)
	enemies.append(monster)
	add_child(monster)


func _attack(origin: Vector2, direction: float, ranged: bool, damage: int, weapon: String) -> void:
	if ranged:
		hit_effects.release_weapon(weapon)
		arrows.append({"at": origin, "direction": direction, "damage": damage, "left": 0.55,
			"weapon": weapon, "pierce": int(weapon == "thorn_bow"), "hit_ids": []})
		return
	var reach: float = Armory.WEAPONS[weapon][4] if Armory.WEAPONS.has(weapon) else 51.0
	var blade_step := maxi(1, hunter.blade_step) if weapon in Hunter.SHORT_BLADES else 0
	if blade_step > 0:
		hit_effects.swing(origin, direction, reach, blade_step, weapon)
	else:
		hit_effects.release_weapon(weapon)
	var hitbox := Rect2(origin.x if direction > 0 else origin.x - reach, origin.y - 17, reach, 42)
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
			applied += int(fang_hits % 3 == 0)
		else:
			fang_hits = 0
		_hit_monster(monster, applied, weapon_hit, hitbox.intersection(bounds).get_center(),
			direction, false, weapon, blade_step)
		hit_count += 1
		if hit_count >= (2 if weapon == "gate_halberd" else 1):
			break


func _cast(origin: Vector2, direction: float, weapon: String) -> void:
	hit_effects.release_weapon(weapon)
	if weapon == "scribe_staff":
		var x := clampf(origin.x + direction * 129.0, 54.0, 3230.0)
		var vertical_ray := PhysicsRayQueryParameters2D.create(Vector2(x, origin.y), Vector2(x, origin.y + 280.0), 1)
		var ground := get_world_2d().direct_space_state.intersect_ray(vertical_ray)
		if not ground.is_empty():
			glyphs.append({"at": ground.position, "left": 0.46, "damage": hunter.weapon_damage(weapon), "direction": direction})
		return
	# Sweep from just in front of the hunter on the first tick so the staff
	# cannot launch a fireball through a wall or enemy between the body and tip.
	var cast_start := Vector2(hunter.position.x + direction * 15.0, origin.y)
	arrows.append({"at": origin, "direction": direction, "damage": hunter.weapon_damage(weapon), "left": 0.44,
		"spell": true, "weapon": weapon, "hit_ids": [], "cast_start": cast_start})


func _launch_enemy_projectile(origin: Vector2, direction: float, attack: Dictionary) -> void:
	var speed := float(attack.speed)
	arrows.append({"at": origin, "direction": direction, "damage": int(attack.damage),
		"left": (float(attack.trigger_range) + 75.0) / speed, "hostile": attack.kind,
		"speed": speed, "radius": float(attack.extent), "element": attack.element})


func _update_glyphs(delta: float) -> void:
	for index in range(glyphs.size() - 1, -1, -1):
		var glyph := glyphs[index]
		glyph.left -= delta
		if glyph.left > 0:
			continue
		var area := Rect2(glyph.at - Vector2(54, 64), Vector2(108, 69))
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
		var speed: float = arrow.get("speed", 850.0)
		var velocity := Vector2(arrow.direction * (710.0 if spell else speed), 0)
		var to: Vector2 = arrow.at + velocity * delta
		var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
		var wall := get_world_2d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty():
			to = wall.position
		var hitbox := Rect2(Vector2(minf(from.x, to.x), from.y - 4), Vector2(absf(to.x - from.x), 8))
		if spell:
			hitbox = Rect2(Vector2(minf(from.x, to.x), from.y - 6), Vector2(absf(to.x - from.x), 12))
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
		if hunter.gear.get("手部") == "stonegrip_gloves" and monster.attack_kind == "roll" and monster.recovery > 0.0:
			monster.apply_equipment_push(direction, 110.0)
		elif hunter.gear.get("手部") == "hardroot_bracers" and not hunter.is_on_floor():
			monster.apply_equipment_push(direction, 85.0)
	if weapon == "ember_staff":
		hit_effects.fire_impact(point)
		return
	if blade_step == 0:
		hit_effects.impact(point, direction, weapon_hit)
		return
	var blocked := result == Monster.HitResult.BLOCKED
	hit_effects.blade_impact(point, direction, blade_step, blocked, result == Monster.HitResult.DISARMED)
	if not blocked:
		hunter.blade_recoil = -direction * (52.0 if blade_step == 3 else 34.0)
		if not monster.is_queued_for_deletion():
			monster.flash_blade_hit()


func _on_monster_felled(monster: Monster) -> void:
	enemies.erase(monster)
	var x := monster.position.x
	if monster.species == "lantern_crab":
		_drop_corridor_lantern(x)
	var reward := loot_rng.randi_range(int(monster.soul_reward[0]), int(monster.soul_reward[1]))
	_drop("soul_currency", x, reward)
	var rank := Progression.drop_rank(loot_rng.randf())
	if rank > 0:
		var item := loot_catalog[loot_rng.randi_range(0, loot_catalog.size() - 1)]
		_drop(item, x + 22, 1, rank, true)
	var loot: String = Bestiary.DROPS.get(monster.species, "")
	if not loot.is_empty() and not obtained_equipment.has(loot) and not _has_drop(loot):
		_drop(loot, x - 12)
	if monster.species == "ash_scribe" and not obtained_equipment.has("scribe_staff") and not _has_drop("scribe_staff"):
		_drop("scribe_staff", x + 28)
	match monster.species:
		"spider":
			if rng.randf() < 0.37 and not collected_souls.has("spider") and not _has_drop("spider"):
				_drop("spider", x - 12)
			if not owned_equipment.has("fang_dagger"):
				_drop("fang_material", x + 8)
		"lizard":
			if not collected_souls.has("lizard"):
				_drop("lizard", x - 12)
		"bell_moth":
			if not obtained_equipment.has("scaleveil_hood") and not _has_drop("scaleveil_hood"):
				_drop("scaleveil_hood", x - 12)
		"seal_keeper":
			keeper_felled = true
			_sync_region_gate()
			_notice("封印者倒下了。往東調查主祭壇。", 4.0)
			return
		"treant":
			guardian_felled = true
			landscape.portal_open = true
			_drop("material", x + 19, 3)
			_notice("樹靈倒下了。回到神殿入口，借蜥翼滑過斷橋。", 4.0)
			return
	if rng.randf() < 0.76:
		_drop("material", x + 15, 2 if monster.species == "lizard" else 1)


func _drop_corridor_lantern(x: float) -> void:
	if region != Campaign.Region.CORRIDOR or lantern_found or _has_drop("lantern"):
		return
	var gate: StaticBody2D = landscape.get_node("LightGate")
	_drop("lantern", minf(x, gate.position.x - 50.0))
	_notice("提燈落在地上。靠近拾取，用它打開暗水道。", 4.0)


func _on_monster_disarmed(monster: Monster) -> void:
	if monster.species == "lantern_crab":
		_drop_corridor_lantern(monster.position.x + monster.facing * 72.0)
		return
	if monster.species in ["thorn_archer", "shield_heron"]:
		var item := "thorn_bow" if monster.species == "thorn_archer" else "earthen_armor"
		if not obtained_equipment.has(item) and not _has_drop(item):
			_drop(item, monster.position.x + monster.facing * 50.0)
		return
	if monster.species == "seal_keeper":
		_notice("護印已破，趁硬直反擊。", 3.0)
		return
	if hunter.stolen_blade or _has_drop("blade"):
		return
	unclaimed_blade_x = monster.position.x + monster.facing * 104
	_drop("blade", unclaimed_blade_x)
	_notice("%s掉在地上了。" % _ranked_gear_name("root_blade", 1), 3.0)


func _has_drop(kind: String) -> bool:
	for drop: Dictionary in drops:
		if drop.kind == kind:
			return true
	return false


func _drop(kind: String, x: float, amount: int = 1, rank: int = 1, rolled: bool = false) -> void:
	drops.append({"kind": kind, "at": Vector2(clampf(x, 736 if region == Campaign.Region.TEMPLE else 60, 3240), Landscape.FLOOR_Y - 27),
		"amount": amount, "spawn": elapsed, "rank": rank, "rolled": rolled})


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
				if _grant_equipment("root_blade"):
					_show_pickup(_ranked_gear_name("root_blade", 1))
				_notice("取得%s。按 I 換裝。" % _ranked_gear_name("root_blade", 1), 3.0)
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
				if SOUL_NAMES.has(drop.kind):
					var soul_name := "%s之魂" % SOUL_NAMES[drop.kind]
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
	var hint := "跳起後按住 Shift 滑翔。" if hunter.equipped_soul == "lizard" else "貼牆時按住方向與 Shift 攀爬。"
	_notice("已裝備%s。%s" % [SOUL_NAMES[hunter.equipped_soul], hint], 3.0)


func _interact() -> void:
	var loot := _near_treasure()
	if not loot.is_empty():
		if _grant_equipment(loot):
			_notice("石匣內有%s。按 I 看裝備。" % _ranked_gear_name(loot, 1), 4.0)
		else:
			_warn_full_bag()
	elif _near(landscape.shrine.global_position):
		for id in ["linen_hood", "hunter_wraps"]:
			if not obtained_equipment.has(id):
				_grant_equipment(id)
		_set_camp_open(true)
	elif _near(landscape.portal.global_position):
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
	elif _near_cache() and not landscape.cache_open:
		if region == Campaign.Region.TEMPLE:
			var needed := int(not obtained_equipment.has("moss_vest")) + int(not obtained_equipment.has("ember_staff"))
			if inventory.size() + needed > Progression.bag_capacity(hunter.level):
				_warn_full_bag()
				return
		landscape.cache_open = true
		materials += 3
		var rewards := PackedStringArray()
		if region == Campaign.Region.TEMPLE:
			for id in ["moss_vest", "ember_staff"]:
				if not obtained_equipment.has(id) and _grant_equipment(id):
					rewards.append(_ranked_gear_name(id, 1))
		if not rewards.is_empty():
			_notice("取得%s和 3 份素材。按 I 看裝備。" % "、".join(rewards), 4.0)
		else:
			_notice("從石匣取得 3 份工坊素材。", 4.0)


func _near(at: Vector2) -> bool:
	return absf(hunter.global_position.x - at.x) < 79 and absf(hunter.global_position.y - at.y) < 60


func _near_treasure() -> String:
	for chest in Armory.CHESTS[region]:
		if not obtained_equipment.has(chest[0]) and hunter.position.distance_to(Vector2(chest[1], chest[2])) < 50:
			return chest[0]
	return ""


func _near_cache() -> bool:
	return hunter.global_position.distance_to(landscape.cache.global_position) < 65


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
	arrows.clear()
	glyphs.clear()
	hit_effects.clear()
	# A disarmed guardian stays dead after victory. Keep its unclaimed weapon reachable.
	drops = drops.filter(func(drop: Dictionary) -> bool: return guardian_felled and drop.kind == "blade")
	hunter.respawn(_camp_start())
	camera.reset_smoothing()
	_spawn_enemies()
	restarting = false
	_notice("在營火旁醒來。這次遺失了 %d 份素材。" % lost, 3.8)


func _finish() -> void:
	completed = true
	hunter.set_physics_process(false)
	for monster: Monster in enemies:
		monster.set_physics_process(false)
	end_screen.show()


func _camp_start() -> Vector2:
	return START if region == Campaign.Region.TEMPLE else landscape.shrine.position + Vector2(48, -14)


func _sync_region_gate() -> void:
	match region:
		Campaign.Region.TEMPLE:
			landscape.portal_open = guardian_felled
		Campaign.Region.CORRIDOR:
			landscape.portal_open = lantern_found
			landscape.get_node("Darkness").visible = not lantern_found
			landscape.get_node("LightGate/Bar").visible = not lantern_found
			landscape.get_node("LightGate/Collision").set_deferred("disabled", lantern_found)
		Campaign.Region.COURT:
			landscape.portal_open = keeper_felled


func _queue_region(destination: int) -> void:
	if not transitioning:
		transitioning = true
		_change_region.call_deferred(destination)


func _change_region(destination: int) -> void:
	var checkpoint := _checkpoint_state()
	checkpoint["region"] = destination
	var next: PackedScene = load(Campaign.scene_path(checkpoint))
	if next == null or CampSave.write(checkpoint) != OK:
		transitioning = false
		_notice("無法保存下一區的進度，請重試。", 4.0)
		return
	get_tree().set_meta(CampSave.RESTORE_META, checkpoint)
	if get_tree().change_scene_to_packed(next) != OK:
		get_tree().remove_meta(CampSave.RESTORE_META)
		transitioning = false
		_notice("無法開啟下一區，請重試。", 4.0)


func _notice(message: String, seconds: float) -> void:
	notice_label.text = message
	notice_left = seconds


func _resize_backdrop() -> void:
	var texture_size := background.texture.get_size()
	var visible_size := get_viewport_rect().size + Vector2(220, 10)
	var cover := maxf(visible_size.x / texture_size.x, visible_size.y / texture_size.y)
	var editor_cover := 1372.0 / texture_size.x
	background.scale = backdrop_scale * (cover / editor_cover)


func _draw() -> void:
	for chest in Armory.CHESTS[region]:
		if not obtained_equipment.has(chest[0]):
			var at := Vector2(chest[1], chest[2])
			draw_texture_rect(CacheTexture, Rect2(at - Vector2(21, 24), Vector2(42, 24)), false)
			draw_circle(at - Vector2(0, 26), 3.5, Color(1.0, 0.79, 0.46, 0.62))
	for glyph in glyphs:
		var center: Vector2 = glyph.at - Vector2(0, 9)
		var charge := 1.0 - float(glyph.left) / 0.46
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
			EnemyEffects.bolt(self, at, projectile.direction, projectile.element, projectile.hostile, projectile.radius)
			continue
		var thorn: bool = projectile.weapon == "thorn_bow"
		draw_line(at - Vector2(projectile.direction * 26, 0), at,
			Color("#cbd98d") if thorn else Color("#ffe7a6"), 2, true)
		draw_circle(at, 2, Color("#efffc4") if thorn else Color("#fff7d7"))
	for drop: Dictionary in drops:
		var at: Vector2 = drop.at + Vector2(0, sin(elapsed * 4.8 + float(drop.at.x)) * 5.0)
		var color: Color = DROP_COLORS.get(drop.kind, Color("#dfb9ff"))
		draw_circle(at, 15, Color(color, 0.16))
		if drop.kind == "lantern":
			draw_texture_rect_region(MonsterArt.CRAB, Rect2(at - Vector2(10, 14), Vector2(20, 28)),
				MonsterArt.LANTERN_REGION)
		elif drop.kind == "blade":
			draw_line(at - Vector2(10, -7), at + Vector2(12, -8), color, 4, true)
		elif not Equipment.item(drop.kind).is_empty():
			draw_texture_rect(Equipment.ranked_icon(drop.kind, int(drop.rank)),
				Rect2(at - Vector2(13, 13), Vector2(26, 26)), false)
		else:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -10), at + Vector2(7, 0),
				at + Vector2(0, 10), at + Vector2(-7, 0)]), color)
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
	end_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_rows.add_child(end_prompt)
	end_screen.hide()
	_build_camp_menu(root)
	_build_gear_menu(root)
	_build_pause_menu(root)


func _build_camp_menu(root: Control) -> void:
	camp_menu = CenterContainer.new()
	root.add_child(camp_menu)
	camp_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := _panel(camp_menu)
	var theme_panel: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	theme_panel.bg_color = Color("#102123")
	theme_panel.border_color = Color("#977c52")
	theme_panel.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", theme_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	var title := _label(26, Color("#ffe0a1"))
	title.text = "營火與工坊"
	rows.add_child(title)
	camp_stock = _label(15, Color("#d8e4d4"))
	rows.add_child(camp_stock)
	rows.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	rows.add_child(columns)
	var services := _camp_section(columns, "營火服務")
	var cards := GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	services.add_child(cards)
	var flame := _camp_icon("M16 3C19 11 27 14 27 21a11 11 0 0 1-22 0c0-5 4-8 6-11 0 4 2 5 2 5Z", "#ffba69")
	var spirit := _camp_icon("M16 3 26 15 16 29 6 15Z M16 9v14 M12 15h8", "#99d9d4")
	camp_rest = _camp_card(cards, flame, "休息與存檔", _camp_heal)
	camp_level_up = _camp_card(cards, spirit, "", _level_up)
	camp_knife = _camp_card(cards, Equipment.icon("hunter_knife"), "", _upgrade_weapon.bind(false))
	camp_bow = _camp_card(cards, Equipment.icon("hunter_bow"), "", _upgrade_weapon.bind(true))
	forge_fang = _camp_card(cards, Equipment.icon("fang_dagger"), "製作蛛牙短刃", _forge_fang_dagger)

	var workshop := _camp_section(columns, "裝備工坊")
	camp_rank_items = ItemList.new()
	camp_rank_items.custom_minimum_size = Vector2(292, 166)
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
	camp_menu.hide()


func _camp_section(parent: Container, heading: String) -> VBoxContainer:
	var section := _panel(parent)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	section.add_child(rows)
	var title := _label(17, Color("#f1d294"))
	title.text = heading
	rows.add_child(title)
	return rows


func _camp_icon(path: String, color: String) -> Texture2D:
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 32 32"><path d="%s" fill="none" stroke="%s" stroke-width="2" stroke-linejoin="round"/></svg>' % [path, color])
	return ImageTexture.create_from_image(image)


func _camp_card(parent: Container, artwork: Texture2D, caption: String, action: Callable) -> Button:
	var button := _camp_button(parent, caption, action)
	button.custom_minimum_size = Vector2(138, 100)
	button.icon = artwork
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.add_theme_constant_override("icon_max_width", 41)
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#273e39") if state in ["hover", "pressed"] else Color("#192c2c")
		style.border_color = Color("#b59960") if state in ["hover", "pressed"] else Color("#546c60")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_top = 9
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, style)
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
		get_tree().change_scene_to_file("res://scenes/title.tscn")


func _save_camp() -> bool:
	_update_camp_menu()
	var saved := CampSave.write(_checkpoint_state()) == OK
	camp_stock.text += "\n" + ("已保存營火進度" if saved else "存檔失敗，請重試")
	return saved


func _checkpoint_state() -> Dictionary:
	cache_flags[region] = landscape.cache_open
	var state := {
		"region": region,
		"lantern_found": lantern_found,
		"keeper_felled": keeper_felled,
		"cache_flags": cache_flags,
		"materials": materials,
		"fangs": fangs,
		"soul_balance": soul_balance,
		"player_level": hunter.level,
		"inventory": inventory,
		"next_item_uid": next_item_uid,
		"obtained_equipment": obtained_equipment,
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
	if guardian_felled and unclaimed_blade_x >= 0.0:
		state["blade_x"] = unclaimed_blade_x
	return state


func _restore_camp(state: Dictionary) -> void:
	soul_balance = maxi(0, int(state.get("soul_balance", 0)))
	hunter.level = clampi(int(state.get("player_level", 0)), 0, Progression.MAX_LEVEL)
	materials = maxi(0, state.get("materials", 0))
	fangs = maxi(0, state.get("fangs", 0))
	hunter.stolen_blade = state.get("stolen_blade", false)
	for soul in state.get("souls", []):
		if SOUL_NAMES.has(soul) and not collected_souls.has(soul):
			collected_souls.append(soul)
	var equipped: String = state.get("equipped_soul", "")
	if collected_souls.has(equipped):
		hunter.equipped_soul = equipped
	_restore_inventory(state)
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
	cache_flags = state.get("cache_flags", {Campaign.Region.TEMPLE: state.get("cache_open", false)})
	landscape.cache_open = cache_flags.get(region, false)
	unclaimed_blade_x = state.get("blade_x", -1.0)
	if region == Campaign.Region.TEMPLE and guardian_felled and not hunter.stolen_blade and unclaimed_blade_x >= 0.0:
		_drop("blade", unclaimed_blade_x)


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
	if not camp_menu.visible or entry.is_empty():
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
	camp_selected_item.text = "背包沒有裝備" if entry.is_empty() else _entry_name(entry)
	camp_salvage.disabled = entry.is_empty()
	camp_salvage.text = "換取 %d 魂" % Progression.salvage_value(int(entry.get("rank", 0)))
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
	camp_level_up.text = "角色成長\n已達 Lv.10" if hunter.level >= Progression.MAX_LEVEL else (
		"Lv.%d → Lv.%d\n體力 +1  ·  %d 魂" % [hunter.level, hunter.level + 1, cost])
	var selected := _selected_camp_item()
	if selected == 0:
		selected = _equipped_uid("武器")
	camp_rank_items.clear()
	for entry in inventory:
		var item_name := _entry_name(entry)
		camp_rank_items.add_item(item_name, Equipment.ranked_icon(entry.item, int(entry.rank)))
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
	spirit_status.text = SOUL_NAMES.get(hunter.equipped_soul, "未裝備")
	soul_status.text = str(soul_balance)
	mana_status.get_parent().visible = hunter.staff_unlocked
	mana_status.text = "%d/%d" % [hunter.mana, Hunter.MAX_MANA]
	var flags := PackedStringArray()
	if _bag_full():
		flags.append("背包已滿")
	if hunter.pollen_left > 0:
		flags.append("鱗粉緩速")
	if region == Campaign.Region.CORRIDOR and lantern_found:
		flags.append("潮火提燈")
	status_flags.text = "    ".join(flags)
	status_flags.visible = not flags.is_empty()
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
	if _near(landscape.shrine.global_position):
		prompt_label.text = "E　打開營火與工坊選單"
	elif region == Campaign.Region.CORRIDOR and not lantern_found and absf(hunter.position.x - landscape.get_node("LightGate").position.x) < 108.0:
		prompt_label.text = "石閘上鎖　／　擊倒石蟹或射落牠的提燈"
	elif _near(landscape.portal.global_position):
		prompt_label.text = "E　查看石門"
	elif _near_cache() and not landscape.cache_open:
		prompt_label.text = "E　查看觀景台上的石匣"
	elif not _near_treasure().is_empty():
		prompt_label.text = "E　打開補給石匣"
	elif hunter.position.x > 677 and hunter.position.x < 805:
		prompt_label.text = "斷橋　／　裝備蜥翼，跳起後按住 Shift 滑翔"
	elif hunter.position.x > 2560 and not guardian_felled:
		prompt_label.text = "樹靈舉起木刃時，攻擊握刃處的亮點可以繳械"
	elif absf(hunter.position.x - MOTH_X) < 175.0 and not owned_equipment.has("scaleveil_hood"):
		prompt_label.text = "石鐘蛾腹部發光時，向上攻擊可打斷落粉。"


func _update_region_hud() -> void:
	if region == Campaign.Region.CORRIDOR:
		objective_label.text = Campaign.NAMES[region] + "\n" + (
			"穿過暗水道，往東走到排水出口。" if lantern_found else "擊倒石蟹，或在牠舉起提燈時射落提燈。")
	else:
		objective_label.text = Campaign.NAMES[region] + "\n" + (
			"調查東側主祭壇。" if keeper_felled else "避開雙段橫掃，蓄力時擊破護印。")
	prompt_label.text = ""
	if _near(landscape.shrine.global_position):
		prompt_label.text = "E　打開營火與工坊選單"
	elif _near(landscape.portal.global_position):
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
	var backdrop: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	backdrop.bg_color = Color("#0d1d1e")
	backdrop.border_color = Color("#887454")
	panel.add_theme_stylebox_override("panel", backdrop)
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
	gear_list.custom_minimum_size.y = 252
	gear_list.icon_mode = ItemList.ICON_MODE_TOP
	gear_list.fixed_icon_size = Vector2i(46, 46)
	gear_list.max_columns = 3
	gear_list.fixed_column_width = 124
	gear_list.same_column_width = true
	gear_list.max_text_lines = 1
	gear_list.add_theme_font_override("font", font)
	gear_list.add_theme_font_size_override("font_size", 14)
	gear_list.add_theme_constant_override("v_separation", 7)
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
	detail_rows.add_child(HSeparator.new())
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
	gear_apply = _camp_button(actions, "裝備　E", _apply_gear)
	gear_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destroy_item = _camp_button(actions, "銷毀　D", _ask_destroy_item)
	destroy_dialog = ConfirmationDialog.new()
	destroy_dialog.title = "銷毀裝備"
	destroy_dialog.get_ok_button().text = "銷毀"
	destroy_dialog.get_cancel_button().text = "取消"
	destroy_dialog.confirmed.connect(_destroy_gear_item)
	gear_menu.add_child(destroy_dialog)
	var close := _camp_button(actions, "返回探索　I / Esc", _set_gear_open.bind(false))
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_menu.hide()


func _build_gear_portrait(parent: HBoxContainer) -> void:
	var panel := _panel(parent)
	panel.custom_minimum_size.x = 306
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = Color("#152a29")
	panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	var heading := _label(16, Color("#d8e4d4"))
	heading.text = "目前裝備"
	rows.add_child(heading)

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
	gear_portrait.custom_minimum_size = Vector2(144, 248)
	gear_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_portrait_pose = Node2D.new()
	gear_portrait.add_child(gear_portrait_pose)
	gear_portrait_pose.draw.connect(_draw_gear_portrait)
	gear_portrait.resized.connect(_layout_gear_portrait)
	portrait_row.add_child(gear_portrait)

	var right := _gear_slot_column(portrait_row)
	_add_gear_slot(right, "身體")
	_add_gear_slot(right, "腿部")
	var weapon := _gear_slot_column(rows)
	weapon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_add_gear_slot(weapon, "武器")


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
	for entry in inventory:
		gear_ids.append(entry.item)
		gear_uids.append(int(entry.uid))
		var rank := int(entry.rank)
		var item_name := _entry_name(entry)
		var text := item_name
		if _is_equipped(entry):
			text += " ✓"
		var item_index := gear_list.add_item(text, Equipment.ranked_icon(entry.item, rank))
		gear_list.set_item_tooltip(item_index, item_name)
	if gear_uids.is_empty():
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
			return "最大體力　%d → %d" % [base, base + 1]
		"scaleveil_hood":
			return "鱗粉緩速　%.1f 秒 → %.1f 秒" % [Hunter.POLLEN_DURATION, Hunter.POLLEN_DURATION * 0.5]
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
