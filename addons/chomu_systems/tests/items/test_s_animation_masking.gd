extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/animation_masking.gd")

func run(t: Node) -> void:
	var am := Impl.new()
	
	# Setup bone sets
	var upper_bones: Array[String] = ["Spine", "Shoulder_L", "Shoulder_R", "Hand_L", "Hand_R"]
	var lower_bones: Array[String] = ["Hips", "Thigh_L", "Thigh_R", "Foot_L", "Foot_R"]
	
	var upper_mask := Impl.create_upper_body_mask(upper_bones)
	var lower_mask := Impl.create_lower_body_mask(lower_bones)
	
	am.add_layer("Base", lower_mask) # Base layer is lower body
	am.add_layer("Action", upper_mask) # Action layer is upper body
	
	# Test 1: Basic Masking Isolation
	t.check("S-52 Upper body isolation", 
		am.get_bone_blend_weight("Hand_L", "Action") > 0.0 and am.get_bone_blend_weight("Foot_L", "Action") == 0.0, 
		"Action layer should affect hands but not feet")
	
	t.check("S-52 Lower body isolation", 
		am.get_bone_blend_weight("Foot_L", "Base") > 0.0 and am.get_bone_blend_weight("Hand_L", "Base") == 0.0, 
		"Base layer should affect feet but not hands")
	
	# Test 2: Weight Modulation
	am.set_layer_weight("Action", 0.5)
	t.check("S-52 Weight modulation", 
		is_equal_approx(am.get_bone_blend_weight("Hand_L", "Action"), 0.5), 
		"Bone weight should be scaled by layer weight")
	
	# Test 3: Total Influence
	t.check("S-52 Total influence Hand", 
		is_equal_approx(am.get_total_bone_influence("Hand_L"), 0.5), 
		"Total influence for Hand_L should be 0.5")
	
	t.check("S-52 Total influence Foot", 
		is_equal_approx(am.get_total_bone_influence("Foot_L"), 1.0), 
		"Total influence for Foot_L should be 1.0")
	
	# Test 4: State Persistence
	var state := am.save_state()
	var am2 := Impl.new()
	am2.load_state(state)
	t.check("S-52 Save/Load state", 
		is_equal_approx(am2.get_bone_blend_weight("Hand_L", "Action"), 0.5), 
		"Loaded state should preserve layer weights and masks")
	
	# Test 5: Layer Removal
	am.remove_layer("Action")
	t.check("S-52 Layer removal", 
		am.get_bone_blend_weight("Hand_L", "Action") == 0.0, 
		"Removed layer should no longer provide weight")

func is_equal_approx(a: float, b: float) -> bool:
	return abs(a - b) < 0.001
