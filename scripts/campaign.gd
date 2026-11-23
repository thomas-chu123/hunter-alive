extends RefCounted

enum Region { TEMPLE, CORRIDOR, COURT }

const TITLE_SCENE := "res://scenes/title/title.tscn"
const IDS := ["ruins", "flooded_corridor", "buried_court"]

const SCENES := [
	"res://scenes/ruins/ruins.tscn",
	"res://scenes/flooded_corridor/flooded_corridor.tscn",
	"res://scenes/buried_court/buried_court.tscn",
]

const NAMES := ["崩塌神殿", "淹沒的迴廊", "埋碑內庭"]


static func scene_path(checkpoint: Dictionary) -> String:
	var index: Variant = checkpoint.get("region", Region.TEMPLE)
	if index is int and index >= 0 and index < SCENES.size():
		return SCENES[index]
	return SCENES[Region.TEMPLE]
