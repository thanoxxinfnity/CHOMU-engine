extends RefCounted

const ChomuLightExposure := preload("res://addons/chomu_systems/ai/light_exposure.gd")

func run(t: Node) -> void:
	# Setup scene
	var exposure_node := ChomuLightExposure.new()
	t.add_child(exposure_node)
	
	var marker1 := Node3D.new()
	var marker2 := Node3D.new()
	var marker3 := Node3D.new()
	t.add_child(marker1)
	t.add_child(marker2)
	t.add_child(marker3)
	marker1.global_position = Vector3(0, 0, 0)
	marker2.global_position = Vector3(10, 0, 0)
	marker3.global_position = Vector3(20, 0, 0)
	
	exposure_node.sample_points = [marker1, marker2, marker3]
	exposure_node.ambient_level = 0.02
	exposure_node.weight_max = true
	
	# 1. Check baseline (ambient)
	await t.physics_frames(3) 
	t.check("F-41 baseline ambient", exposure_node.exposure() > 0.01 and exposure_node.exposure() < 0.05, "Should be near ambient")
	
	# 2. Verify round-robin: only one sample per frame
	# We check the internal counter for a few frames
	var sample_count_ok := true
	for i in range(3):
		await t.physics_frames(1)
		if exposure_node._samples_this_frame != 1:
			sample_count_ok = false
	t.check("F-41 single sample per frame", sample_count_ok, "Should only evaluate one probe per physics frame")
	
	# 3. Add light near marker 1
	var light := OmniLight3D.new()
	t.add_child(light)
	light.global_position = marker1.global_position + Vector3(0, 1, 0)
	light.omni_range = 5.0
	light.light_energy = 1.0
	
	# 4. Verify detection and lag
	var exp_before := exposure_node.exposure()
	# It might take up to 3 frames to hit marker 1
	await t.physics_frames(3)
	t.check("F-41 light detection", exposure_node.exposure() > exp_before, "Exposure should rise when light is added")
	
	# 5. Verify distance-based visibility (signature: float)
	var vis_near := exposure_node.visibility_for(0.0)
	var vis_far := exposure_node.visibility_for(100.0)
	t.check("F-41 visibility distance", vis_near > vis_far, "Near distance should result in higher visibility")
	
	# 6. Verify update cycle (moving light)
	light.global_position = marker2.global_position + Vector3(0, 1, 0)
	marker1.global_position = Vector3(-100, 0, 0)
	
	await t.physics_frames(3)
	t.check("F-41 update cycle", exposure_node.exposure() > 0.1, "Should eventually detect light at marker 2")
	
	# Cleanup
	light.queue_free()
	marker1.queue_free()
	marker2.queue_free()
	marker3.queue_free()
	exposure_node.queue_free()
