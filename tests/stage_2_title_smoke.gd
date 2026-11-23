extends SceneTree

const CampSave := preload("res://scripts/camp_save.gd")
const TITLE := "res://scenes/title/title.tscn"

var failed := false


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file(TITLE)
	await scene_changed
	var title = current_scene
	var resume_only := "--resume" in OS.get_cmdline_user_args()
	if not resume_only:
		check(title.continue_game.disabled, "fresh profile disables Continue")
		await hold_view()
		await press(title.settings_button)
		check(title.settings.visible, "Settings opens")
		title.volume.value = 65
		await hold_view()
		await press(title.settings.get_child(-1))
		await press(title.new_game)
		await scene_changed
		var ruins = current_scene
		check(ruins.name == "Ruins", "New Game opens the ruins")
		ruins.materials = 7
		ruins.collected_souls.append("lizard")
		ruins.hunter.equipped_soul = "lizard"
		ruins.hunter.bow_level = 2
		ruins.hunter.with_bow = true
		await at_camp(ruins)
		await hold_view()
		await press(ruins.camp_rest)
		check(CampSave.read().get("state", {}).get("materials", 0) == 7, "Rest writes the checkpoint")
		await hold_view()
		await press(ruins.camp_save_exit)
		await scene_changed
		title = current_scene
	if not check(not title.continue_game.disabled and title.volume.value == 65, "checkpoint and settings reload"):
		quit(1)
		return
	await press(title.new_game)
	check(title.confirmation.visible, "existing save requires confirmation before overwrite")
	await hold_view()
	title.confirmation.hide()
	await press(title.continue_game)
	await scene_changed
	var restored = current_scene
	check(restored.materials == 7 and restored.hunter.equipped_soul == "lizard", "Continue restores materials and wing soul")
	check(restored.hunter.with_bow and restored.hunter.bow_level == 2, "Continue restores weapon selection and upgrades")
	await hold_view()
	quit(1 if failed else 0)


func at_camp(ruins: Node) -> void:
	for frame in range(10):
		await physics_frame
	Input.action_press("hunt_interact")
	await physics_frame
	await physics_frame
	Input.action_release("hunt_interact")
	check(ruins.camp_menu.visible, "E opens the camp menu")


func press(button: Button) -> void:
	button.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	root.push_input(release)


func hold_view() -> void:
	await create_timer(0.75).timeout


func check(condition: bool, description: String) -> bool:
	failed = failed or not condition
	print("%s %s" % ["PASS" if condition else "FAIL", description])
	return condition
