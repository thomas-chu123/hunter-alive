extends RefCounted

const Bestiary := preload("res://scripts/character/ruin_bestiary.gd")

const MAX_RANK := 5
const MAX_LEVEL := 10
# Material names are internal design references.
const NAMES := ["", "木", "鐵", "銅", "銀", "金"]
const COLORS := [
	Color.TRANSPARENT, Color("#a9734d"), Color("#718d9a"), Color("#ce8555"),
	Color("#d1def0"), Color("#f2ca61"),
]


static func rank_name(rank: int) -> String:
	return "+%d" % rank


static func gear_cost(rank: int) -> int:
	return 10 if rank == 1 else 20


static func level_cost(level: int) -> int:
	return 10 * (level + 1)


static func bag_capacity(level: int) -> int:
	return 10 + 2 * level


static func salvage_value(rank: int) -> int:
	return 2 * rank


static func drop_rank(roll: float) -> int:
	var edge := 0.0
	var rates: Array = Bestiary.loot.random_equipment.rank_rates
	for index in range(rates.size()):
		edge += float(rates[index])
		if roll < edge:
			return index + 1
	return 0


static func armor_percent(points: int) -> int:
	return mini(points * 3, 60)
