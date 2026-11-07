extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/raycast_character_step_up_calculator.gd")

func run(t: Node) -> void:
	var calc := Impl.new()
	
	# Setup a simple environment: a floor and a step
	var floor_node := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(10, 0.1, 10)
	floor_col.shape = floor_box
	floor_node.add_child(floor_col)
	floor_node.position = Vector3(0, -0.05, 0)
	t.add_child(floor_node)
	
	var step_node := StaticBody3D.new()
	var step_col := CollisionShape3D.new()
	var step_box := BoxShape3D.new()
	step_box.size = Vector3(1, 0.2, 1)
	step_col.shape = step_box
	step_node.add_child(step_col)
	# Box center at 0.1, bottom at 0.0, top at 0.2
	step_node.position = Vector3(0, 0.1, -1.0) 
	t.add_child(step_node)
	
	await t.physics_frames(2)
	var space = t.get_world_3d().direct_space_state
	
	# Test 1: No obstacle in front
	var pos_clear := Vector3(0, 0, 0)
	var vel_clear := Vector3(0, 0, 1) # Moving away from step
	var res_clear := calc.calculate_step(pos_clear, vel_clear, space)
	t.check("S-48 no obstacle", res_clear.success == false, "Should not step when no obstacle is present")
	
	# Test 2: Valid step-up
	var pos_step := Vector3(0, 0, 0)
	var vel_step := Vector3(0, 0, -1) # Moving towards step
	var res_step := calc.calculate_step(pos_step, vel_step, space)
	t.check("S-48 valid step", res_step.success == true, "Should detect valid step-up")
	t.check("S-48 step height", abs(res_step.vertical_offset - 0.2) < 0.05, "Step height should be approx 0.2")
	
	# Test 3: Too high to step
	var high_step_node := StaticBody3D.new()
	var high_col := CollisionShape3D.new()
	var high_box := BoxShape3D.new()
	high_box.size = Vector3(1, 1.0, 1)
	high_col.shape = high_box
	high_step_node.add_child(high_col)
	# Box center at 0.5, bottom at 0.0, top at 1.0
	high_step_node.position = Vector3(2, 0.5, -1.0) 
	t.add_child(high_step_node)
	
	await t.physics_frames(2)
	var pos_high := Vector3(2, 0, 0)
	var res_high := calc.calculate_step(pos_high, vel_step, space)
	t.check("S-48 too high", res_high.success == false, "Should not step up obstacles exceeding max_step_height")
	
	# Test 4: State Save/Load
	var config := calc.get_config()
	config.max_step_height = 0.77
	var state := calc.save_state()
	t.check("S-48 save state", state["max_step_height"] == 0.77, "State should save config")
	
	var calc2 := Impl.new()
	calc2.load_state(state)
	t.check("S-48 load state", calc2.get_config().max_step_height == 0.77, "State should load config")
	
	# Cleanup
	floor_node.queue_free()
	step_node.queue_free()
	high_step_node.queue_free()
