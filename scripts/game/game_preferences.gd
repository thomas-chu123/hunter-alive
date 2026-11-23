extends RefCounted

const PATH := "user://settings.cfg"


static func read() -> ConfigFile:
	var file := ConfigFile.new()
	file.load(PATH)
	return file


static func apply(window: Window, volume: float, fullscreen: bool) -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master, volume <= 0)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume / 100.0, 0.001)))
	if DisplayServer.get_name() != "headless":
		var mode := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		if window.mode != mode:
			window.mode = mode


static func write(volume: float, fullscreen: bool) -> Error:
	var file := ConfigFile.new()
	file.set_value("audio", "volume", volume)
	file.set_value("display", "fullscreen", fullscreen)
	return file.save(PATH)
