extends RefCounted
class_name ChomuCoverSystemForAi

## S-14 Cover System for AI
## Provides a data-driven system for AI agents to find and utilize cover.
## It handles the spatial analysis of "cover points" relative to a threat source.

## Represents a specific point where an AI can take cover.
class CoverPoint:
	var id: int
	var position: Vector3
	var normal: Vector3 # Direction the cover faces (away from the wall/obstacle)
	var type: String # e.g., "full", "half", "low"
	var current_occupant_id: String = ""
	
	func _init(p_id: int, p_pos: Vector3, p_norm: Vector3, p_type: String = "full"):
		id = p_id
		position = p_pos
		normal = p_norm
		type = p_type

## The main system managing cover points and queries.
## Designed for low RAM and deterministic behavior.
## This class is RefCounted and does not depend on the SceneTree for logic,
## though it uses PhysicsDirectSpaceState3D for raycasting.
##
## Public API:
## - add_cover_point(pos: Vector3, normal: Vector3, type: String) -> int
## - remove_cover_point(id: int)
## - find_best_cover(agent_pos: Vector3, threat_pos: Vector3, space_state: PhysicsDirectSpaceState3D, preferences: Dictionary) -> CoverPoint
## - occupy_cover(point_id: int, agent_id: String) -> bool
## - release_cover(point_id: int)
## - get_state() -> Dictionary
## - set_state(state: Dictionary)

var _points: Dictionary = {} # int -> CoverPoint
var _next_id: int = 0
var _rng: RandomNumberGenerator

func _init(seed_val: int = 42):
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val

## Registers a cover point in the system.
func add_cover_point(pos: Vector3, normal: Vector3, type: String = "full") -> int:
	var id := _next_id
	_points[id] = CoverPoint.new(id, pos, normal, type)
	_next_id += 1
	return id

## Removes a cover point from the system.
func remove_cover_point(id: int) -> void:
	_points.erase(id)

## Finds the most suitable cover point for an agent given a threat position.
## preferences: { "type": String, "max_dist": float, "min_dist": float }
func find_best_cover(agent_pos: Vector3, threat_pos: Vector3, space_state: PhysicsDirectSpaceState3D, preferences: Dictionary) -> CoverPoint:
	var best_point: CoverPoint = null
	var best_score: float = -1.0
	
	var pref_type := preferences.get("type", "full")
	var max_dist := preferences.get("max_dist", 20.0)
	var min_dist := preferences.get("min_dist", 2.0)
	
	for id in _points:
		var cp = _points[id]
		
		# 1. Availability & Type
		if cp.current_occupant_id != "" or cp.type != pref_type:
			continue
			
		# 2. Distance check
		var dist_to_cp := agent_pos.distance_to(cp.position)
		if dist_to_cp > max_dist or dist_to_cp < min_dist:
			continue
			
		# 3. Line of Sight (LoS) from Threat to Cover Point
		# The cover point is only valid if the threat cannot see the point directly
		# (or is blocked by the cover geometry).
		var query := PhysicsRayQueryParameters3D.new()
		query.from = threat_pos
		query.to = cp.position
		var result := space_state.intersect_ray(query)
		
		# If the ray hits nothing or hits the agent/cover point itself, it's not "cover"
		# In a real scenario, we check if the hit is the cover object.
		if result.is_empty():
			continue
			
		# 4. Scoring (Heuristic)
		# Score = (Distance from threat) + (Alignment of cover normal to threat)
		var threat_to_cp_dir = (cp.position - threat_pos).normalized()
		var alignment = cp.normal.dot(-threat_to_cp_dir) # Higher if normal faces threat
		
		var score = (threat_pos.distance_to(cp.position) / max_dist) + (alignment * 2.0)
		
		if score > best_score:
			best_score = score
			best_point = cp
			
	return best_point

## Marks a cover point as occupied by a specific agent.
func occupy_cover(point_id: int, agent_id: String) -> bool:
	if _points.has(point_id):
		var cp = _points[point_id]
		if cp.current_occupant_id == "":
			cp.current_occupant_id = agent_id
			return true
	return false

## Marks a cover point as vacant.
func release_cover(point_id: int) -> void:
	if _points.has(point_id):
		_points[point_id].current_occupant_id = ""

## Serializes the current state of the cover system.
func get_state() -> Dictionary:
	var state := {
		"next_id": _next_id,
		"points": []
	}
	for id in _points:
		var cp = _points[id]
		state["points"].append({
			"id": cp.id,
			"pos": cp.position,
			"norm": cp.normal,
			"type": cp.type,
			"occ": cp.current_occupant_id
		})
	return state

## Restores the system state from a dictionary.
func set_state(state: Dictionary) -> void:
	_next_id = state.get("next_id", 0)
	_points.clear()
	for p_data in state.get("points", []):
		var cp = CoverPoint.new(p_data["id"], p_data["pos"], p_data["norm"], p_data["type"])
		cp.current_occupant_id = p_data["occ"]
		_points[cp.id] = cp
