extends Node2D

const Hunter := preload("res://scripts/ruin_hunter.gd")
const Monster := preload("res://scripts/ruin_monster.gd")
const Landscape := preload("res://scripts/ruin_landscape.gd")
const BACKDROP := preload("res://assets/environment/ancient_temple.png")
const START := Vector2(950, 526)
const SOUL_NAMES := {"lizard": "蜥翼", "spider": "蛛步"}
const DROP_COLORS := {
	"material": Color("#eac18c"), "lizard": Color("#a4f2d0"),
	"spider": Color("#ed9e96"), "blade": Color("#ffda84"),
}

var hunter: Hunter
var landscape: Landscape
var camera: Camera2D
var background: TextureRect
var enemies: Array[Monster] = []
var drops: Array[Dictionary] = []
var arrows: Array[Dictionary] = []
var collected_souls: Array[String] = []
var materials := 0
var guardian_felled := false
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
var font: SystemFont


func _ready() -> void:
	rng.randomize()
	_build_backdrop()
	landscape = Landscape.new()
	add_child(landscape)
	for bounds: Rect2 in Landscape.STONES:
		_add_stone_collider(bounds)

	hunter = Hunter.new()
	hunter.name = "Hunter"
	hunter.position = START
	hunter.attacked.connect(_attack)
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
	_spawn_enemies()
	_build_hud()
	_notice("前世的記憶停在墜落那一刻。神殿深處也許有回家的線索。", 5.0)


func _process(delta: float) -> void:
	elapsed += delta
	background.position.x = -110.0 - clampf((hunter.position.x - 950.0) * 0.050, -95, 95)
	notice_left = maxf(0.0, notice_left - delta)
	notice_label.visible = notice_left > 0 and not completed
	if not completed:
		_update_hud()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if completed or restarting or camp_menu.visible:
		return
	if hunter.position.y > 790:
		_on_hunter_defeated()
		return
	_update_arrows(delta)
	_collect_drops()
	if Input.is_action_just_pressed("hunt_equip"):
		_equip_next_soul()
	if Input.is_action_just_pressed("hunt_interact") and Engine.get_physics_frames() > camp_closed_frame:
		_interact()


func _input(event: InputEvent) -> void:
	if camp_menu.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("hunt_interact")):
		_set_camp_open(false)
		get_viewport().set_input_as_handled()
		return
	if completed and event.is_action_pressed("hunt_interact"):
		get_tree().reload_current_scene()


func _spawn_enemies() -> void:
	_add_monster("spider", 1310)
	_add_monster("lizard", 1880)
	_add_monster("spider", 2240)
	if not guardian_felled:
		_add_monster("treant", 2840)


func _add_monster(species: String, x: float) -> void:
	var monster := Monster.new()
	monster.configure(species, Vector2(x, Landscape.FLOOR_Y), hunter)
	monster.felled.connect(_on_monster_felled)
	monster.disarmed.connect(_on_monster_disarmed)
	enemies.append(monster)
	add_child(monster)


func _add_stone_collider(bounds: Rect2) -> void:
	var body := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	collision.shape = shape
	body.position = bounds.get_center()
	body.add_child(collision)
	add_child(body)


func _attack(origin: Vector2, direction: float, ranged: bool, damage: int) -> void:
	if ranged:
		arrows.append({"at": origin, "direction": direction, "damage": damage, "left": 0.55})
		return
	var hitbox := Rect2(origin.x if direction > 0 else origin.x - 51.0, origin.y - 17, 51, 42)
	for monster: Monster in enemies.duplicate():
		if monster.armed and monster.windup > 0 and hitbox.intersects(monster.weapon_hitbox()):
			monster.receive_hit(damage, true)
		elif hitbox.intersects(monster.body_hitbox()):
			monster.receive_hit(damage, false)


func _update_arrows(delta: float) -> void:
	for index in range(arrows.size() - 1, -1, -1):
		var arrow := arrows[index]
		var from: Vector2 = arrow.at
		var to := from + Vector2(arrow.direction * 850.0 * delta, 0)
		var ray := PhysicsRayQueryParameters2D.create(from, to, 1)
		var wall := get_world_2d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty():
			to = wall.position
		var hitbox := Rect2(Vector2(minf(from.x, to.x), from.y - 4), Vector2(absf(to.x - from.x), 8))
		var hit := _arrow_hits_monster(hitbox, arrow.direction, arrow.damage)
		arrow.left -= delta
		if hit or not wall.is_empty() or arrow.left <= 0:
			arrows.remove_at(index)
		else:
			arrow.at = to


func _arrow_hits_monster(hitbox: Rect2, direction: float, damage: int) -> bool:
	var nearest: Monster
	var nearest_x := INF
	var hits_weapon := false
	for monster: Monster in enemies:
		var weapon_hit := monster.armed and monster.windup > 0 and hitbox.intersects(monster.weapon_hitbox())
		if not weapon_hit and not hitbox.intersects(monster.body_hitbox()):
			continue
		var hit_x := monster.weapon_hitbox().get_center().x if weapon_hit else monster.position.x
		if hit_x * direction < nearest_x:
			nearest = monster
			nearest_x = hit_x * direction
			hits_weapon = weapon_hit
	if nearest == null:
		return false
	nearest.receive_hit(damage, hits_weapon)
	return true


func _on_monster_felled(monster: Monster) -> void:
	enemies.erase(monster)
	var x := monster.position.x
	match monster.species:
		"spider":
			if rng.randf() < 0.37 and not collected_souls.has("spider") and not _has_drop("spider"):
				_drop("spider", x - 12)
		"lizard":
			if not collected_souls.has("lizard"):
				_drop("lizard", x - 12)
		"treant":
			guardian_felled = true
			landscape.portal_open = true
			_drop("material", x + 19, 3)
			_notice("樹靈倒下了。回到神殿入口，借蜥翼滑過斷橋。", 4.0)
			return
	if rng.randf() < 0.76:
		_drop("material", x + 15, 2 if monster.species == "lizard" else 1)


func _on_monster_disarmed(monster: Monster) -> void:
	if hunter.stolen_blade or _has_drop("blade"):
		return
	_drop("blade", monster.position.x + monster.facing * 104)
	_notice("樹靈的木刃掉在地上了。", 3.0)


func _has_drop(kind: String) -> bool:
	for drop: Dictionary in drops:
		if drop.kind == kind:
			return true
	return false


func _drop(kind: String, x: float, amount: int = 1) -> void:
	drops.append({"kind": kind, "at": Vector2(clampf(x, 736, 3280), Landscape.FLOOR_Y - 27),
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
				_notice("取得樹靈木刃。近戰傷害提升。", 3.0)
			_:
				collected_souls.append(drop.kind)
				_notice("拾得%s之魂。按 F 裝備，按住 Shift 使用魂技。" % SOUL_NAMES[drop.kind], 4.0)


func _equip_next_soul() -> void:
	if collected_souls.is_empty():
		return
	var slot := collected_souls.find(hunter.equipped_soul)
	hunter.equipped_soul = collected_souls[(slot + 1) % collected_souls.size()]
	var hint := "跳起後按住 Shift 滑翔。" if hunter.equipped_soul == "lizard" else "貼牆時按住方向與 Shift 攀爬。"
	_notice("已裝備%s。%s" % [SOUL_NAMES[hunter.equipped_soul], hint], 3.0)


func _interact() -> void:
	if _near(Landscape.SHRINE_X):
		_set_camp_open(true)
	elif _near(Landscape.PORTAL_X):
		if guardian_felled:
			_finish()
		else:
			_notice("石門上的枝紋在發光。還有一名守門者活著。", 3.0)
	elif _near_cache() and not landscape.cache_open:
		landscape.cache_open = true
		materials += 3
		_notice("石匣裡存有 3 份素材。匣蓋刻著與西側石門相同的名字。", 4.0)


func _near(x: float) -> bool:
	return absf(hunter.position.x - x) < 79 and absf(hunter.position.y - Landscape.FLOOR_Y) < 60


func _near_cache() -> bool:
	return hunter.position.distance_to(Landscape.OVERLOOK) < 65


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
	# A disarmed guardian stays dead after victory. Keep its unclaimed weapon reachable.
	drops = drops.filter(func(drop: Dictionary) -> bool: return guardian_felled and drop.kind == "blade")
	hunter.respawn(START)
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


func _notice(message: String, seconds: float) -> void:
	notice_label.text = message
	notice_left = seconds


func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	background = TextureRect.new()
	background.texture = BACKDROP
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color("#a9c1bf")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(background)
	_resize_backdrop()
	get_viewport().size_changed.connect(_resize_backdrop)


func _resize_backdrop() -> void:
	background.size = get_viewport_rect().size + Vector2(220, 10)


func _draw() -> void:
	for projectile: Dictionary in arrows:
		var at: Vector2 = projectile.at
		draw_line(at - Vector2(projectile.direction * 26, 0), at, Color("#ffe7a6"), 2, true)
		draw_circle(at, 2, Color("#fff7d7"))
	for drop: Dictionary in drops:
		var at: Vector2 = drop.at + Vector2(0, sin(elapsed * 4.8 + float(drop.at.x)) * 5.0)
		var color: Color = DROP_COLORS[drop.kind]
		draw_circle(at, 15, Color(color, 0.16))
		if drop.kind == "blade":
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
	help.text = "A / D 跑步　 Ctrl 慢走　 S 蹲下　 空白鍵 跳躍　 J 攻擊　 Q 換武器　 F 裝魂　 Shift 魂技　 E 互動"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_rows.add_child(help)

	end_screen = CenterContainer.new()
	root.add_child(end_screen)
	end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := _panel(end_screen)
	var card_rows := VBoxContainer.new()
	card_rows.add_theme_constant_override("separation", 12)
	card.add_child(card_rows)
	var title := _label(32, Color("#ffe0a1"))
	title.text = "斷橋另一端"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_rows.add_child(title)
	var story := _label(18, Color("#e1e9d7"))
	story.text = "石門認得你前世的名字。\n門後的道路通往更古老的世界。"
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_rows.add_child(story)
	var replay := _label(16, Color("#b6c9bc"))
	replay.text = "E　再次踏入遺跡"
	replay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_rows.add_child(replay)
	end_screen.hide()
	_build_camp_menu(root)


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
	camp_rest = _camp_button(rows, "休息並恢復體力", _camp_heal)
	camp_knife = _camp_button(rows, "", _upgrade_weapon.bind(false))
	camp_bow = _camp_button(rows, "", _upgrade_weapon.bind(true))
	_camp_button(rows, "返回探索　Esc", _set_camp_open.bind(false))
	camp_menu.hide()


func _camp_button(rows: VBoxContainer, label: String, action: Callable) -> Button:
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
	hunter.set_physics_process(not open)
	for monster: Monster in enemies:
		monster.set_physics_process(not open)
	if open:
		_update_camp_menu()
		camp_rest.grab_focus()
	else:
		camp_closed_frame = Engine.get_physics_frames() + 1


func _camp_heal() -> void:
	hunter.health = Hunter.MAX_HEALTH
	_update_camp_menu()


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
	camp_stock.text = "素材 %d　｜　體力 %d / %d" % [materials, hunter.health, Hunter.MAX_HEALTH]
	_update_upgrade_button(camp_knife, "近戰武器", hunter.knife_level)
	_update_upgrade_button(camp_bow, "獵弓", hunter.bow_level)


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
	var weapon_name := "獵弓" if hunter.with_bow else ("樹靈木刃" if hunter.stolen_blade else "短刀")
	health_label.text = "體力  %s%s" % ["◆".repeat(hunter.health), "◇".repeat(Hunter.MAX_HEALTH - hunter.health)]
	var level := hunter.bow_level if hunter.with_bow else hunter.knife_level
	var upgrade := (" +%d" % level) if level > 0 else ""
	loadout_label.text = "%s%s　｜　%s　｜　素材 %d" % [weapon_name, upgrade, soul_name, materials]
	if not collected_souls.has("lizard"):
		objective_label.text = "崩塌神殿\n往東狩獵滑翔蜥蜴，取得蜥翼之魂。"
	elif not guardian_felled:
		objective_label.text = "崩塌神殿\n穿過地下通道，打倒東側的樹靈。"
	else:
		objective_label.text = "崩塌神殿\n回到西側斷橋，用蜥翼抵達石門。"

	prompt_label.text = ""
	if _near(Landscape.SHRINE_X):
		prompt_label.text = "E　打開營火與工坊選單"
	elif _near(Landscape.PORTAL_X):
		prompt_label.text = "E　查看石門"
	elif _near_cache() and not landscape.cache_open:
		prompt_label.text = "E　查看觀景台上的石匣"
	elif hunter.position.x > 677 and hunter.position.x < 805:
		prompt_label.text = "斷橋　／　裝備蜥翼，跳起後按住 Shift 滑翔"
	elif hunter.position.x > 2560 and not guardian_felled:
		prompt_label.text = "樹靈舉起木刃時，攻擊握刃處的亮點可以繳械"
