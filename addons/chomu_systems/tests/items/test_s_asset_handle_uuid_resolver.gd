extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/asset_handle_uuid_resolver.gd")

func run(t: Node) -> void:
	var resolver := Impl.new(42)
	
	# Test 1: Basic Registration and Resolution
	var path1 := "res://assets/textures/hero.png"
	var uuid1 := resolver.register_asset(path1)
	t.check("S-56 Basic Registration", uuid1 != "", "UUID should be generated")
	t.check("S-56 Basic Resolution", resolver.resolve_uuid(uuid1) == path1, "UUID should resolve to original path")
	
	# Test 2: Determinism (Same path, same resolver instance)
	var uuid1_again := resolver.register_asset(path1)
	t.check("S-56 Idempotency", uuid1 == uuid1_again, "Registering same path twice should return same UUID")
	
	# Test 3: Path Update (Renaming)
	var path1_new := "res://assets/textures/hero_final_v2.png"
	var success := resolver.update_path(uuid1, path1_new)
	t.check("S-56 Path Update Success", success == true, "Updating path should return true")
	t.check("S-56 Path Update Resolution", resolver.resolve_uuid(uuid1) == path1_new, "UUID should now resolve to new path")
	t.check("S-56 Path Update Reverse", resolver.get_uuid_for_path(path1_new) == uuid1, "New path should map back to UUID")
	t.check("S-56 Path Update Old Cleanup", resolver.get_uuid_for_path(path1) == "", "Old path should no longer be mapped")
	
	# Test 4: Unregistration
	var path2 := "res://assets/sounds/jump.wav"
	var uuid2 := resolver.register_asset(path2)
	resolver.unregister_asset(uuid2)
	t.check("S-56 Unregister Resolution", resolver.resolve_uuid(uuid2) == "", "Unregistered UUID should resolve to empty")
	t.check("S-56 Unregister Reverse", resolver.get_uuid_for_path(path2) == "", "Unregistered path should resolve to empty")
	
	# Test 5: State Persistence
	var resolver2 := Impl.new(99) # Different seed
	var path3 := "res://assets/models/tree.glb"
	var uuid3 := resolver.register_asset(path3)
	
	var state := resolver.save_state()
	resolver2.load_state(state)
	
	t.check("S-56 State Load Resolution", resolver2.resolve_uuid(uuid3) == path3, "Loaded state should resolve UUIDs correctly")
	t.check("S-56 State Load Reverse", resolver2.get_uuid_for_path(path3) == uuid3, "Loaded state should resolve paths correctly")
	
	# Test 6: Determinism across instances with same seed
	var resolver_a := Impl.new(100)
	var resolver_b := Impl.new(100)
	var path_test := "res://test.png"
	var uuid_a := resolver_a.register_asset(path_test)
	var uuid_b := resolver_b.register_asset(path_test)
	t.check("S-56 Seed Determinism", uuid_a == uuid_b, "Same seed and path should produce same UUID")
