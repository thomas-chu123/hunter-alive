extends RefCounted

const Config := preload("res://scripts/game/config_table.gd")

static var creatures: Dictionary = Config.read("monsters")
static var loot: Dictionary = Config.read("monster_loot")
static var rules: Dictionary = Config.read("monster_rules")


static func soul(id: String) -> Dictionary:
	var creature: Dictionary = creatures.get(id, {})
	return creature.get("soul", {})


static func vector(values: Array) -> Vector2:
	return Vector2(values[0], values[1])


static func rectangle(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])
