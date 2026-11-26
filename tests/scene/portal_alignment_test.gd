extends SceneTree

const Campaign := preload("res://scripts/game/campaign.gd")
const PORTAL_SOURCE := 2
const EXIT_TILE := 10

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for region in Campaign.IDS.size():
		for stage in range(1, Campaign.BOSS_STAGE + 1):
			check_scene(Campaign.scene_path({"region": region, "stage": stage}))
	await process_frame
	quit(1 if failures else 0)


func check_scene(path: String) -> void:
	var level := (load(path) as PackedScene).instantiate()
	var terrain := level.get_node("Landscape/Terrain") as TileMapLayer
	var traps := level.get_node("Landscape/Traps") as TileMapLayer
	var portals := traps.get_used_cells_by_id(PORTAL_SOURCE, Vector2i.ZERO, EXIT_TILE)
	for portal_cell in portals:
		var portal_position := terrain.to_local(traps.to_global(traps.map_to_local(portal_cell)))
		var ground_cell := terrain.local_to_map(portal_position + Vector2(0, 10))
		var distance := 0
		while distance < 10 and terrain.get_cell_tile_data(ground_cell + Vector2i(0, distance)) == null:
			distance += 1
		check(distance == 0 and terrain.get_cell_tile_data(ground_cell + Vector2i.UP) == null,
			"%s exit portal is grounded (cell %s, gap %d px)" % [path, portal_cell, distance * 20])
	level.free()


func check(condition: bool, message: String) -> void:
	print("%s %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1
