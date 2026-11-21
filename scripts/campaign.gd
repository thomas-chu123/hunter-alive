extends RefCounted

enum Region { TEMPLE, CORRIDOR, COURT }

const SCENES := [
	"res://scenes/ruins.tscn",
	"res://scenes/flooded_corridor.tscn",
	"res://scenes/buried_court.tscn",
]

const NAMES := ["崩塌神殿", "淹沒的迴廊", "埋碑內庭"]


static func scene_path(checkpoint: Dictionary) -> String:
	var index: Variant = checkpoint.get("region", Region.TEMPLE)
	if index is int and index >= 0 and index < SCENES.size():
		return SCENES[index]
	return SCENES[Region.TEMPLE]
