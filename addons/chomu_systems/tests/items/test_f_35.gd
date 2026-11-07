extends RefCounted

const Impl := preload("res://addons/chomu_systems/net/interest_grid.gd")

func run(t: Node) -> void:
	var grid := Impl.new(10.0)
	
	# Test 1: Basic relevancy
	grid.upsert_entity(1, Vector3(0, 0, 0))
	grid.upsert_entity(2, Vector3(5, 0, 0))
	grid.upsert_entity(3, Vector3(20, 0, 0))
	
	grid.set_client(100, Vector3(0, 0, 0), 7.0)
	var rel = grid.relevant(100)
	t.check("F-35 Basic relevancy", 1 in rel and 2 in rel and not 3 in rel, "Client should see entities 1 and 2")
	
	# Test 2: Moving entity produces entered/left
	grid.update() # Initialize current_set
	grid.upsert_entity(3, Vector3(2, 0, 0)) # Move 3 into range
	var changes = grid.update()
	t.check("F-35 Entity entered", changes.get(100, {}).get("entered", []).has(3), "Entity 3 should have entered range")
	
	grid.upsert_entity(2, Vector3(50, 0, 0)) # Move 2 out of range
	changes = grid.update()
	t.check("F-35 Entity left", changes.get(100, {}).get("left", []).has(2), "Entity 2 should have left range")
	
	# Test 3: Entity removal
	grid.upsert_entity(4, Vector3(1, 0, 0))
	grid.update()
	grid.remove_entity(4)
	changes = grid.update()
	t.check("F-35 Entity removed", changes.get(100, {}).get("left", []).has(4), "Removed entity should trigger left event")
	
	# Test 4: Spatial hash efficiency
	grid.upsert_entity(1000, Vector3(1000, 1000, 1000))
	grid.upsert_entity(1001, Vector3(-1000, -1000, -1000))
	
	grid.set_client(200, Vector3(0, 0, 0), 5.0)
	grid.relevant(200)
	
	t.check("F-35 Spatial efficiency", grid.last_cells_scanned < 100, "Should only scan nearby cells, not the whole world")
	
	# Test 5: Client movement
	grid.set_client(200, Vector3(1000, 1000, 1000), 5.0)
	var rel_far = grid.relevant(200)
	t.check("F-35 Client movement", 1000 in rel_far, "Client should see entity 1000 after moving")
