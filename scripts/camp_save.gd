extends RefCounted

const PATH := "user://ruins-checkpoint.cfg"
const VERSION := 1
const RESTORE_META := &"ruins_checkpoint"


static func read() -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PATH) != OK or file.get_value("checkpoint", "version", 0) != VERSION:
		return {}
	var state: Variant = file.get_value("checkpoint", "state", null)
	if state is Dictionary:
		return {"state": state}
	return {}


static func write(state: Dictionary) -> Error:
	var file := ConfigFile.new()
	file.set_value("checkpoint", "version", VERSION)
	file.set_value("checkpoint", "state", state)
	var temporary := PATH + ".tmp"
	var result := file.save(temporary)
	if result != OK:
		return result
	return DirAccess.rename_absolute(temporary, PATH)
