extends SceneTree

const Ruins := preload("res://scripts/ruins.gd")

var failed := false


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://scenes/ruins.tscn")
	await scene_changed
	var level: Ruins = current_scene
	var hunter := level.hunter
	for enemy in level.enemies:
		enemy.queue_free()
	level.enemies.clear()
	hunter.level = 2
	hunter.rest()
	hunter.select_weapon("hunter_bow")
	hunter.bow_level = 1
	hunter.equipped_soul = "spider"
	level.soul_balance = 39
	await frames(55)
	check(level.health_hearts.health == 8 and level.health_hearts.capacity == 8, "eight full health hearts at Lv.2")
	hunter.hurt(hunter.position.x - 10, 6)
	await frames(32)
	check(level.health_label.text == "體力 2/8" and level.health_hearts.health == 2
		and level.health_hearts.capacity == 8, "damage leaves two filled and six empty hearts")
	check(level.weapon_status.text == "+1木質獵弓" and level.spirit_status.text == "蛛步"
		and level.soul_status.text == "39" and hunter.bow_level == 1,
		"weapon shows the ranked name while the material upgrade remains active")
	await frames(52)
	level._grant_equipment("ember_staff")
	hunter.select_weapon("ember_staff")
	hunter.mana = 2
	hunter.apply_pollen()
	await frames(25)
	check(level.mana_status.is_visible_in_tree() and level.mana_status.text == "2/4"
		and level.status_flags.text == "鱗粉緩速", "mana and contextual effects display independently")
	hunter.level = 10
	hunter.rest()
	await frames(42)
	check(level.health_hearts.health == 16 and level.health_hearts.capacity == 16, "level cap and healing update the heart row")
	if DisplayServer.get_name() != "headless":
		root.get_node("GameMusic").play_region(-1)
		await frames(76)
	quit(1 if failed else 0)


func frames(count: int) -> void:
	for index in range(count):
		await process_frame


func check(condition: bool, message: String) -> void:
	print("%.2fs %s %s" % [Engine.get_process_frames() / 60.0, "PASS" if condition else "FAIL", message])
	if not condition:
		failed = true
