extends Node2D

const Hunter := preload("res://scripts/ruin_hunter.gd")
const Monster := preload("res://scripts/ruin_monster.gd")
const HitEffects := preload("res://scripts/ruin_hit_effects.gd")
const Landscape := preload("res://scripts/ruin_landscape.gd")
const CampSave := preload("res://scripts/camp_save.gd")
const Preferences := preload("res://scripts/game_preferences.gd")
const HunterAnimation := preload("res://scripts/hunter_animation.gd")
const Equipment := preload("res://scripts/ruin_equipment.gd")
const Bestiary := preload("res://scripts/ruin_bestiary.gd")
const Armory := preload("res://scripts/ruin_armory.gd")
const CacheTexture := preload("res://assets/environment/ruins/reliquary.png")
const Campaign := preload("res://scripts/campaign.gd")
const MonsterArt := preload("res://scripts/ruin_sprite_art.gd")
const START := Vector2(950, 526)
const MOTH_X := 2330.0
const SOUL_NAMES := {"lizard": "蜥翼", "spider": "蛛步"}
const DROP_COLORS := {
	"material": Color("#eac18c"), "lizard": Color("#a4f2d0"),
	"spider": Color("#ed9e96"), "blade": Color("#ffda84"),
}

var hunter: Hunter
var hit_effects: HitEffects
@onready var landscape: Landscape = $Landscape
var camera: Camera2D
@onready var background: Sprite2D = $Backdrop/Temple
@onready var backdrop_origin := background.position
@onready var backdrop_scale := background.scale
var enemies: Array[Monster] = []
var drops: Array[Dictionary] = []
var arrows: Array[Dictionary] = []
var glyphs: Array[Dictionary] = []
var fang_target: Monster
var fang_hits := 0
var collected_souls: Array[String] = []
var materials := 0
var fangs := 0
var forge_fang: Button
var owned_equipment: Array[String] = []
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
var loadout_label: Label
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
var pause_menu: CenterContainer
var pause_volume: HSlider
var pause_fullscreen: CheckButton
var gear_menu: CenterContainer
var gear_list: ItemList
var gear_slot_images: Dictionary = {}
var gear_name: Label
var gear_values: Label
var gear_detail: Label
var gear_apply: Button
var gear_ids: Array[String] = []
var font: SystemFont


func _ready() -> void:
	rng.randomize()
	_resize_backdrop()
	get_viewport().size_changed.connect(_resize_backdrop)

	hunter = Hunter.new()
	hunter.name = "Hunter"
	hunter.position = _camp_start()
	hunter.attacked.connect(_attack)
	hunter.cast.connect(_cast)
	hunter.defeated.connect(_on_hunter_defeated)
	add_child(hunter)
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
		if region == Campaign.Region.COURT:
			get_tree().change_scene_to_file("res://scenes/title.tscn")
		else:
			_queue_region(region + 1)
		get_viewport().set_input_as_handled()


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
		arrows.append({"at": origin, "direction": direction, "damage": damage, "left": 0.55,
			"weapon": weapon, "pierce": int(weapon == "thorn_bow"), "hit_ids": []})
		return
	var reach: float = Armory.WEAPONS[weapon][4] if Armory.WEAPONS.has(weapon) else 51.0
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
		_hit_monster(monster, applied, weapon_hit, hitbox.intersection(bounds).get_center(), direction, false, weapon)
		hit_count += 1
		if hit_count >= (2 if weapon == "gate_halberd" else 1):
			break


func _cast(origin: Vector2, direction: float, weapon: String) -> void:
	if weapon == "scribe_staff":
		var x := clampf(origin.x + direction * 129.0, 54.0, 3230.0)
		var vertical_ray := PhysicsRayQueryParameters2D.create(Vector2(x, origin.y), Vector2(x, origin.y + 280.0), 1)
		var ground := get_world_2d().direct_space_state.intersect_ray(vertical_ray)
		if not ground.is_empty():
			glyphs.append({"at": ground.position, "left": 0.46, "damage": hunter.weapon_damage(weapon), "direction": direction})
		return
	arrows.append({"at": origin, "direction": direction, "damage": Hunter.STAFF_DAMAGE, "left": 0.44,
		"spell": true, "weapon": weapon, "hit_ids": []})


func _launch_enemy_projectile(origin: Vector2, direction: float, effect: String) -> void:
	arrows.append({"at": origin, "direction": direction, "damage": 1, "left": 0.6, "hostile": effect})


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
		var from: Vector2 = arrow.at
		var spell: bool = arrow.get("spell", false)
		var hostile: String = arrow.get("hostile", "")
		var speed := 850.0 if hostile.is_empty() else (590.0 if hostile == "arrow" else 465.0)
		var velocity := Vector2(arrow.direction * 710.0, -245.0) if spell else Vector2(arrow.direction * speed, 0)
		var to := from + velocity * delta
		var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
		var wall := get_world_2d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty():
			to = wall.position
		var hitbox := Rect2(Vector2(minf(from.x, to.x), from.y - 4), Vector2(absf(to.x - from.x), 8))
		if spell:
			hitbox = Rect2(from, Vector2.ZERO).expand(to).grow(5)
		var hit := false
		if not hostile.is_empty():
			var height := Hunter.CROUCH_HEIGHT if hunter.crouching else Hunter.STANDING_HEIGHT
			hit = hitbox.intersects(Rect2(hunter.position - Vector2(12, height), Vector2(24, height)))
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
		projectile: bool = false, weapon: String = "") -> void:
	monster.receive_hit(damage, weapon_hit, projectile, weapon, direction)
	if not projectile and not monster.is_queued_for_deletion():
		if hunter.gear.get("手部") == "stonegrip_gloves" and monster.attack_kind == "roll" and monster.recovery > 0.0:
			monster.velocity.x += direction * 110.0
		elif hunter.gear.get("手部") == "hardroot_bracers" and not hunter.is_on_floor():
			monster.velocity.x += direction * 85.0
	hit_effects.impact(point, direction, weapon_hit)


func _on_monster_felled(monster: Monster) -> void:
	enemies.erase(monster)
	var x := monster.position.x
	var loot: String = Bestiary.DROPS.get(monster.species, "")
	if not loot.is_empty() and not owned_equipment.has(loot) and not _has_drop(loot):
		_drop(loot, x - 12)
	if monster.species == "ash_scribe" and not owned_equipment.has("scribe_staff") and not _has_drop("scribe_staff"):
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
			if not owned_equipment.has("scaleveil_hood") and not _has_drop("scaleveil_hood"):
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


func _on_monster_disarmed(monster: Monster) -> void:
	if monster.species == "lantern_crab":
		if not lantern_found and not _has_drop("lantern"):
			_drop("lantern", monster.position.x + monster.facing * 72.0)
			_notice("提燈落在地上。靠近拾取，用它打開暗水道。", 4.0)
		return
	if monster.species in ["thorn_archer", "shield_heron"]:
		var item := "thorn_bow" if monster.species == "thorn_archer" else "earthen_armor"
		if not owned_equipment.has(item) and not _has_drop(item):
			_drop(item, monster.position.x + monster.facing * 50.0)
		return
	if monster.species == "seal_keeper":
		_notice("護印已破，趁硬直反擊。", 3.0)
		return
	if hunter.stolen_blade or _has_drop("blade"):
		return
	unclaimed_blade_x = monster.position.x + monster.facing * 104
	_drop("blade", unclaimed_blade_x)
	_notice("樹靈的木刃掉在地上了。", 3.0)


func _has_drop(kind: String) -> bool:
	for drop: Dictionary in drops:
		if drop.kind == kind:
			return true
	return false


func _drop(kind: String, x: float, amount: int = 1) -> void:
	drops.append({"kind": kind, "at": Vector2(clampf(x, 736 if region == Campaign.Region.TEMPLE else 60, 3240), Landscape.FLOOR_Y - 27),
		"amount": amount, "spawn": elapsed})


func _collect_drops() -> void:
	for index in range(drops.size() - 1, -1, -1):
		var drop := drops[index]
		if elapsed - drop.spawn < 0.22 or (hunter.position - Vector2(0, 25)).distance_to(drop.at) > 43:
			continue
		drops.remove_at(index)
		match drop.kind:
			"material":
				materials += int(drop.amount)
			"blade":
				hunter.stolen_blade = true
				unclaimed_blade_x = -1.0
				_grant_equipment("root_blade")
				_notice("取得樹靈木刃。按 I 換裝。", 3.0)
			"fang_material":
				fangs += 1
				_notice("取得蛛牙。回營火可製作蛛牙短刃。", 3.0)
			"lantern":
				lantern_found = true
				_sync_region_gate()
				_notice("取得潮火提燈，暗水道已照亮。", 4.0)
			"scaleveil_hood":
				_grant_equipment("scaleveil_hood")
				_notice("取得鱗紗兜帽。按 I 看裝備。", 3.0)
			_:
				if SOUL_NAMES.has(drop.kind):
					if not collected_souls.has(drop.kind):
						collected_souls.append(drop.kind)
					_notice("拾得%s之魂。按 F 裝備，按住 Shift 使用魂技。" % SOUL_NAMES[drop.kind], 4.0)
				elif not Equipment.item(drop.kind).is_empty():
					_grant_equipment(drop.kind)
					_notice("取得%s。按 I 看裝備。" % Equipment.item(drop.kind)[0], 3.0)


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
		_grant_equipment(loot)
		_notice("石匣內有%s。按 I 看裝備。" % Equipment.item(loot)[0], 4.0)
	elif _near(landscape.shrine.global_position):
		var first_visit := not owned_equipment.has("linen_hood")
		_grant_equipment("linen_hood")
		_grant_equipment("hunter_wraps")
		_set_camp_open(true)
		if first_visit:
			_notice("取得營火布兜與獵人纏手。返回探索後按 I 看裝備。", 4.0)
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
		landscape.cache_open = true
		materials += 3
		if region == Campaign.Region.TEMPLE:
			_grant_equipment("moss_vest")
			_grant_equipment("ember_staff")
			_notice("取得苔織獵衣、餘火魔法杖和 3 份素材。按 I 看裝備。", 4.0)
		else:
			_notice("從石匣取得 3 份工坊素材。", 4.0)


func _near(at: Vector2) -> bool:
	return absf(hunter.global_position.x - at.x) < 79 and absf(hunter.global_position.y - at.y) < 60


func _near_treasure() -> String:
	for chest in Armory.CHESTS[region]:
		if not owned_equipment.has(chest[0]) and hunter.position.distance_to(Vector2(chest[1], chest[2])) < 50:
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
		if not owned_equipment.has(chest[0]):
			var at := Vector2(chest[1], chest[2])
			draw_texture_rect(CacheTexture, Rect2(at - Vector2(21, 24), Vector2(42, 24)), false)
			draw_circle(at - Vector2(0, 26), 3.5, Color(1.0, 0.79, 0.46, 0.62))
	for glyph in glyphs:
		draw_arc(glyph.at - Vector2(0, 5), 30.0, 0, TAU, 32, Color("#9cc9ee"), 2.0, true)
	for projectile: Dictionary in arrows:
		var at: Vector2 = projectile.at
		if projectile.get("spell", false):
			draw_circle(at, 12, Color(0.95, 0.33, 0.11, 0.33))
			draw_circle(at, 6, Color("#ffd078"))
			continue
		var ink := Color("#ffe7a6") if not projectile.has("hostile") else Color("#81c4b5")
		draw_line(at - Vector2(projectile.direction * 26, 0), at, ink, 2, true)
		draw_circle(at, 2, Color("#fff7d7"))
	for drop: Dictionary in drops:
		var at: Vector2 = drop.at + Vector2(0, sin(elapsed * 4.8 + float(drop.at.x)) * 5.0)
		var color: Color = DROP_COLORS.get(drop.kind, Color("#dfb9ff"))
		draw_circle(at, 15, Color(color, 0.16))
		if drop.kind == "lantern":
			draw_texture_rect_region(MonsterArt.CRAB, Rect2(at - Vector2(10, 14), Vector2(20, 28)),
				MonsterArt.LANTERN_REGION)
		elif drop.kind == "blade":
			draw_line(at - Vector2(10, -7), at + Vector2(12, -8), color, 4, true)
		else:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -10), at + Vector2(7, 0),
				at + Vector2(0, 10), at + Vector2(-7, 0)]), color)


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
	var status_rows := VBoxContainer.new()
	status_rows.add_theme_constant_override("separation", 4)
	status.add_child(status_rows)
	health_label = _label(17, Color("#ffc19b"))
	status_rows.add_child(health_label)
	loadout_label = _label(15, Color("#d8e4d4"))
	status_rows.add_child(loadout_label)

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
	panel.custom_minimum_size.x = 390
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 9)
	panel.add_child(rows)
	var title := _label(25, Color("#ffe0a1"))
	title.text = "營火與工坊"
	rows.add_child(title)
	camp_stock = _label(16, Color("#d8e4d4"))
	rows.add_child(camp_stock)
	camp_rest = _camp_button(rows, "休息、恢復體力與存檔", _camp_heal)
	camp_knife = _camp_button(rows, "", _upgrade_weapon.bind(false))
	camp_bow = _camp_button(rows, "", _upgrade_weapon.bind(true))
	forge_fang = _camp_button(rows, "用蛛牙製作短刃", _forge_fang_dagger)
	_camp_button(rows, "返回探索　Esc", _set_camp_open.bind(false))
	if region > Campaign.Region.TEMPLE:
		_camp_button(rows, "返回上一區營火", _queue_region.bind(region - 1))
	_camp_button(rows, "存檔並返回開始頁面", _camp_return_to_title)
	camp_menu.hide()


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
	materials = maxi(0, state.get("materials", 0))
	fangs = maxi(0, state.get("fangs", 0))
	hunter.stolen_blade = state.get("stolen_blade", false)
	if hunter.stolen_blade:
		_grant_equipment("root_blade")
	for soul in state.get("souls", []):
		if SOUL_NAMES.has(soul) and not collected_souls.has(soul):
			collected_souls.append(soul)
	var equipped: String = state.get("equipped_soul", "")
	if collected_souls.has(equipped):
		hunter.equipped_soul = equipped
	for item in state.get("owned_equipment", []):
		if not Equipment.item(item).is_empty():
			_grant_equipment(item)
	if state.get("cache_open", false):
		_grant_equipment("moss_vest")
		_grant_equipment("ember_staff")
	for slot in state.get("gear", {}):
		var item = state.gear[slot]
		if owned_equipment.has(item) and Equipment.item(item)[1] == slot and slot != "武器":
			hunter.gear[slot] = item
	var previous_weapon: String = state.get("weapon", "hunter_bow" if state.get("with_bow", false) else "hunter_knife")
	if hunter.stolen_blade and previous_weapon == "hunter_knife" and not state.get("owned_equipment", []).has("root_blade"):
		previous_weapon = "root_blade"
	hunter.select_weapon(previous_weapon)
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
	if fangs > 0 and not owned_equipment.has("fang_dagger"):
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


func _update_camp_menu() -> void:
	camp_stock.text = "素材 %d　｜　體力 %d / %d" % [materials, hunter.health, hunter.max_health()]
	_update_upgrade_button(camp_knife, "近戰武器", hunter.knife_level)
	_update_upgrade_button(camp_bow, "獵弓", hunter.bow_level)
	forge_fang.visible = fangs > 0 and not owned_equipment.has("fang_dagger")


func _update_upgrade_button(button: Button, weapon: String, level: int) -> void:
	button.disabled = level >= 2 or materials < 2 + level
	button.text = "%s +%d　已達上限" % [weapon, level] if level >= 2 else (
		"%s +%d → +%d　消耗 %d 素材" % [weapon, level, level + 1, 2 + level]
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


func _update_hud() -> void:
	var soul_name := String(SOUL_NAMES.get(hunter.equipped_soul, "未裝備"))
	var weapon_name := _gear_item_name(hunter.selected_weapon())
	health_label.text = "體力  %s%s" % ["◆".repeat(hunter.health), "◇".repeat(hunter.max_health() - hunter.health)]
	var level := hunter.bow_level if hunter.with_bow else (0 if hunter.with_staff else hunter.knife_level)
	var upgrade := (" +%d" % level) if level > 0 else ""
	loadout_label.text = "%s%s　｜　%s　｜　素材 %d" % [weapon_name, upgrade, soul_name, materials]
	if hunter.staff_unlocked:
		loadout_label.text += "　｜　法力 %d/%d" % [hunter.mana, Hunter.MAX_MANA]
	if hunter.pollen_left > 0:
		loadout_label.text += "　｜　鱗粉緩速"
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
			"穿過暗水道，往東走到排水出口。" if lantern_found else "石蟹舉起提燈時，向亮點射擊。")
		if lantern_found:
			loadout_label.text += "　｜　潮火提燈"
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


func _grant_equipment(id: String) -> void:
	if not owned_equipment.has(id):
		owned_equipment.append(id)
	if id == "ember_staff":
		hunter.staff_unlocked = true
	if Equipment.item(id)[1] == "武器" and not hunter.unlocked_weapons.has(id):
		hunter.unlocked_weapons.append(id)


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

	var inventory := VBoxContainer.new()
	inventory.custom_minimum_size.x = 410
	inventory.add_theme_constant_override("separation", 8)
	columns.add_child(inventory)
	var inventory_label := _label(16, Color("#d8e4d4"))
	inventory_label.text = "持有物品"
	inventory.add_child(inventory_label)
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
	inventory.add_child(gear_list)

	var details := _panel(inventory)
	var detail_rows := VBoxContainer.new()
	detail_rows.add_theme_constant_override("separation", 4)
	details.add_child(detail_rows)
	gear_name = _label(18, Color("#f4d698"))
	detail_rows.add_child(gear_name)
	gear_values = _label(16, Color("#f2e9d2"))
	detail_rows.add_child(gear_values)
	gear_detail = _label(14, Color("#adbfba"))
	detail_rows.add_child(gear_detail)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	inventory.add_child(actions)
	gear_apply = _camp_button(actions, "裝備", _apply_gear)
	gear_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var portrait := TextureRect.new()
	portrait.name = "HunterPortrait"
	var frame := AtlasTexture.new()
	frame.atlas = HunterAnimation.FRAMES["idle"]
	frame.region = Rect2(151, 0, 133, 182)
	frame.filter_clip = true
	portrait.texture = frame
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(144, 248)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_row.add_child(portrait)

	var right := _gear_slot_column(portrait_row)
	_add_gear_slot(right, "身體")
	_add_gear_slot(right, "腿部")
	var weapon := _gear_slot_column(rows)
	weapon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_add_gear_slot(weapon, "武器")


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
		_refresh_gear(hunter.selected_weapon())
		gear_list.grab_focus()
	else:
		camp_closed_frame = Engine.get_physics_frames() + 1


func _refresh_gear(selected: String) -> void:
	for slot in gear_slot_images:
		var id: String = hunter.selected_weapon() if slot == "武器" else hunter.gear.get(slot, "")
		var icon: TextureRect = gear_slot_images[slot]
		icon.texture = _gear_icon(id)
		icon.tooltip_text = "%s　%s" % [slot, _gear_item_name(id) if not id.is_empty() else "未裝備"]
	gear_list.clear()
	gear_ids.assign(Equipment.STARTING_WEAPONS)
	for id: String in owned_equipment:
		if not gear_ids.has(id):
			gear_ids.append(id)
	for id in gear_ids:
		var text := _gear_item_name(id)
		if _is_equipped(id):
			text += " ✓"
		var index := gear_list.add_item(text, _gear_icon(id))
		gear_list.set_item_tooltip(index, _gear_item_name(id))
	var index := maxi(0, gear_ids.find(selected))
	gear_list.select(index)
	gear_list.ensure_current_is_visible()
	_show_gear(index)


func _is_equipped(id: String) -> bool:
	var slot: String = Equipment.item(id)[1]
	return hunter.selected_weapon() == id if slot == "武器" else hunter.gear.get(slot) == id


func _show_gear(index: int) -> void:
	var id := gear_ids[index]
	gear_name.text = "%s　·　%s" % [_gear_item_name(id), Equipment.item(id)[1]]
	gear_values.text = _gear_item_values(id)
	gear_detail.text = Equipment.item(id)[2]
	gear_apply.disabled = Equipment.item(id)[1] == "武器" and _is_equipped(id)
	gear_apply.text = "卸下" if _is_equipped(id) and not gear_apply.disabled else "裝備"


func _gear_icon(id: String) -> Texture2D:
	return Equipment.icon(id)


func _gear_item_name(id: String) -> String:
	if id == "hunter_knife":
		return "短刀"
	return Equipment.item(id)[0]


func _gear_item_values(id: String) -> String:
	match id:
		"linen_hood":
			return "最大體力　%d → %d" % [Hunter.MAX_HEALTH, Hunter.MAX_HEALTH + 1]
		"scaleveil_hood":
			return "鱗粉緩速　%.1f 秒 → %.1f 秒" % [Hunter.POLLEN_DURATION, Hunter.POLLEN_DURATION * 0.5]
		"moss_vest":
			return "每次休息後　格擋 1 次傷害"
		"hunter_wraps":
			return "近戰攻擊週期　%.2f 秒 → %.2f 秒" % [Hunter.KNIFE_DURATION, Hunter.WRAPS_KNIFE_DURATION]
		_:
			if Equipment.item(id)[1] != "武器":
				return Equipment.item(id)[1] + "裝備"
			var stats := "傷害 %d　｜　攻擊週期 %.2f 秒" % [hunter.weapon_damage(id), hunter.weapon_period(id)]
			if id in ["ember_staff", "scribe_staff"]:
				stats += "　｜　法力 %d" % Hunter.STAFF_MANA_COST
			return stats


func _apply_gear() -> void:
	var selection := gear_list.get_selected_items()
	if selection.is_empty():
		return
	var id := gear_ids[selection[0]]
	var slot: String = Equipment.item(id)[1]
	if slot == "武器":
		hunter.select_weapon(id)
	elif _is_equipped(id):
		hunter.gear.erase(slot)
	else:
		hunter.gear[slot] = id
	hunter.health = mini(hunter.health, hunter.max_health())
	_refresh_gear(id)
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
