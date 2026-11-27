extends RefCounted

enum Region { TEMPLE, CORRIDOR, COURT, VOLCANO }

const Config := preload("res://scripts/game/config_table.gd")
static var settings := Config.read("campaign/campaign")
static var scene_routes := Config.read("campaign/stage_change")
static var TITLE_SCENE: String = scene_routes.title
static var TRAP_COURSE_SCENE: String = scene_routes.trap_course
static var BOSS_STAGE: int = settings.boss_stage
static var regions: Array = settings.regions
static var IDS := regions.map(func(region: Dictionary) -> String: return region.id)
static var SCENES := IDS.map(func(id: String) -> String: return scene_routes.regions[id].entry)
static var NAMES := regions.map(func(region: Dictionary) -> String: return region.name)


static func scene_path(checkpoint: Dictionary) -> String:
	var region: Variant = checkpoint.get("region", Region.TEMPLE)
	if not region is int or region < 0 or region >= IDS.size():
		region = Region.TEMPLE
	var stage: Variant = checkpoint.get("stage", 1)
	if stage is int and stage == 0:
		return SCENES[region]
	var stages: Array = scene_routes.regions[IDS[region]].stages
	if not stage is int or stage < 1 or stage > stages.size():
		stage = 1
	return stages[stage - 1]


static func next_stage(region: int, stage: int) -> Dictionary:
	var stages: Array = scene_routes.regions[IDS[region]].stages
	if stage < stages.size():
		return {"region": region, "stage": stage + 1}
	if region + 1 < IDS.size():
		return {"region": region + 1, "stage": 1}
	return {}
