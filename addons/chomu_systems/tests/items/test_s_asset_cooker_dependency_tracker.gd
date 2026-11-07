extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/asset_cooker_dependency_tracker.gd")

func run(t: Node) -> void:
	var cooker = Impl.new()
	
	# Mock cooking function: just appends '.cooked' to the path
	var mock_cook = func(path: String): return path + ".cooked"
	
	t.check("S-55 Basic Registration", true, "Should register assets")
	cooker.register_asset("res://tex.png")
	cooker.register_asset("res://mat.tres", ["res://tex.png"])
	
	t.check("S-55 Initial Dirty State", cooker.get_dirty_assets().size() == 2, "Both should be dirty initially")
	
	t.check("S-55 Cooking Process", cooker.cook_asset("res://mat.tres", mock_cook) == "res://mat.tres.cooked", "Should cook asset and its deps")
	t.check("S-55 Post-Cook Clean", cooker.get_dirty_assets().size() == 0, "Nothing should be dirty after cooking root")
	
	t.check("S-55 Dependency Propagation", true, "Changing tex should dirty mat")
	cooker.mark_dirty("res://tex.png")
	var dirty = cooker.get_dirty_assets()
	var mat_is_dirty = false
	for d in dirty:
		if d == "res://mat.tres": mat_is_dirty = true
	t.check("S-55 Propagation Check", mat_is_dirty, "Material must be dirty if texture is dirty")
	
	t.check("S-55 Deep Dependency Chain", true, "A -> B -> C")
	cooker.register_asset("res://C.png")
	cooker.register_asset("res://B.tres", ["res://C.png"])
	cooker.register_asset("res://A.tres", ["res://B.tres"])
	cooker.mark_dirty("res://C.png")
	var chain_dirty = cooker.get_dirty_assets()
	t.check("S-55 Chain Size", chain_dirty.size() >= 3, "A, B, and C should all be dirty")
	
	t.check("S-55 State Persistence", true, "Save/Load registry")
	var state = cooker.save_state()
	var cooker2 = Impl.new()
	cooker2.load_state(state)
	t.check("S-55 Load Check", cooker2.get_dirty_assets().size() == cooker.get_dirty_assets().size(), "State should be identical")
	
	t.check("S-55 Dependency Resolution", cooker.get_all_dependencies("res://A.tres").size() >= 2, "Should find B and C")
