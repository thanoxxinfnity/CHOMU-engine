extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/global_variable_property_registry.gd")

func run(t: Node) -> void:
	var reg := Impl.new(42)
	
	# Test 1: Basic Registration and Retrieval
	reg.register_variable("player_health", 100, TYPE_INT)
	t.check("S-95 basic get/set", reg.get_variable("player_health") == 100, "Should retrieve initial value")
	
	reg.set_variable("player_health", 80)
	t.check("S-95 update value", reg.get_variable("player_health") == 80, "Should update value to 80")
	
	# Test 2: Type Safety
	reg.register_variable("game_speed", 1.0, TYPE_FLOAT)
	var success_type := reg.set_variable("game_speed", "fast") # Wrong type
	t.check("S-95 type safety", success_type == false, "Should reject String for FLOAT hint")
	t.check("S-95 type persistence", reg.get_variable("game_speed") == 1.0, "Value should remain unchanged after failed type set")
	
	# Test 3: Read-Only Protection
	reg.register_variable("gravity", -9.81, TYPE_FLOAT, true)
	var success_ro := reg.set_variable("gravity", -1.62)
	t.check("S-95 read-only protection", success_ro == false, "Should not allow modifying read-only variable")
	t.check("S-95 read-only value", reg.get_variable("gravity") == -9.81, "Read-only value should be preserved")
	
	# Test 4: Serialization (Save/Load)
	reg.register_variable("score", 0, TYPE_INT)
	reg.set_variable("score", 500)
	var state := reg.save_state()
	t.check("S-95 save state", state.has("score") and state["score"] == 500, "Save state should contain current values")
	
	var reg2 := Impl.new(42)
	reg2.register_variable("score", 0, TYPE_INT) # Must be registered to be loaded
	reg2.load_state(state)
	t.check("S-95 load state", reg2.get_variable("score") == 500, "Loaded state should restore values")
	
	# Test 5: Deterministic RNG
	var r1 := Impl.new(100).get_random_float()
	var r2 := Impl.new(100).get_random_float()
	t.check("S-95 deterministic RNG", r1 == r2, "Same seed should produce same random float")
	
	# Test 6: Unregistration
	reg.register_variable("temp", 1, TYPE_INT)
	reg.unregister_variable("temp")
	t.check("S-95 unregister", reg.has_variable("temp") == false, "Variable should be removed from registry")
	
	# Test 7: Default Value
	var val := reg.get_variable("non_existent", "default_val")
	t.check("S-95 default value", val == "default_val", "Should return default when key is missing")
