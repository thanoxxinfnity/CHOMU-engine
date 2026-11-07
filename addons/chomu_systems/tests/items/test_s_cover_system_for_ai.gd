extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/cover_system_for_ai.gd")

func run(t: Node) -> void:
	var sys := Impl.new()
	
	# Setup a simple environment: a wall at x=0
	# We need a StaticBody3D to act as cover for the raycast
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 5, 5)
	col.shape = shape
	wall.add_child(col)
	wall.position = Vector3(0, 0, 0)
	t.add_child(wall)
	
	# Cover point behind the wall (relative to threat at x=10)
	# Point is at (-1, 0, 0), Normal is (1, 0, 0) [facing the wall]
	# Wait, normal should face AWAY from the wall for the agent to lean against it.
	# If wall is at 0, and agent is at -1, normal is (-1, 0, 0).
	var cp_id := sys.add_cover_point(Vector3(-1, 0, 0), Vector3(-1, 0, 0), "full")
	
	var threat_pos := Vector3(10, 0, 0)
	var agent_pos := Vector3(-2, 0, 0)
	var space = t.get_world_3d().direct_space_state
	
	var prefs := { "type": "full", "max_dist": 10.0, "min_dist": 0.1 }
	
	t.check("S-14 find_best_cover finds valid point", 
		sys.find_best_cover(agent_pos, threat_pos, space, prefs) != null, 
		"Should find the point behind the wall")
	
	t.check("S-14 occupy_cover marks as busy", 
		sys.occupy_cover(cp_id, "agent_1") == true, 
		"Should occupy the point")
	
	t.check("S-14 find_best_cover ignores occupied", 
		sys.find_best_cover(agent_pos, threat_pos, space, prefs) == null, 
		"Occupied point should not be returned")
	
	sys.release_cover(cp_id)
	t.check("S-14 release_cover makes point available", 
		sys.find_best_cover(agent_pos, threat_pos, space, prefs) != null, 
		"Point should be available again after release")
	
	var state := sys.get_state()
	var sys2 := Impl.new()
	sys2.set_state(state)
	t.check("S-14 state save/load", 
		sys2._points.size() == sys._points.size(), 
		"State should be restored correctly")
	
	wall.queue_free()
