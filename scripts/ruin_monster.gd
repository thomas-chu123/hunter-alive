extends Node2D

signal felled(monster: Node2D)
signal disarmed(monster: Node2D)

const COLORS := {"spider": Color("#ae745d"), "lizard": Color("#77c6ad"), "treant": Color("#d5a56d")}
const HP := {"spider": 5, "lizard": 6, "treant": 20}
const SIZE := {"spider": Vector2(76, 42), "lizard": Vector2(92, 70), "treant": Vector2(110, 120)}
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
	draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	var outline := Color("#172c2a")
	var hue: Color = COLORS[species]
	var light := Color("#f7f4d4") if flash > 0 else hue
	var pulse := sin(age * 7.0) * 4.0
	match species:
		"spider":
			_draw_spider(light, outline, pulse)
		"lizard":
			_draw_lizard(light, outline, pulse)
		"treant":
			_draw_treant(light, outline, pulse)

	if windup > 0:
		var height := -130.0 if species == "treant" else -78.0
		draw_line(Vector2(0, height - 9), Vector2(0, height + 1), Color("#ffd184"), 3, true)
		draw_circle(Vector2(0, height + 6), 2, Color("#ffd184"))
	if health < int(HP[species]):
		var size: Vector2 = SIZE[species]
		var bar := Rect2(-24, -size.y - 13, 48, 4)
		draw_rect(bar, outline)
		bar.size.x *= float(health) / int(HP[species])
		draw_rect(bar, hue)


func _draw_spider(light: Color, ink: Color, pulse: float) -> void:
	for i in range(4):
		var x := float(i * 13 - 24)
		var spread := float(i * 22 - 34)
		for side: float in [-1.0, 1.0]:
			var foot := Vector2(spread + pulse * side + side * 7, -2.0 + minf(0, pulse * side))
			var knee := Vector2(x + side * 18, -35 - (i % 2) * 6 + pulse * side)
			draw_polyline(PackedVector2Array([Vector2(x, -22), knee, foot]), ink, 5, true)
			draw_line(knee, foot, light.darkened(0.24), 1.5, true)
	draw_circle(Vector2(-13, -22), 24, ink)
	draw_circle(Vector2(-15, -25), 19, light)
	draw_arc(Vector2(-17, -26), 13, 2.9, 5.3, 11, light.lightened(0.35), 2, true)
	draw_circle(Vector2(18, -17), 15, ink)
	draw_circle(Vector2(23, -21), 3, Color("#ffe49c"))
	draw_circle(Vector2(29, -17), 2, Color("#ffe49c"))


func _draw_lizard(light: Color, ink: Color, pulse: float) -> void:
	var y := -29.0 + pulse * 0.45
	draw_colored_polygon(PackedVector2Array([Vector2(-59, y + 10), Vector2(-21, y - 3),
		Vector2(-6, y - 11), Vector2(33, y - 10), Vector2(50, y - 1),
		Vector2(31, y + 12), Vector2(1, y + 14), Vector2(-29, y + 9)]), ink)
	draw_colored_polygon(PackedVector2Array([Vector2(-38, y), Vector2(2, y - 8),
		Vector2(32, y - 11), Vector2(47, y - 2), Vector2(26, y + 7), Vector2(1, y + 9)]), light)
	draw_colored_polygon(PackedVector2Array([Vector2(-24, y + 4), Vector2(-29, y - 35 - pulse),
		Vector2(5, y - 17), Vector2(19, y + 1), Vector2(4, y - 3), Vector2(-8, y + 5)]),
		light.darkened(0.40))
	draw_line(Vector2(-29, y - 35 - pulse), Vector2(4, y - 5), light.lightened(0.22), 1.8, true)
	draw_circle(Vector2(34, y - 5), 2.7, Color("#ffe8ac"))


func _draw_treant(light: Color, ink: Color, pulse: float) -> void:
	draw_line(Vector2(-22, -46), Vector2(-33, -5), ink, 18, true)
	draw_line(Vector2(20, -46), Vector2(31, -5), ink, 18, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-39, -101), Vector2(-23, -112),
		Vector2(24, -108), Vector2(46, -80), Vector2(30, -23), Vector2(-26, -24)]), ink)
	draw_colored_polygon(PackedVector2Array([Vector2(-34, -97), Vector2(-19, -105),
		Vector2(22, -103), Vector2(37, -81), Vector2(23, -30), Vector2(-22, -32)]), light.darkened(0.37))
	for i in range(4):
		var x := float(-25 + i * 15)
		draw_polyline(PackedVector2Array([Vector2(x + 6, -37), Vector2(x, -65),
			Vector2(x - 4, -97)]), light.darkened(0.1), 2.5, true)
	draw_line(Vector2(-35, -83), Vector2(-51, -112), ink, 8, true)
	draw_line(Vector2(-51, -112), Vector2(-41, -131), Color("#78926a"), 6, true)
	draw_line(Vector2(22, -93), Vector2(39, -122), Color("#80956c"), 7, true)
	draw_line(Vector2(11, -88), Vector2(29, -83), Color("#f7cd7b"), 3, true)
	draw_line(Vector2(32, -81), Vector2(59, -48 + pulse), ink, 13, true)
	if armed:
		var blade := Color("#ffdc91") if windup > 0 else light
		draw_line(Vector2(57, -53 + pulse), Vector2(111, -49), Color("#473b27"), 7, true)
		draw_colored_polygon(PackedVector2Array([Vector2(78, -53), Vector2(97, -69),
			Vector2(120, -62), Vector2(115, -48), Vector2(91, -43)]), blade)
