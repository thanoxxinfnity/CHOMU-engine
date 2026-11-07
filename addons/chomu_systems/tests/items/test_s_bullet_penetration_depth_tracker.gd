extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/bullet_penetration_depth_tracker.gd")

func run(t: Node) -> void:
	## Test 1: Material registration
	var tracker = Impl.new()
	var registered = tracker.register_material("wood", 0.7, 0.05, 0.3)
	t.check("S-64 material registration succeeds", registered, "Should return true for new material")
	
	registered = tracker.register_material("wood", 0.7, 0.05, 0.3)
	t.check("S-64 duplicate material registration fails", !registered, "Should return false for existing material")
	
	## Test 2: Material retrieval
	var mat = tracker.get_material("wood")
	t.check("S-64 material retrieval works", mat != null, "Should return material object")
	t.check("S-64 material density correct", mat.density == 0.7, "Density should be 0.7")
	t.check("S-64 material thickness correct", mat.thickness == 0.05, "Thickness should be 0.05")
	
	## Test 3: Penetration processing
	var result = tracker.process_penetration("wood", 0.03)
	t.check("S-64 penetration result created", result != null, "Should return result object")
	t.check("S-64 penetration depth tracked", result.penetration_depth == 0.03, "Depth should be 0.03")
	t.check("S-64 density reduced after penetration", result.remaining_density < result.original_density, "Density should decrease")
	
	## Test 4: Full penetration
	result = tracker.process_penetration("wood", 0.5)
	t.check("S-64 full penetration detected", result.fully_penetrated, "Should be fully penetrated with deep penetration")
	
	## Test 5: Trajectory simulation
	tracker.clear_tracking()
	var materials: Array = [
		{"material_id": "wood", "thickness": 0.05},
		{"material_id": "metal", "thickness": 0.02}
	]
	tracker.register_material("metal", 0.9, 0.02, 0.8)
	var results = tracker.simulate_trajectory(materials)
	t.check("S-64 trajectory simulation returns results", results.size() > 0, "Should return at least one result")
	t.check("S-64 trajectory accumulates depth", results[0].penetration_depth > 0, "Penetration depth should accumulate")
	
	## Test 6: Event counting
	var count = tracker.get_event_count()
	t.check("S-64 event count accurate", count == materials.size(), "Should have correct event count")
	
	## Test 7: State serialization
	tracker.register_material("concrete", 1.0, 0.1, 0.9)
	var state = tracker.save_state()
	t.check("S-64 state saved to dictionary", state is Dictionary, "Should return Dictionary")
	t.check("S-64 state contains materials", state.has("materials"), "Should have materials key")
	t.check("S-64 state contains event count", state.has("total_penetration_events"), "Should have event count key")
	
	## Test 8: State loading
	var new_tracker = Impl.new()
	new_tracker.load_state(state)
	var loaded_count = new_tracker.get_event_count()
	t.check("S-64 state loaded correctly", loaded_count == count, "Event count should match after load")
	
	var loaded_mats = new_tracker.get_registered_materials()
	t.check("S-64 materials loaded from state", loaded_mats.has("concrete"), "Concrete material should be loaded")
	
	## Test 9: Non-existent material handling
	result = tracker.process_penetration("nonexistent", 0.1)
	t.check("S-64 handles missing material", result.remaining_density == 1.0, "Should return full density for unknown material")
	
	## Test 10: Deterministic behavior with seed
	var tracker1 = Impl.new(42)
	tracker1.register_material("test", 0.5, 0.1, 0.5)
	var tracker2 = Impl.new(42)
	tracker2.register_material("test", 0.5, 0.1, 0.5)
	
	var results1 = tracker1.simulate_trajectory([{"material_id": "test", "thickness": 0.1}])
	var results2 = tracker2.simulate_trajectory([{"material_id": "test", "thickness": 0.1}])
	
	t.check("S-64 deterministic with same seed", results1[0].penetration_depth == results2[0].penetration_depth, "Same seed should produce same results")
	
	## Test 11: Clear tracking
	tracker.clear_tracking()
	t.check("S-64 tracking cleared", tracker.get_event_count() == 0, "Event count should be zero after clear")
	
	## Test 12: Block detection
	var blocked = tracker.should_block_bullet("wood", 10.0)
	t.check("S-64 low energy blocked", blocked, "Low energy bullet should be blocked")
	
	blocked = tracker.should_block_bullet("wood", 100.0)
	t.check("S-64 high energy not blocked", !blocked, "High energy bullet should not be blocked")
	
	## Cleanup - RefCounted objects are garbage collected, no need to free
