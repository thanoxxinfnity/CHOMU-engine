extends RefCounted

const Impl := preload("res://addons/chomu_systems/anim/motion_matching.gd")

func run(t: Node) -> void:
	var mm: ChomuMotionMatching = Impl.new()
	
	# Test 1: add_clip and normalize
	var clip_frames: Array[Dictionary] = []
	for i in range(10):
		var feats: PackedFloat32Array = PackedFloat32Array([float(i), float(i * 2), float(i * 0.5)])
		clip_frames.append({"features": feats})
	mm.add_clip("walk", clip_frames)
	
	var clip_frames2: Array[Dictionary] = []
	for i in range(10):
		var feats: PackedFloat32Array = PackedFloat32Array([float(i + 5), float(i * 2 + 1), float(i * 0.5 - 1)])
		clip_frames2.append({"features": feats})
	mm.add_clip("run", clip_frames2)
	
	mm.normalize()
	t.check("F-75 add_clip and normalize", mm.get_current_clip_idx() == -1, "Initial state has no current clip")
	
	# Test 2: query exact stored frame returns it
	var query_feats: PackedFloat32Array = PackedFloat32Array([5.0, 10.0, 2.5])  # frame 5 of walk
	var result: Dictionary = mm.query(query_feats)
	t.check("F-75 query exact frame returns correct clip", result.clip == "walk", "Clip should be 'walk', got '%s'" % result.clip)
	t.check("F-75 query exact frame returns correct index", result.frame == 5, "Frame should be 5, got %d" % result.frame)
	t.check("F-75 query exact frame has near-zero cost", result.cost < 1e-4, "Cost should be near zero, got %f" % result.cost)
	
	# Test 3: transition bias keeps current clip on near-ties
	mm.query(PackedFloat32Array([5.0, 10.0, 2.5]))  # sets current to walk frame 5
	t.check("F-75 bias test - current clip is walk", mm.get_current_clip_idx() == 0, "Current clip should be walk (idx 0)")
	
	# Now query something ambiguous but bias should keep walk
	var ambiguous: PackedFloat32Array = PackedFloat32Array([5.0, 5.5, 0.75])
	var result_walk: Dictionary = mm.query(ambiguous)
	t.check("F-75 transition bias keeps current clip", result_walk.clip == "walk", "Bias should keep 'walk', got '%s'" % result_walk.clip)
	
	# Test 4: two_bone_ik reachable target
	var root: Vector3 = Vector3(0, 0, 0)
	var mid: Vector3 = Vector3(1, 0, 0)
	var end: Vector3 = Vector3(2, 0, 0)
	var target: Vector3 = Vector3(1.5, 1.0, 0)
	var pole: Vector3 = Vector3(0, 0, 1)
	
	var ik_result: Array[Vector3] = Impl.two_bone_ik(root, mid, end, target, pole)
	var new_mid: Vector3 = ik_result[0]
	var new_end: Vector3 = ik_result[1]
	
	var len1_orig: float = root.distance_to(mid)
	var len2_orig: float = mid.distance_to(end)
	var len1_new: float = root.distance_to(new_mid)
	var len2_new: float = new_mid.distance_to(new_end)
	var end_dist: float = new_end.distance_to(target)
	
	t.check("F-75 IK preserves bone1 length", abs(len1_new - len1_orig) < 1e-3, "Bone1 length diff: %f" % abs(len1_new - len1_orig))
	t.check("F-75 IK preserves bone2 length", abs(len2_new - len2_orig) < 1e-3, "Bone2 length diff: %f" % abs(len2_new - len2_orig))
	t.check("F-75 IK reaches reachable target", end_dist < 1e-3, "End distance to target: %f" % end_dist)
	
	# Test 5: two_bone_ik unreachable target (fully extended)
	var far_target: Vector3 = Vector3(5, 0, 0)  # distance 5 > total_len 2
	var ik_result2: Array[Vector3] = Impl.two_bone_ik(root, mid, end, far_target, pole)
	var new_mid2: Vector3 = ik_result2[0]
	var new_end2: Vector3 = ik_result2[1]
	
	var len1_new2: float = root.distance_to(new_mid2)
	var len2_new2: float = new_mid2.distance_to(new_end2)
	var dir_to_target: Vector3 = (far_target - root).normalized()
	var expected_mid: Vector3 = root + dir_to_target * len1_orig
	var expected_end: Vector3 = expected_mid + dir_to_target * len2_orig
	
	t.check("F-75 IK unreachable preserves bone1 length", abs(len1_new2 - len1_orig) < 1e-3, "Bone1 length diff: %f" % abs(len1_new2 - len1_orig))
	t.check("F-75 IK unreachable preserves bone2 length", abs(len2_new2 - len2_orig) < 1e-3, "Bone2 length diff: %f" % abs(len2_new2 - len2_orig))
	t.check("F-75 IK unreachable fully extends toward target", new_mid2.distance_to(expected_mid) < 1e-3, "Mid not fully extended toward target")
	t.check("F-75 IK unreachable end fully extended", new_end2.distance_to(expected_end) < 1e-3, "End not fully extended toward target")
	
	# Test 6: two_bone_ik target at root
	var root_target: Vector3 = Vector3(0, 0, 0)
	var ik_result3: Array[Vector3] = Impl.two_bone_ik(root, mid, end, root_target, pole)
	var new_mid3: Vector3 = ik_result3[0]
	var new_end3: Vector3 = ik_result3[1]
	var len1_new3: float = root.distance_to(new_mid3)
	var len2_new3: float = new_mid3.distance_to(new_end3)
	t.check("F-75 IK target at root preserves lengths", abs(len1_new3 - len1_orig) < 1e-3 and abs(len2_new3 - len2_orig) < 1e-3, "Lengths not preserved at root target")
	
	# Test 7: query with custom weights
	var weighted_result: Dictionary = mm.query(PackedFloat32Array([5.0, 10.0, 2.5]), PackedFloat32Array([1.0, 0.0, 0.0]))
	t.check("F-75 query with weights works", weighted_result.clip == "walk", "Weighted query should work")
	
	# Test 8: set_transition_cost
	mm.set_transition_cost(0.5)
	t.check("F-75 set_transition_cost", true, "Transition cost setter runs without error")
	
	# RefCounted objects are auto-freed, no need to call free()
	# mm.free()  # This would cause an error
