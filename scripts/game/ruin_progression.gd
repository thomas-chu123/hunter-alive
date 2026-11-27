extends RefCounted

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")

const Config := preload("res://scripts/game/config_table.gd")
static var settings := Config.read("equipment/progression")
static var MAX_RANK: int = settings.max_rank
static var MAX_LEVEL: int = settings.max_level
static var NAMES: Array = settings.rank_names
static var COLORS: Array = settings.rank_colors.map(func(value: String) -> Color: return Color(value))


static func rank_name(rank: int) -> String:
	return "+%d" % rank


static func gear_cost(rank: int) -> int:
	return settings.first_upgrade_cost if rank == 1 else settings.upgrade_cost


static func level_cost(level: int) -> int:
	return int(settings.level_cost_step) * (level + 1)


static func bag_capacity(level: int) -> int:
	return int(settings.bag_base) + int(settings.bag_per_level) * level


static func salvage_value(rank: int) -> int:
	return int(settings.salvage_per_rank) * rank


static func drop_rank(roll: float, tier: int) -> int:
	return tier if roll < float(Bestiary.loot.random_equipment.chance) else 0


static func armor_percent(points: int) -> int:
	return mini(points * int(settings.armor_per_point), settings.armor_cap)
