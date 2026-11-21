extends RefCounted

const MAX_RANK := 5
const MAX_LEVEL := 10
const NAMES := ["", "木", "鐵", "銅", "銀", "金"]
const COLORS := [
	Color.TRANSPARENT, Color("#a9734d"), Color("#718d9a"), Color("#ce8555"),
	Color("#d1def0"), Color("#f2ca61"),
]
const DROP_RATES := [0.20, 0.10, 0.05, 0.025, 0.0125]


static func rank_name(rank: int) -> String:
	return "%s +%d" % [NAMES[rank], rank]


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
	for index in range(DROP_RATES.size()):
		edge += DROP_RATES[index]
		if roll < edge:
			return index + 1
	return 0


static func armor_percent(points: int) -> int:
	return mini(points * 3, 60)
