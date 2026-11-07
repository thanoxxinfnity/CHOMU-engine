extends RefCounted
class_name ChomuRopeCableVerletIntegration

## S-27 Rope & Cable Verlet Integration
## A high-performance, data-driven Verlet integration system for simulating 
## ropes, cables, and chains. Designed for mobile-first performance.

class Point:
	var position: Vector3
	var prev_position: Vector3
	var acceleration: Vector3
	var is_pinned: bool
	var mass: float

	func _init(pos: Vector3, m: float = 1.0, pinned: bool = false):
		position = pos
		prev_position = pos
		acceleration = Vector3.ZERO
		mass = m
		is_pinned = pinned

class Constraint:
	var p1_idx: int
	var p2_idx: int
	var rest_length: float
	var stiffness: float

	func _init(idx1: int, idx2: int, length: float, stiff: float = 1.0):
		p1_idx = idx1
		p2_idx = idx2
		rest_length = length
		stiffness = stiff

# Internal state
var _points: Array[Point] = []
var _constraints: Array[Constraint] = []
var _gravity: Vector3 = Vector3(0, -9.81, 0)
var _drag: float = 0.98
var _iterations: int = 5

## Initializes a rope with a set of points and constraints.
## points_data: Array of { "pos": Vector3, "mass": float, "pinned": bool }
## constraints_data: Array of { "p1": int, "p2": int, "stiffness": float }
func setup(points_data: Array, constraints_data: Array) -> void:
	_points.clear()
	_constraints.clear()
	
	for p in points_data:
		var pt = Point.new(p.get("pos", Vector3.ZERO), p.get("mass", 1.0), p.get("pinned", false))
		_points.append(pt)
	
	for c in constraints_data:
		var p1 = c.get("p1", 0)
		var p2 = c.get("p2", 0)
		var dist = _points[p1].position.distance_to(_points[p2].position)
		var con = Constraint.new(p1, p2, dist, c.get("stiffness", 1.0))
		_constraints.append(con)

## Updates the simulation by one time step.
func step(delta: float, external_force: Vector3 = Vector3.ZERO) -> void:
	if _points.is_empty():
		return

	# 1. Verlet Integration
	for p in _points:
		if p.is_pinned:
			continue
		
		var velocity = (p.position - p.prev_position) * _drag
		p.prev_position = p.position
		p.position += velocity + (p.acceleration + _gravity + external_force) * delta * delta
		p.acceleration = Vector3.ZERO

	# 2. Constraint Satisfaction (Relaxation)
	for i in range(_iterations):
		for c in _constraints:
			var p1 = _points[c.p1_idx]
			var p2 = _points[c.p2_idx]
			
			var delta_pos = p2.position - p1.position
			var current_dist = delta_pos.length()
			if current_dist < 0.0001: continue
			
			var diff = (current_dist - c.rest_length) / current_dist
			var correction = delta_pos * diff * c.stiffness
			
			var m1_inv = 0.0 if p1.is_pinned else (1.0 / p1.mass)
			var m2_inv = 0.0 if p2.is_pinned else (1.0 / p2.mass)
			var total_inv_mass = m1_inv + m2_inv
			
			if total_inv_mass > 0:
				p1.position += correction * (m1_inv / total_inv_mass)
				p2.position -= correction * (m2_inv / total_inv_mass)

## Pins a specific point to a new world position.
func pin_point(index: int, position: Vector3) -> void:
	if index >= 0 and index < _points.size():
		var p = _points[index]
		p.is_pinned = true
		p.position = position
		p.prev_position = position

## Applies a force to a specific point.
func apply_force(index: int, force: Vector3) -> void:
	if index >= 0 and index < _points.size():
		_points[index].acceleration += force / _points[index].mass

## Returns the current positions of all points.
func get_positions() -> PackedVector3Array:
	var result = PackedVector3Array()
	for p in _points:
		result.append(p.position)
	return result

## Serializes the current state of the rope.
func save_state() -> Dictionary:
	var pts_data = []
	for p in _points:
		pts_data.append({
			"pos": p.position,
			"prev": p.prev_position,
			"pinned": p.is_pinned,
			"mass": p.mass
		})
	
	var cons_data = []
	for c in _constraints:
		cons_data.append({
			"p1": c.p1_idx,
			"p2": c.p2_idx,
			"len": c.rest_length,
			"stiff": c.stiffness
		})
		
	return {
		"points": pts_data,
		"constraints": cons_data,
		"gravity": _gravity,
		"drag": _drag,
		"iterations": _iterations
	}

## Restores the state of the rope.
func load_state(data: Dictionary) -> void:
	_gravity = data.get("gravity", _gravity)
	_drag = data.get("drag", _drag)
	_iterations = data.get("iterations", _iterations)
	
	var pts_data = data.get("points", [])
	_points.clear()
	for p in pts_data:
		var pt = Point.new(p.pos, p.mass, p.pinned)
		pt.prev_position = p.prev
		_points.append(pt)
	
	var cons_data = data.get("constraints", [])
	_constraints.clear()
	for c in cons_data:
		var con = Constraint.new(c.p1, c.p2, c.len, c.stiff)
		_constraints.append(con)
