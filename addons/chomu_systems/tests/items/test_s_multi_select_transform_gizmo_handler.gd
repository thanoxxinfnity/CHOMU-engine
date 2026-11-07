extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/multi_select_transform_gizmo_handler.gd")

func run(t: Node) -> void:
	var handler := Impl.new()
	
	# Setup test nodes
	var n1 := Node3D.new()
	var n2 := Node3D.new()
	t.add_child(n1)
	t.add_child(n2)
	
	n1.global_position = Vector3(0, 0, 0)
	n2.global_position = Vector3(2, 0, 0)
	
	var selection: Array[Node3D] = [n1, n2]
	handler.set_selection(selection)
	
	t.check("S-108 Center Calculation", handler.gizmo_center == Vector3(1, 0, 0), "Center should be average of positions")
	
	# Test Translation
	handler.start_transform()
	# Move gizmo by +1 on Y
	var delta_trans := Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	handler.update_transform(delta_trans)
	
	t.check("S-108 Translation N1", n1.global_position.is_equal_approx(Vector3(0, 1, 0)), "N1 should move with gizmo")
	t.check("S-108 Translation N2", n2.global_position.is_equal_approx(Vector3(2, 1, 0)), "N2 should move with gizmo")
	handler.end_transform()
	
	# Test Rotation around center
	n1.global_position = Vector3(0, 0, 0)
	n2.global_position = Vector3(2, 0, 0)
	handler.set_selection(selection) 
	
	handler.start_transform()
	# Rotate 90 degrees around Y axis
	var rot_basis := Basis(Vector3.UP, deg_to_rad(90))
	var rot_delta := Transform3D(rot_basis, Vector3.ZERO)
	handler.update_transform(rot_delta)
	
	# N1 relative to center(1,0,0) is (-1,0,0). 
	# Rotated 90deg around Y: (0,0,1). 
	# World: (1,0,0) + (0,0,1) = (1,0,1)
	t.check("S-108 Rotation N1", n1.global_position.is_equal_approx(Vector3(1, 0, 1)), "N1 should rotate around center")
	# N2 relative to center(1,0,0) is (1,0,0).
	# Rotated 90deg around Y: (0,0,-1).
	# World: (1,0,0) + (0,0,-1) = (1,0,-1)
	t.check("S-108 Rotation N2", n2.global_position.is_equal_approx(Vector3(1, 0, -1)), "N2 should rotate around center")
	handler.end_transform()
	
	# Test Scaling
	n1.global_position = Vector3(0, 0, 0)
	n2.global_position = Vector3(2, 0, 0)
	handler.set_selection(selection)
	
	handler.start_transform()
	# Scale by 2x
	var scale_basis := Basis.IDENTITY.scaled(Vector3(2, 2, 2))
	var scale_delta := Transform3D(scale_basis, Vector3.ZERO)
	handler.update_transform(scale_delta)
	
	# N1 relative (-1,0,0) * 2 = (-2,0,0). World: (1,0,0) + (-2,0,0) = (-1,0,0)
	t.check("S-108 Scale N1", n1.global_position.is_equal_approx(Vector3(-1, 0, 0)), "N1 should scale away from center")
	# N2 relative (1,0,0) * 2 = (2,0,0). World: (1,0,0) + (2,0,0) = (3,0,0)
	t.check("S-108 Scale N2", n2.global_position.is_equal_approx(Vector3(3, 0, 0)), "N2 should scale away from center")
	handler.end_transform()
	
	# Test State Save/Load
	handler.set_mode(Impl.TransformMode.ROTATE)
	var state := handler.save_state()
	var handler2 := Impl.new()
	handler2.load_state(state)
	t.check("S-108 State Persistence", handler2.current_mode == Impl.TransformMode.ROTATE, "Mode should be preserved")
	
	n1.queue_free()
	n2.queue_free()
