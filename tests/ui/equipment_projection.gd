extends SceneTree

const Hunter := preload("res://scripts/character/ruin_hunter.gd")

var failed := false


func _initialize() -> void:
	var hunter := Hunter.new()
	hunter.gear = {"頭部": "linen_hood", "手部": "hunter_wraps"}
	hunter.item_ranks = {"linen_hood": 2, "hunter_wraps": 1, "hunter_knife": 2}
	var candidate := {"手部": "bowstring_gloves"}
	var ranks := {"bowstring_gloves": 4}
	check(hunter.max_health(candidate) == 6 and hunter.max_health() == 7, "removing the hood previews a lower HP cap")
	check(hunter.armor_points(candidate, ranks) == 4 and hunter.armor_points() == 3, "replacement counts only the selected armor ranks")
	check(is_equal_approx(hunter.weapon_period("hunter_bow", candidate), Hunter.BOW_DURATION * 0.85), "candidate gloves change bow frequency")
	check(is_equal_approx(hunter.weapon_period("hunter_knife"), Hunter.WRAPS_KNIFE_DURATION), "active gloves still determine actual knife frequency")
	check(hunter.weapon_damage("hunter_knife") == 3 and hunter.weapon_damage("hunter_knife", 3) == 4, "a higher-ranked copy previews damage 3 to 4")
	hunter.free()
	quit(int(failed))


func check(condition: bool, message: String) -> void:
	failed = failed or not condition
	print("%s %s" % ["PASS" if condition else "FAIL", message])
