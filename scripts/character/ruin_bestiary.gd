extends RefCounted

const Config := preload("res://scripts/game/config_table.gd")

static var creatures: Dictionary = Config.read("monsters/monsters")
static var loot: Dictionary = Config.read("monsters/monster_loot")
static var rules: Dictionary = Config.read("monsters/monster_rules")


static func tile_tier(source_id: int) -> int:
	for variant: Dictionary in rules.tiers.variants:
		if int(variant.tile_source_id) == source_id:
			return int(variant.tier)
		for alias in variant.get("additional_tile_source_ids", []):
			if int(alias) == source_id:
				return int(variant.tier)
	return int(rules.tiers.default_tier)


static func tier_profile(tier: int) -> Dictionary:
	for variant: Dictionary in rules.tiers.variants:
		if int(variant.tier) == tier:
			return variant
	return {}


static func soul(id: String) -> Dictionary:
	var creature: Dictionary = creatures.get(id, {})
	return creature.get("soul", {})


static func vector(values: Array) -> Vector2:
	return Vector2(values[0], values[1])


static func rectangle(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])
