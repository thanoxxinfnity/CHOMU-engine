extends RefCounted

const Impl = preload("res://addons/chomu_systems/sheet/dependency_graph_resolver.gd")

func run(t: Node) -> void:
	var resolver := Impl.new()
	
	# Setup a simple graph:
	# TextureA -> (none)
	# MaterialA -> TextureA
	# MeshA -> MaterialA
	# SceneA -> MeshA, TextureA
	
	resolver.register_asset("TextureA", [])
	resolver.register_asset("MaterialA", ["TextureA"])
	resolver.register_asset("MeshA", ["MaterialA"])
	resolver.register_asset("SceneA", ["MeshA", "TextureA"])
	
	t.check("S-43 Recursive Deps", 
		resolver.get_dependencies_recursive("SceneA").size() == 3, 
		"SceneA should depend on MeshA, MaterialA, and TextureA")
	
	t.check("S-43 Recursive Dependents", 
		resolver.get_dependents_recursive("TextureA").size() == 3, 
		"TextureA should be used by MaterialA, MeshA, and SceneA")
	
	var sorted = resolver.get_topological_sort()
	t.check("S-43 Topo Sort Order", 
		sorted.find("TextureA") < sorted.find("MaterialA") and sorted.find("MaterialA") < sorted.find("MeshA"), 
		"Texture must come before Material, and Material before Mesh")
	
	# Test state persistence
	var state = resolver.save_state()
	var resolver2 = Impl.new()
	resolver2.load_state(state)
	
	t.check("S-43 Save/Load State", 
		resolver2.get_dependencies_recursive("SceneA").size() == 3, 
		"Loaded resolver should maintain dependency counts")
	
	# Test removal
	resolver.remove_asset("MaterialA")
	t.check("S-43 Asset Removal", 
		resolver.get_dependencies_recursive("MeshA").size() == 0, 
		"MeshA should no longer depend on MaterialA after removal")
	
	# Test circular dependency safety
	resolver.register_asset("NodeX", ["NodeY"])
	resolver.register_asset("NodeY", ["NodeX"])
	var circ_sorted = resolver.get_topological_sort()
	t.check("S-43 Circular Safety", 
		circ_sorted.size() > 0, 
		"Topo sort should not crash on circular dependencies")
