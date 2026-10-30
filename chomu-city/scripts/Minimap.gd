extends Control
## Rotating radar-style minimap drawn with 2D primitives (cheap on phones).

const SCALE := 0.55          # pixels per metre
var city: Node
var traffic: Node
var peds: Node
var _font: Font

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(230, 230)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font

func _process(_d: float) -> void:
	queue_redraw()

func _w2m(p: Vector3, center: Vector3, rot: float) -> Vector2:
	var d := Vector2(p.x - center.x, p.z - center.z).rotated(rot) * SCALE
	return size * 0.5 + d

func _draw() -> void:
	var r := size.x * 0.5
	var c := size * 0.5
	draw_circle(c, r, Color(0.06, 0.07, 0.09, 0.82))
	if city == null or Game.player == null:
		return
	var focus: Vector3 = Game.player_car.global_position if Game.driving and Game.player_car else Game.player.global_position
	var rot := Game.cam_yaw
	var road_w: float = city.ROAD_HALF * 2.0 * SCALE
	var half: float = city.HALF
	var col := Color(0.42, 0.44, 0.5)
	# blocks are the gaps; draw roads
	for x in city.roads:
		draw_line(_w2m(Vector3(x, 0, -half - 7), focus, rot), _w2m(Vector3(x, 0, half + 7), focus, rot), col, road_w)
		draw_line(_w2m(Vector3(-half - 7, 0, x), focus, rot), _w2m(Vector3(half + 7, 0, x), focus, rot), col, road_w)
	# park
	var pc: Vector3 = city.block_center(3, 1)
	draw_circle(_w2m(pc, focus, rot), 30.0 * SCALE, Color(0.2, 0.45, 0.2, 0.7))
	if traffic:
		for p in traffic.positions():
			draw_circle(_w2m(p, focus, rot), 3.5, Color(1.0, 0.35, 0.3))
	if peds:
		for p in peds.positions():
			draw_circle(_w2m(p, focus, rot), 2.0, Color(0.85, 0.85, 0.9, 0.8))
	if Game.player_car and not Game.driving:
		draw_circle(_w2m(Game.player_car.global_position, focus, rot), 5.0, Color(0.3, 0.7, 1.0))
	# player arrow (camera-up)
	var fwd: Vector3
	if Game.driving and Game.player_car:
		fwd = Game.player_car.forward_dir()
	elif Game.player and Game.player.model:
		fwd = Game.player.model.global_basis.z
	else:
		fwd = Vector3.FORWARD
	var a := Vector2(fwd.x, fwd.z).rotated(rot).normalized()
	var perp := Vector2(-a.y, a.x)
	var pts := PackedVector2Array([c + a * 11.0, c - a * 7.0 + perp * 7.0, c - a * 3.0, c - a * 7.0 - perp * 7.0])
	draw_colored_polygon(pts, Util.ACCENT)
	# north marker
	var n := Vector2(0, -1).rotated(rot)
	draw_string(_font, c + n * (r - 14.0) - Vector2(6, -6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
	draw_arc(c, r - 1.0, 0, TAU, 64, Color(1, 1, 1, 0.25), 2.0, true)
