extends Node2D

const Campaign := preload("res://scripts/game/campaign.gd")
const Hunter := preload("res://scripts/character/ruin_hunter.gd")
const TRAP_SIGNS := {
	Vector2(240, 242): "下降針刺",
	Vector2(560, 242): "左牆尖刺",
	Vector2(820, 242): "右牆尖刺",
	Vector2(1060, 242): "擺錘",
	Vector2(1300, 332): "熔岩",
	Vector2(1520, 242): "火球",
	Vector2(1940, 242): "爆裂火球",
	Vector2(2140, 242): "毒霧",
	Vector2(2500, 242): "滾石",
	Vector2(2940, 333): "固定門 Ａ",
	Vector2(3260, 333): "落點 Ｂ",
	Vector2(3520, 333): "隨機門",
	Vector2(3820, 364): "電擊",
}
const START := Vector2(70, 439)

@onready var hunter: Hunter = $Hunter
@onready var hearts := $HUD/Margin/Row/Hearts
@onready var camera: Camera2D = $Hunter/Camera
var _sign_font := SystemFont.new()


func _ready() -> void:
	_sign_font.font_names = PackedStringArray(["Noto Sans CJK TC", "Microsoft JhengHei", "sans-serif"])
	get_node("/root/GameMusic").play_region(-1)
	hunter.defeated.connect(_reset_hunter.call_deferred)
	_update_health()


func _process(_delta: float) -> void:
	_update_health()
	if hunter.position.y > 650:
		_reset_hunter()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(Campaign.TITLE_SCENE)
	elif event is InputEventKey and event.physical_keycode == KEY_R and event.pressed and not event.echo:
		_reset_hunter()


func _reset_hunter() -> void:
	hunter.respawn(START)
	camera.reset_smoothing()


func _update_health() -> void:
	hearts.update_health(hunter.health, hunter.max_health())


func _draw() -> void:
	const FONT_SIZE := 17
	for anchor: Vector2 in TRAP_SIGNS:
		var title: String = TRAP_SIGNS[anchor]
		var width := _sign_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var left := anchor.x - width / 2.0
		var plate := Rect2(left - 10, anchor.y - 21, width + 20, 29)
		draw_rect(plate, Color("#201b1a"))
		draw_rect(plate, Color("#7e6046"), false, 1.0)
		draw_string(_sign_font, Vector2(left, anchor.y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color("#ead2a4"))
