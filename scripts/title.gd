extends Control

const CampSave := preload("res://scripts/camp_save.gd")
const Campaign := preload("res://scripts/campaign.gd")
const Preferences := preload("res://scripts/game_preferences.gd")
const GOLD := Color("#f3d8a3")
const TEXT := Color("#e4eadc")

var buttons: VBoxContainer
var settings: VBoxContainer
var new_game: Button
var continue_game: Button
var settings_button: Button
var volume: HSlider
var fullscreen: CheckButton
var notice: Label
var confirmation: ConfirmationDialog
var font: SystemFont


func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK TC", "Microsoft JhengHei", "sans-serif"])

	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://assets/environment/ancient_temple.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var tint := ColorRect.new()
	tint.color = Color(0.025, 0.062, 0.065, 0.54)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.073, 0.073, 0.95)
	style.border_color = Color("#8e7751")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 30
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var rows := VBoxContainer.new()
	rows.custom_minimum_size.x = 294
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	rows.add_child(_label("遠古獵人", 40, GOLD))
	rows.add_child(_label("崩塌神殿", 23, TEXT))

	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	rows.add_child(buttons)
	new_game = _button(buttons, "新遊戲", _request_new)
	continue_game = _button(buttons, "繼續", _continue)
	settings_button = _button(buttons, "設定", _open_settings)
	_button(buttons, "離開", get_tree().quit)
	continue_game.disabled = CampSave.read().is_empty()

	settings = VBoxContainer.new()
	settings.add_theme_constant_override("separation", 10)
	rows.add_child(settings)
	settings.add_child(_label("主音量", 17, TEXT))
	volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.custom_minimum_size.y = 28
	settings.add_child(volume)
	fullscreen = CheckButton.new()
	fullscreen.text = "全螢幕"
	fullscreen.add_theme_font_override("font", font)
	settings.add_child(fullscreen)
	_button(settings, "返回", _close_settings)
	settings.hide()

	notice = _label("", 16, GOLD)
	notice.hide()
	rows.add_child(notice)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "開始新遊戲"
	confirmation.dialog_text = "要覆蓋目前的營火存檔嗎？"
	confirmation.ok_button_text = "覆蓋並開始"
	confirmation.cancel_button_text = "取消"
	confirmation.get_label().add_theme_font_override("font", font)
	confirmation.get_ok_button().add_theme_font_override("font", font)
	confirmation.get_cancel_button().add_theme_font_override("font", font)
	add_child(confirmation)
	confirmation.confirmed.connect(_new_game)

	_load_settings()
	volume.value_changed.connect(_apply_settings.unbind(1))
	fullscreen.toggled.connect(_apply_settings.unbind(1))
	new_game.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if settings.visible and event.is_action_pressed("ui_cancel"):
		_close_settings()
		get_viewport().set_input_as_handled()


func _request_new() -> void:
	if CampSave.read().is_empty():
		_new_game()
	else:
		confirmation.popup_centered()


func _new_game() -> void:
	if CampSave.write({}) != OK:
		_show_notice("無法建立營火存檔。")
		return
	_start_run({})


func _continue() -> void:
	var checkpoint := CampSave.read()
	if checkpoint.is_empty():
		continue_game.disabled = true
		_show_notice("找不到可讀取的營火存檔。")
		new_game.grab_focus()
		return
	_start_run(checkpoint.state)


func _start_run(state: Dictionary) -> void:
	get_tree().set_meta(CampSave.RESTORE_META, state)
	if get_tree().change_scene_to_file(Campaign.scene_path(state)) != OK:
		get_tree().remove_meta(CampSave.RESTORE_META)
		_show_notice("無法進入存檔中的區域。")


func _open_settings() -> void:
	buttons.hide()
	settings.show()
	volume.grab_focus()


func _close_settings() -> void:
	settings.hide()
	buttons.show()
	settings_button.grab_focus()


func _load_settings() -> void:
	var file := Preferences.read()
	volume.set_value_no_signal(float(file.get_value("audio", "volume", 100)))
	fullscreen.set_pressed_no_signal(bool(file.get_value("display", "fullscreen", false)))
	Preferences.apply(get_window(), volume.value, fullscreen.button_pressed)


func _apply_settings() -> void:
	Preferences.apply(get_window(), volume.value, fullscreen.button_pressed)
	if Preferences.write(volume.value, fullscreen.button_pressed) != OK:
		_show_notice("無法儲存設定。")


func _show_notice(message: String) -> void:
	notice.text = message
	notice.show()


func _label(value: String, size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", ink)
	return label


func _button(parent: VBoxContainer, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
