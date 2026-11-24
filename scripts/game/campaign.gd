extends RefCounted

enum Region { TEMPLE, CORRIDOR, COURT, VOLCANO }

const TITLE_SCENE := "res://scenes/title/title.tscn"
const BOSS_STAGE := 5
const IDS := ["ruins", "flooded_corridor", "buried_court", "volcanic_caldera"]

const SCENES := [
	"res://scenes/ruins/ruins.tscn",
	"res://scenes/flooded_corridor/flooded_corridor.tscn",
	"res://scenes/buried_court/buried_court.tscn",
	"res://scenes/volcanic_caldera/volcanic_caldera.tscn",
]

const NAMES := ["崩塌神殿", "淹沒的迴廊", "埋碑內庭", "火山熔爐"]


static func scene_path(checkpoint: Dictionary) -> String:
	var region: Variant = checkpoint.get("region", Region.TEMPLE)
	if not region is int or region < 0 or region >= IDS.size():
		region = Region.TEMPLE
	var stage: Variant = checkpoint.get("stage", 1)
	if stage is int and stage == 0:
		return SCENES[region]
	if not stage is int or stage < 1 or stage > BOSS_STAGE:
		stage = 1
	var id: String = IDS[region]
	return "res://scenes/%s/%s_%d.tscn" % [id, id, stage]
