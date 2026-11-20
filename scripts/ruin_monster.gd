extends Node2D

signal felled(monster: Node2D)
signal disarmed(monster: Node2D)

const Art := preload("res://scripts/ruin_sprite_art.gd")
const COLORS := {"spider": Color("#ae745d"), "lizard": Color("#77c6ad"), "treant": Color("#d5a56d")}
const HP := {"spider": 5, "lizard": 6, "treant": 20}
const SIZE := {"spider": Vector2(76, 42), "lizard": Vector2(92, 70), "treant": Vector2(110, 120)}
const ART_ROWS := {"spider": 0, "lizard": 1, "treant": 2}
const ART_SCALES := {"spider": 0.30, "lizard": 0.33, "treant": 0.46}
const STRIKE_DURATION := 0.30

var species: String
var target: CharacterBody2D
var home := Vector2.ZERO
var health := 0
var armed := false
var facing := -1.0
var age := 0.0
var flash := 0.0
var recovery := 0.0
var windup := 0.0
var strike := 0.0
var stagger := 0.0
var can_hit := false
var attack_range := 0.0
var walking := false


func configure(kind: String, at: Vector2, hunter: CharacterBody2D) -> void:
	species = kind
	position = at
	home = at
	target = hunter
	health = HP[species]
	armed = species == "treant"
	attack_range = 145.0 if armed else 74.0


func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	age += delta
	flash = maxf(flash - delta, 0)
	stagger = maxf(stagger - delta, 0)
	recovery = maxf(recovery - delta, 0)
	var before_x := position.x
	var offset := target.position - position
	var alert := absf(offset.x) < 345 and absf(offset.y) < 155
	if windup > 0:
		windup -= delta
		if windup <= 0:
			strike = STRIKE_DURATION
			can_hit = true
	elif strike > 0:
		strike -= delta
		_resolve_attack(delta)
		if strike <= 0:
			recovery = 1.0 if species == "treant" else 0.68
	elif stagger <= 0 and alert:
		if absf(offset.x) > 8:
			facing = signf(offset.x)
		if absf(offset.x) <= attack_range and absf(offset.y) < 85 and recovery <= 0:
			windup = 0.82 if species == "treant" else 0.44
		elif absf(offset.x) > attack_range * 0.78:
			var speed := 116.0 if species == "spider" else 72.0
			position.x = clampf(position.x + facing * speed * delta, home.x - 205, home.x + 205)
	elif stagger <= 0 and not alert:
		var destination := home.x + sin(age * 0.9) * 52.0
		facing = -1.0 if destination < position.x else 1.0
		position.x = move_toward(position.x, destination, 54.0 * delta)
	walking = absf(position.x - before_x) > 0.25
	queue_redraw()


func _resolve_attack(delta: float) -> void:
	var speed := 265.0 if species == "lizard" else 130.0
	position.x = clampf(position.x + facing * speed * delta, home.x - 205, home.x + 205)
	if species == "lizard":
		var flight := clampf(strike / STRIKE_DURATION, 0.0, 1.0)
		position.y = home.y - sin(PI * flight) * 52.0
	var offset := target.position - position
	if can_hit and facing * offset.x >= -22 and absf(offset.x) < attack_range + 25 and absf(offset.y) < 84:
		can_hit = false
		target.hurt(position.x)


func body_hitbox() -> Rect2:
	var size: Vector2 = SIZE[species]
	return Rect2(position - Vector2(size.x / 2.0, size.y), size)


func weapon_hitbox() -> Rect2:
	return Rect2(position + Vector2(facing * 81 - 24, -71), Vector2(48, 56))


func receive_hit(damage: int, weapon_hit: bool) -> void:
	if health <= 0:
		return
	flash = 0.15
	if weapon_hit and armed and windup > 0:
		armed = false
		attack_range = 91.0
		windup = 0.0
		stagger = 0.50
		recovery = 0.50
		disarmed.emit(self)
		return
	health = maxi(0, health - damage)
	if health == 0:
		felled.emit(self)
		queue_free()


func _draw() -> void:
	var pose := 1 if walking and sin(age * 13.0) > 0 else 0
	var torso_motion := sin(age * (9.0 if walking else 3.0)) * 1.5
	if windup > 0:
		pose = 2
		torso_motion = 0
	if strike > 0:
		pose = 3 if species != "treant" or not armed else 1
		torso_motion = 0
	if species == "treant" and not armed:
		pose = 3
	var tint := Color(1.25, 1.16, 1.07) if flash > 0 else Color.WHITE
	Art.draw_actor(self, ART_ROWS[species], pose, ART_SCALES[species], facing, torso_motion, tint)
	draw_set_transform(Vector2.ZERO)
	if windup > 0 and armed:
		var grip := weapon_hitbox().get_center() - position + Vector2(0, 12)
		draw_circle(grip, 9, Color(1, 0.74, 0.29, 0.32))
		draw_circle(grip, 3, Color("#ffeac3"))
	elif windup > 0:
		var height := -155.0 if species == "treant" else -94.0
		draw_line(Vector2(0, height - 9), Vector2(0, height + 1), Color("#ffd184"), 3, true)
		draw_circle(Vector2(0, height + 6), 2, Color("#ffd184"))
	if health < int(HP[species]):
		var height := -161.0 if species == "treant" else -90.0
		var bar := Rect2(-24, height, 48, 4)
		draw_rect(bar, Color("#172c2a"))
		bar.size.x *= float(health) / int(HP[species])
		draw_rect(bar, COLORS[species])
