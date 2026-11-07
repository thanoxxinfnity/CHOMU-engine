extends Control
class_name ChomuCustomBZierCurveEditorWidget

## Custom Bézier Curve Editor Widget
## A visual spline manipulation tool for animations and camera paths.
## Designed for mobile-first (NEON path) efficiency with low RAM overhead.
##
## This widget manages a set of Bézier points (anchor and control points)
## and provides methods to sample the curve and serialize its state.

signal curve_changed # Emitted when any point is moved or added/removed

## Represents a single Bézier point with its control handles
class BezierPoint:
	var position: Vector2
	var control_in: Vector2
	var control_out: Vector2
	var id: int

	func _init(p_id: int, p_pos: Vector2):
		id = p_id
		position = p_pos
		control_in = p_pos + Vector2(-20, 0)
		control_out = p_pos + Vector2(20, 0)

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"pos": position,
			"cin": control_in,
			"cout": control_out
		}

	static func from_dict(d: Dictionary) -> BezierPoint:
		var bp = BezierPoint.new(d.id, d.pos)
		bp.control_in = d.cin
		bp.control_out = d.cout
		return bp

@export var curve_color: Color = Color.CYAN
@export var handle_color: Color = Color.YELLOW
@export var point_radius: float = 6.0

var _points: Array[BezierPoint] = []
var _selected_point_id: int = -1
var _drag_mode: int = 0 # 0: None, 1: Position, 2: ControlIn, 3: ControlOut
var _rng: RandomNumberGenerator

func _init():
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

## Adds a point to the curve at the specified position.
func add_point(pos: Vector2) -> int:
	var id = _points.size()
	var bp = BezierPoint.new(id, pos)
	_points.append(bp)
	curve_changed.emit()
	return id

## Removes a point by ID.
func remove_point(id: int) -> bool:
	for i in range(_points.size()):
		if _points[i].id == id:
			_points.remove_at(i)
			# Re-index IDs to keep them deterministic/sequential
			for j in range(_points.size()):
				_points[j].id = j
			curve_changed.emit()
			return true
	return false

## Samples the curve at t (0.0 to 1.0).
func sample_curve(t: float) -> Vector2:
	if _points.size() == 0:
		return Vector2.ZERO
	if _points.size() == 1:
		return _points[0].position
	
	t = clampf(t, 0.0, 1.0)
	var num_segments = _points.size() - 1
	var segment_t = t * float(num_segments)
	var idx = int(floor(segment_t))
	
	if idx >= num_segments: 
		idx = num_segments - 1
	
	var local_t = segment_t - float(idx)
	var p0 = _points[idx]
	var p1 = _points[idx + 1]
	
	return _calculate_cubic_bezier(p0.position, p0.control_out, p1.control_in, p1.position, local_t)

func _calculate_cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var inv_t = 1.0 - t
	var b0 = inv_t * inv_t * inv_t
	var b1 = 3.0 * inv_t * inv_t * t
	var b2 = 3.0 * inv_t * t * t
	var b3 = t * t * t
	return p0 * b0 + p1 * b1 + p2 * b2 + p3 * b3

## Serializes the current curve state to a Dictionary.
func save_state() -> Dictionary:
	var data: Array[Dictionary] = []
	for p in _points:
		data.append(p.to_dict())
	return {"points": data}

## Loads the curve state from a Dictionary.
func load_state(data: Dictionary) -> void:
	_points.clear()
	if data.has("points"):
		for p_dict in data.points:
			_points.append(BezierPoint.from_dict(p_dict))
	curve_changed.emit()

func _draw() -> void:
	if _points.size() < 1: return
	
	for i in range(_points.size() - 1):
		var p0 = _points[i]
		var p1 = _points[i+1]
		var segment_points: PackedVector2Array = []
		for step in range(11):
			segment_points.append(_calculate_cubic_bezier(p0.position, p0.control_out, p1.control_in, p1.position, step / 10.0))
		draw_polyline(segment_points, curve_color, 2.0, true)
		draw_line(p0.position, p0.control_out, handle_color, 1.0)
		draw_line(p1.position, p1.control_in, handle_color, 1.0)

	for p in _points:
		draw_circle(p.position, point_radius, Color.WHITE)
		draw_circle(p.control_in, point_radius * 0.6, handle_color)
		draw_circle(p.control_out, point_radius * 0.6, handle_color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_press(event.position)
			else:
				_drag_mode = 0
				_selected_point_id = -1
	elif event is InputEventMouseMotion and _drag_mode != 0:
		_handle_drag(event.position)

func _handle_press(pos: Vector2) -> void:
	for p in _points:
		if p.position.distance_to(pos) < point_radius * 2:
			_selected_point_id = p.id
			_drag_mode = 1
			return
		if p.control_in.distance_to(pos) < point_radius * 2:
			_selected_point_id = p.id
			_drag_mode = 2
			return
		if p.control_out.distance_to(pos) < point_radius * 2:
			_selected_point_id = p.id
			_drag_mode = 3
			return

func _handle_drag(pos: Vector2) -> void:
	if _selected_point_id == -1: return
	var p = _points[_selected_point_id]
	match _drag_mode:
		1: p.position = pos
		2: p.control_in = pos
		3: p.control_out = pos
	queue_redraw()
	curve_changed.emit()
