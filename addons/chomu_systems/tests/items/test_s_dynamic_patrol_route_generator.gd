extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/dynamic_patrol_route_generator.gd")

func run(t: Node) -> void:
	# F-10.1: Basic route generation creates correct number of waypoints
	var generator := Impl.new()
	var config := Impl.PatrolConfig.new()
	config.min_waypoints = 3
	config.max_waypoints = 5
	config.seed = 42
	generator.set_config(config)
	
	var start_pos := Vector3.ZERO
	var route := generator.create_patrol(start_pos)
	t.check("F-10.1 route generation waypoint count", 
		route.waypoints.size() >= config.min_waypoints and route.waypoints.size() <= config.max_waypoints,
		"Route should have between min and max waypoints")
	
	# F-10.2: Waypoints are connected properly
	var has_connections := true
	for wp in route.waypoints:
		if wp.connections.is_empty():
			has_connections = false
			break
	t.check("F-10.2 waypoint connections exist", has_connections, "Each waypoint should have at least one connection")
	
	# F-10.3: Deterministic behavior with same seed
	var generator2 := Impl.new()
	generator2.set_config(config)
	var route2 := generator2.create_patrol(start_pos)
	t.check("F-10.3 deterministic generation same waypoint count", 
		route.waypoints.size() == route2.waypoints.size(),
		"Same seed should produce same number of waypoints")
	
	# F-10.4: Advance patrol moves to next waypoint
	generator.start_patrol(route)
	var first_wp := generator.get_current_waypoint(route)
	var next_wp := generator.advance_patrol(route)
	t.check("F-10.4 advance patrol moves waypoint", 
		first_wp.id != next_wp.id,
		"Advancing should move to different waypoint")
	
	# F-10.5: Random waypoint selection returns valid waypoint
	var random_wp := generator.select_random_waypoint(route)
	t.check("F-10.5 random waypoint selection valid", 
		random_wp != null and route.waypoints.has(random_wp),
		"Random selection should return waypoint from route")
	
	# F-10.6: Route wraps around at end
	route.current_waypoint_idx = route.waypoints.size() - 1
	var wrapped_wp := generator.advance_patrol(route)
	t.check("F-10.6 patrol wraps around", 
		wrapped_wp.id == route.waypoints[0].id,
		"Advancing past last waypoint should wrap to first")
	
	# F-10.7: Save and load state preserves data
	var state := generator.save_state()
	var generator3 := Impl.new()
	generator3.load_state(state)
	t.check("F-10.7 save/load preserves waypoint count", 
		generator3.get_all_waypoints().size() == generator.get_all_waypoints().size(),
		"Loaded generator should have same waypoints")
	
	# F-10.8: Clear routes removes all data
	generator.clear_routes()
	t.check("F-10.8 clear routes removes waypoints", 
		generator.get_all_waypoints().is_empty(),
		"After clear, no waypoints should exist")
	
	# F-10.9: Get waypoint by ID returns correct waypoint
	generator.set_config(config)
	var test_route := generator.create_patrol(start_pos)
	var test_wp := test_route.waypoints[0]
	var found_wp: Impl.Waypoint = generator.get_waypoint(test_wp.id)
	t.check("F-10.9 get waypoint by ID", 
		found_wp != null and found_wp.id == test_wp.id,
		"Should find waypoint by its ID")
	
	# F-10.10: Route activation status works correctly
	t.check("F-10.10 route activation status", 
		!generator.is_route_active(test_route),
		"New route should not be active until started")
	generator.start_patrol(test_route)
	t.check("F-10.10 route activation after start", 
		generator.is_route_active(test_route),
		"Started route should be active")
