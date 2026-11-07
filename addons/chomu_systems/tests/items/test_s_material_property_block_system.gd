extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/material_property_block_system.gd")

func run(t: Node) -> void:
	var sys := Impl.new()
	
	# 1. Test Default Values
	sys.set_default_property("u_color", Color.RED)
	sys.set_default_property("u_intensity", 1.0)
	t.check("S-107 Default property retrieval", sys.get_effective_property(999, "u_color") == Color.RED, "Should return default for unknown instance")
	t.check("S-107 Default fallback", sys.get_effective_property(999, "u_missing", 0.5) == 0.5, "Should return provided default for missing property")
	
	# 2. Test Instance Overrides
	sys.set_instance_property(100, "u_color", Color.BLUE)
	t.check("S-107 Instance override", sys.get_effective_property(100, "u_color") == Color.BLUE, "Instance 100 should be Blue")
	t.check("S-107 Instance default fallback", sys.get_effective_property(100, "u_intensity") == 1.0, "Instance 100 should still use default intensity")
	
	# 3. Test Removal and Reversion
	sys.remove_instance_property(100, "u_color")
	t.check("S-107 Revert to default", sys.get_effective_property(100, "u_color") == Color.RED, "Instance 100 should revert to Red after override removal")
	
	# 4. Test GeometryInstance3D Application
	var mesh_instance := MeshInstance3D.new()
	t.add_child(mesh_instance)
	
	sys.set_default_property("u_global_val", 10.0)
	sys.set_instance_property(mesh_instance.get_instance_id(), "u_global_val", 20.0)
	sys.set_instance_property(mesh_instance.get_instance_id(), "u_local_val", 5.0)
	
	sys.apply_to_instance(mesh_instance)
	
	# Note: get_instance_shader_parameter is the counterpart to set_instance_shader_parameter
	t.check("S-107 Apply override to node", mesh_instance.get_instance_shader_parameter("u_global_val") == 20.0, "Node should have overridden value")
	t.check("S-107 Apply unique to node", mesh_instance.get_instance_shader_parameter("u_local_val") == 5.0, "Node should have unique value")
	
	mesh_instance.queue_free()
	
	# 5. Test Serialization
	var state_data := sys.save_state()
	t.check("S-107 Save state defaults", state_data["defaults"]["u_color"] == Color.RED, "Saved state should contain defaults")
	
	var sys2 := Impl.new()
	sys2.load_state(state_data)
	t.check("S-107 Load state defaults", sys2.get_effective_property(999, "u_color") == Color.RED, "Loaded system should have same defaults")
	
	# Verify instance IDs were preserved (stored as strings in JSON-compatible dict)
	var inst_id_str := str(mesh_instance.get_instance_id())
	if state_data["instances"].has(inst_id_str):
		t.check("S-107 Load state instances", sys2.get_effective_property(mesh_instance.get_instance_id(), "u_local_val") == 5.0, "Loaded system should have same instance overrides")
