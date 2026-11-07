extends Camera3D
## Demo camera: slow auto-orbit around `target`; drag (touch or mouse) to rotate, pinch / wheel to zoom.

@export var target := Vector3.ZERO
@export var distance := 14.0
@export var min_distance := 4.0
@export var max_distance := 60.0
@export var yaw := 0.6
@export var pitch := -0.22
@export var auto_speed := 0.06
@export var min_height := 0.6   # keep the camera above the water

var _idle := 0.0
var _touches := {}
var _pinch_start := 0.0
var _dist_start := 0.0

func _process(delta: float) -> void:
	_idle += delta
	if _idle > 3.0:
		yaw += auto_speed * delta
	pitch = clampf(pitch, -1.2, 0.15)
	distance = clampf(distance, min_distance, max_distance)
	var dir := Vector3(cos(pitch) * sin(yaw), -sin(pitch), cos(pitch) * cos(yaw))
	var p := target + dir * distance
	p.y = maxf(p.y, min_height)
	global_position = p
	look_at(target, Vector3.UP)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
		else:
			_touches.erase(e.index)
		if _touches.size() == 2:
			var ps: Array = _touches.values()
			_pinch_start = (ps[0] as Vector2).distance_to(ps[1])
			_dist_start = distance
	elif e is InputEventScreenDrag:
		_idle = 0.0
		_touches[e.index] = e.position
		if _touches.size() == 1:
			yaw -= e.relative.x * 0.005
			pitch -= e.relative.y * 0.004
		elif _touches.size() == 2 and _pinch_start > 0.0:
			var ps: Array = _touches.values()
			var d := (ps[0] as Vector2).distance_to(ps[1])
			distance = _dist_start * _pinch_start / maxf(d, 1.0)
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_idle = 0.0
		yaw -= e.relative.x * 0.005
		pitch -= e.relative.y * 0.004
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance *= 0.9
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance *= 1.1
	elif e is InputEventMagnifyGesture:
		distance /= e.factor
