extends RefCounted

enum Region { TEMPLE, CORRIDOR, COURT, VOLCANO }

const TITLE_SCENE := "res://scenes/title/title.tscn"
const Config := preload("res://scripts/game/config_table.gd")
static var settings := Config.read("campaign")
static var BOSS_STAGE: int = settings.boss_stage
static var regions: Array = settings.regions
static var IDS := regions.map(func(region: Dictionary) -> String: return region.id)
static var SCENES := regions.map(func(region: Dictionary) -> String: return region.scene)
static var NAMES := regions.map(func(region: Dictionary) -> String: return region.name)


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
