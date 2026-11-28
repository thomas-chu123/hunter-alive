extends "res://scripts/scene/ruins.gd"

const Trap := preload("res://scripts/trap/trap_tile.gd")
const SLAB_START := Vector2i(115, -9)
const SLAB_WIDTH := 5
static var vault: Dictionary = stage_rules.stages.ruins_1
const WALL_X := 110
const RELEASE := Vector2(2240, 60)
const SLUICE := Vector2(2080, 540)
const RIVER_LEFT := 1500.0
const RIVER_RIGHT := 2160.0

@onready var terrain: TileMapLayer = $Landscape/Terrain
var crack_time := -1.0
var collapsed := false
var passage_open := false
var drained := false
var river_depth : float = vault.normal_depth
var nest_tier := 0
var nest_scale_override: Variant
var nest_position := Vector2.INF
var guardian: Monster
var nest_awake := false
var stone_kill := false
var lizard: Monster
var hare: Monster
var clash_cooldown := 0.0
var loose_floor := 0
var escape_time := -1.0


func _ready() -> void:
	super()
	for trap in $Landscape/Traps.get_children(true):
		if trap is Trap and trap.kind == Trap.Kind.BOULDER:
			trap.boulder_rolled.connect(_on_boulder_rolled)


func _on_boulder_rolled(center: Vector2, radius: float) -> void:
	# Offscreen cycles should leave the encounter for the hunter to discover.
	var point := to_local(center)
	if absf(hunter.position.y - point.y) > vault.boulder_vertical_range or hunter.position.distance_to(point) > vault.boulder_radius_from_hunter:
		return
	for monster in enemies.duplicate():
		var bounds: Rect2 = monster.body_hitbox()
		if point.distance_squared_to(point.clamp(bounds.position, bounds.end)) <= radius * radius:
			monster.receive_hit(monster.max_health, false, false, "", 1.0)
			if monster.health == 0:
				stone_kill = true


func _on_slab(actor: CharacterBody2D) -> bool:
	var cell := terrain.local_to_map(terrain.to_local(actor.global_position) + Vector2.DOWN * 2)
	return actor.is_on_floor() and cell.y == SLAB_START.y and cell.x >= SLAB_START.x and cell.x < SLAB_START.x + SLAB_WIDTH


func _physics_process(delta: float) -> void:
	super(delta)
	if not hunter.is_physics_processing() or restarting or transitioning or completed:
		return
	river_depth = move_toward(river_depth, vault.drained_depth if drained else vault.normal_depth, delta * float(vault.drain_speed))
	hunter.shallow_water = hunter.position.x > RIVER_LEFT and hunter.position.x < RIVER_RIGHT and hunter.position.y > 540 - river_depth and river_depth > vault.wading_depth
	_update_nest()
	_update_clash(delta)
	if escape_time >= 0:
		escape_time += delta
		if escape_time >= float(vault.escape_delay) + loose_floor * float(vault.collapse_interval):
			terrain.erase_cell(Vector2i(133 - loose_floor, 3))
			loose_floor += 1
			if loose_floor == int(vault.collapse_tiles):
				escape_time = -1
	if collapsed:
		return
	if crack_time < 0:
		if not _on_slab(hunter) and not enemies.any(_on_slab):
			return
		crack_time = 0.0
		if hunter.position.distance_to(Vector2(2350, -180)) < 400:
			_notice("裂板正在下沉！退回斷柱，或隨它落下。", 2.2)
	crack_time += delta
	if crack_time >= vault.slab_delay:
		_collapse()


func _collapse() -> void:
	for x in SLAB_WIDTH:
		terrain.erase_cell(SLAB_START + Vector2i.RIGHT * x)
	collapsed = true


func _at_sluice() -> bool:
	return not drained and hunter.position.distance_to(SLUICE) < vault.sluice_radius


func _at_release() -> bool:
	return not passage_open and hunter.position.x > (WALL_X + 1) * 20 and hunter.position.distance_to(RELEASE) < vault.release_radius


func _interact() -> void:
	if _at_sluice():
		_drain_river()
		_notice("水閘升起，河床通往舊研究室。閘頂的石匣需要蛛魂攀上。", 4)
	elif _nest_guarding_chest():
		_notice("石殼壓著匣蓋。等鼴獸落爪後，趁牠收勢時反擊。", 2)
	elif _at_release():
		_open_passage()
		_notice("石栓鬆開了。向西穿過石門，便能回到升降井。", 3.5)
	else:
		var treasure := _near_treasure()
		super()
		if treasure == "cliff_boots" and obtained_equipment.has(treasure):
			escape_time = 0
			_notice("石匣底座下陷！向西拉開火盆旁的石栓，或落往下層。", 4)


func _update_stage_hud() -> void:
	super()
	if _at_sluice():
		prompt_label.text = "E　轉動洩水輪"
	elif _nest_guarding_chest():
		prompt_label.text = "鼴獸守著靴匣"
	elif _at_release():
		prompt_label.text = "E　拉開火盆旁的石栓"
	elif hunter.position.y < -140 and hunter.position.y > -250 and hunter.position.x > 2140:
		prompt_label.text = "斷柱後的爪印消失在裂縫邊。"
	elif hunter.shallow_water:
		prompt_label.text = "上岸可避毒霧。沿水面向東找洩水輪。"
	elif hunter.position.y > 460 and hunter.position.x > 790 and hunter.position.x < 1290:
		prompt_label.text = "滾石向東。把蜥蜴引進石道後跳開。"


func _draw() -> void:
	super()
	draw_rect(Rect2(RIVER_LEFT, 540 - river_depth, RIVER_RIGHT - RIVER_LEFT, river_depth), Color(0.18, 0.44, 0.45, 0.66))
	draw_line(Vector2(RIVER_LEFT, 540 - river_depth), Vector2(RIVER_RIGHT, 540 - river_depth), Color("#73ada5"), 2)
	var hub := SLUICE - Vector2(0, 30)
	draw_arc(hub, 16, 0, TAU, 24, Color("#cbad79"), 4)
	for spoke in 4:
		draw_line(hub, hub + Vector2.RIGHT.rotated(spoke * PI / 2 + (0.6 if drained else 0.0)) * 16, Color("#cbad79"), 3)
	if not collapsed:
		var start := Vector2(SLAB_START * 20)
		var color := Color("#caad86") if crack_time < 0 else Color("#ffbd65")
		for i in range(4):
			var foot := start + Vector2(13 + 21 * i, -1)
			draw_line(foot - Vector2(7, 3), foot, color, 2.0)
			draw_line(foot, foot + Vector2(4, -5), color, 2.0)


func _open_passage() -> void:
	for y in range(-1, 3):
		terrain.erase_cell(Vector2i(WALL_X, y))
	passage_open = true


func _checkpoint_state() -> Dictionary:
	var state := super()
	state["temple_slab_collapsed"] = collapsed
	state["temple_passage_open"] = passage_open
	state["temple_drained"] = drained
	state["temple_stone_kill"] = stone_kill
	state["temple_loose_floor"] = loose_floor
	state["temple_escape_started"] = escape_time >= 0
	return state


func _restore_camp(state: Dictionary) -> void:
	super(state)
	if state.get("temple_slab_collapsed", false):
		_collapse()
	if state.get("temple_passage_open", false):
		_open_passage()

	if state.get("temple_drained", false):
		_drain_river()
		river_depth = vault.drained_depth
	stone_kill = state.get("temple_stone_kill", false)
	loose_floor = clampi(state.get("temple_loose_floor", 0), 0, vault.collapse_tiles)
	for i in loose_floor:
		terrain.erase_cell(Vector2i(133 - i, 3))
	if state.get("temple_escape_started", false) and loose_floor < vault.collapse_tiles:
		escape_time = 0


func _drain_river() -> void:
	drained = true
	for x in range(108, 112):
		for y in range(23, 27):
			terrain.erase_cell(Vector2i(x, y))


func _spawn_enemies() -> void:
	nest_awake = false
	nest_position = Vector2.INF
	super()
	if nest_position.is_finite():
		var props: TileMapLayer = $Landscape/BackgroundProps
		props.set_cell(props.local_to_map(props.to_local(to_global(nest_position))), 0, Vector2i.ZERO, 12)


func _add_monster(species: String, x: float, y: float = Landscape.FLOOR_Y, tier: int = 0, scale_override: Variant = null) -> void:
	if species == "root_mole" and not nest_awake:
		nest_position = Vector2(x, y)
		nest_tier = tier
		nest_scale_override = scale_override
		return
	super(species, x, y, tier, scale_override)
	if species == "lizard":
		lizard = enemies.back()
	elif species == "dust_hare" and y > 500:
		hare = enemies.back()


func _update_nest() -> void:
	if nest_awake or hunter.position.distance_to(nest_position) > vault.nest_radius or absf(hunter.position.y - nest_position.y) > vault.nest_vertical_range:
		return
	nest_awake = true
	var props: TileMapLayer = $Landscape/BackgroundProps
	props.erase_cell(props.local_to_map(props.to_local(to_global(nest_position))))
	_add_monster("root_mole", nest_position.x, nest_position.y, nest_tier, nest_scale_override)
	guardian = enemies.back()
	var mole := guardian
	if stone_kill:
		mole.profile = mole.profile.duplicate()
		mole.profile.speed *= vault.agitated_speed_multiplier
		mole.modulate = Color("#e3bb91")
		_notice("斷柱倒下，銅背鼴獸竄出！滾石的震動讓牠衝得更快。", 4)
	else:
		_notice("斷柱在動！鑿根鼴獸從石殼裡鑽了出來。", 3)


func _nest_guarding_chest() -> bool:
	return _near_treasure() == "cliff_boots" and is_instance_valid(guardian) and guardian.health > 0


func _update_clash(delta: float) -> void:
	clash_cooldown = maxf(0, clash_cooldown - delta)
	if clash_cooldown > 0 or not is_instance_valid(lizard) or not is_instance_valid(hare):
		return
	if lizard.health <= 0 or hare.health <= 0 or hunter.position.distance_to(lizard.position) > vault.clash_radius:
		return
	if lizard.body_hitbox().grow(vault.clash_hit_margin).intersects(hare.body_hitbox()):
		clash_cooldown = vault.clash_cooldown
		var direction := signf(hare.position.x - lizard.position.x)
		hare.receive_hit(vault.clash_damage, false, false, "", direction)
		lizard.receive_hit(vault.clash_damage, false, false, "", -direction)
