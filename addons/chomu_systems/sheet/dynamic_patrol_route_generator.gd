extends RefCounted
class_name ChomuDynamicPatrolRouteGenerator

## Dynamic Patrol Route Generator for AI guards.
## Generates and manages waypoint routes with random waypoint selection for wandering guards.
## Uses seeded RNG for deterministic behavior. Mobile-first design with low RAM footprint.

## Waypoint data structure
class Waypoint:
	extends RefCounted
	var position: Vector3
	var id: int
	var connections: Array[int] = []  # Connected waypoint IDs

	func _init(p: Vector3, waypoint_id: int) -> void:
		position = p
		id = waypoint_id

## Configuration for patrol route generation
class PatrolConfig:
	extends RefCounted
	var min_waypoints: int = 3
	var max_waypoints: int = 8
	var waypoint_spacing: float = 5.0
	var connection_probability: float = 0.6
	var allow_loops: bool = true
	var seed: int = 12345

	func _init() -> void:
		pass

## Main patrol route data structure
class PatrolRoute:
	extends RefCounted
	var waypoints: Array[Waypoint] = []
	var current_waypoint_idx: int = 0
	var route_id: String = ""
	var is_active: bool = false

	func _init(id: String = "") -> void:
		route_id = id

## Dynamic Patrol Route Generator
var _rng: RandomNumberGenerator
var _waypoints: Array[Waypoint] = []
var _routes: Array[PatrolRoute] = []
var _config: PatrolConfig
var _next_waypoint_id: int = 0

func _init(seed: int = 12345) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed
	_config = PatrolConfig.new()

## Sets the patrol configuration
func set_config(config: PatrolConfig) -> void:
	_config = config
	_rng.seed = config.seed

## Generates a new patrol route with specified number of waypoints
func generate_route(start_position: Vector3, waypoint_count: int = -1) -> PatrolRoute:
	if waypoint_count == -1:
		waypoint_count = _rng.randi_range(_config.min_waypoints, _config.max_waypoints)
	
	var route := PatrolRoute.new()
	route.route_id = "route_%d" % _routes.size()
	
	# Generate waypoints in a roughly circular pattern around start position
	var angle_step := TAU / waypoint_count
	for i in range(waypoint_count):
		var angle := angle_step * i + _rng.randf_range(0, TAU)
		var radius := _config.waypoint_spacing * _rng.randf_range(0.5, 1.5)
		var offset := Vector3(cos(angle), 0, sin(angle)) * radius
		var pos := start_position + offset
		
		var wp := Waypoint.new(pos, _next_waypoint_id)
		_next_waypoint_id += 1
		_waypoints.append(wp)
		route.waypoints.append(wp)
	
	# Connect waypoints
	_connect_waypoints(route)
	
	_routes.append(route)
	return route

## Connects waypoints within a route based on probability
func _connect_waypoints(route: PatrolRoute) -> void:
	var count := route.waypoints.size()
	if count < 2:
		return
	
	for i in range(count):
		var wp := route.waypoints[i]
		
		# Always connect to next waypoint (sequential)
		var next_idx := (i + 1) % count
		wp.connections.append(route.waypoints[next_idx].id)
		
		# Random additional connections
		if _config.allow_loops and count > 3:
			for j in range(count):
				if j != i and j != next_idx:
					if _rng.randf() < _config.connection_probability:
						wp.connections.append(route.waypoints[j].id)

## Gets a waypoint by ID
func get_waypoint(id: int) -> Waypoint:
	for wp in _waypoints:
		if wp.id == id:
			return wp
	return null

## Gets all waypoints
func get_all_waypoints() -> Array[Waypoint]:
	return _waypoints.duplicate()

## Creates a new patrol route for an AI guard
func create_patrol(start_position: Vector3) -> PatrolRoute:
	return generate_route(start_position)

## Advances the patrol to the next waypoint
func advance_patrol(route: PatrolRoute) -> Waypoint:
	if route.waypoints.is_empty():
		return null
	
	route.current_waypoint_idx = (route.current_waypoint_idx + 1) % route.waypoints.size()
	return route.waypoints[route.current_waypoint_idx]

## Gets the current waypoint in a patrol route
func get_current_waypoint(route: PatrolRoute) -> Waypoint:
	if route.waypoints.is_empty():
		return null
	return route.waypoints[route.current_waypoint_idx]

## Selects a random waypoint from the route for wandering behavior
func select_random_waypoint(route: PatrolRoute) -> Waypoint:
	if route.waypoints.is_empty():
		return null
	
	var idx := _rng.randi_range(0, route.waypoints.size() - 1)
	return route.waypoints[idx]

## Gets the next waypoint from current position using pathfinding
func get_next_waypoint(current_pos: Vector3, current_wp: Waypoint, route: PatrolRoute) -> Waypoint:
	if route.waypoints.is_empty():
		return null
	
	# Find closest waypoint to current position
	var closest_wp := current_wp
	var closest_dist := INF
	
	for wp in route.waypoints:
		if wp.id == current_wp.id:
			continue
		var dist := current_pos.distance_to(wp.position)
		if dist < closest_dist:
			closest_dist = dist
			closest_wp = wp
	
	return closest_wp

## Starts a patrol route
func start_patrol(route: PatrolRoute) -> void:
	route.is_active = true
	route.current_waypoint_idx = 0

## Stops a patrol route
func stop_patrol(route: PatrolRoute) -> void:
	route.is_active = false

## Checks if a route is active
func is_route_active(route: PatrolRoute) -> bool:
	return route.is_active

## Clears all routes and waypoints
func clear_routes() -> void:
	_waypoints.clear()
	_routes.clear()
	_next_waypoint_id = 0

## Gets all active routes
func get_active_routes() -> Array[PatrolRoute]:
	var active: Array[PatrolRoute] = []
	for route in _routes:
		if route.is_active:
			active.append(route)
	return active

## Saves the current state to a Dictionary
func save_state() -> Dictionary:
	return {
		"rng_seed": _rng.seed,
		"next_waypoint_id": _next_waypoint_id,
		"waypoints": _serialize_waypoints(),
		"routes": _serialize_routes(),
		"config": {
			"min_waypoints": _config.min_waypoints,
			"max_waypoints": _config.max_waypoints,
			"waypoint_spacing": _config.waypoint_spacing,
			"connection_probability": _config.connection_probability,
			"allow_loops": _config.allow_loops,
			"seed": _config.seed
		}
	}

## Loads state from a Dictionary
func load_state(data: Dictionary) -> void:
	if "rng_seed" in data:
		_rng.seed = data["rng_seed"]
	if "next_waypoint_id" in data:
		_next_waypoint_id = data["next_waypoint_id"]
	if "waypoints" in data:
		_waypoints = _deserialize_waypoints(data["waypoints"])
	if "routes" in data:
		_routes = _deserialize_routes(data["routes"])
	if "config" in data:
		var c = data["config"]
		_config.min_waypoints = c.get("min_waypoints", 3)
		_config.max_waypoints = c.get("max_waypoints", 8)
		_config.waypoint_spacing = c.get("waypoint_spacing", 5.0)
		_config.connection_probability = c.get("connection_probability", 0.6)
		_config.allow_loops = c.get("allow_loops", true)
		_config.seed = c.get("seed", 12345)

## Serializes waypoints to array of dictionaries
func _serialize_waypoints() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wp in _waypoints:
		result.append({
			"id": wp.id,
			"position": wp.position,
			"connections": wp.connections.duplicate()
		})
	return result

## Deserializes waypoints from array of dictionaries
func _deserialize_waypoints(data: Array[Dictionary]) -> Array[Waypoint]:
	var result: Array[Waypoint] = []
	for d in data:
		var wp := Waypoint.new(d["position"], d["id"])
		wp.connections = d.get("connections", [])
		result.append(wp)
	return result

## Serializes routes to array of dictionaries
func _serialize_routes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for route in _routes:
		var wp_ids: Array[int] = []
		for wp in route.waypoints:
			wp_ids.append(wp.id)
		result.append({
			"route_id": route.route_id,
			"waypoint_ids": wp_ids,
			"current_idx": route.current_waypoint_idx,
			"is_active": route.is_active
		})
	return result

## Deserializes routes from array of dictionaries
func _deserialize_routes(data: Array[Dictionary]) -> Array[PatrolRoute]:
	var result: Array[PatrolRoute] = []
	for d in data:
		var route := PatrolRoute.new(d["route_id"])
		route.current_waypoint_idx = d.get("current_idx", 0)
		route.is_active = d.get("is_active", false)
		
		# Reconstruct waypoint references
		for wp_id in d.get("waypoint_ids", []):
			var wp := get_waypoint(wp_id)
			if wp:
				route.waypoints.append(wp)
		
		result.append(route)
	return result
