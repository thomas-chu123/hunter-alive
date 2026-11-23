extends RefCounted

const DATA_DIR := "res://data"

static var creatures: Dictionary = _read_table("monsters")
static var encounters: Dictionary = _read_table("monster_encounters")
static var loot: Dictionary = _read_table("monster_loot")
static var rules: Dictionary = _read_table("monster_rules")


static func _read_table(name: String) -> Dictionary:
	var path := "%s/%s.json" % [DATA_DIR, name]
	var document := JSON.new()
	if document.parse(FileAccess.get_file_as_string(path)) != OK or not document.data is Dictionary:
		push_error("Invalid monster data table: %s" % path)
		return {}
	return document.data


static func soul(id: String) -> Dictionary:
	var creature: Dictionary = creatures.get(id, {})
	return creature.get("soul", {})


static func vector(values: Array) -> Vector2:
	return Vector2(values[0], values[1])


static func rectangle(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])
