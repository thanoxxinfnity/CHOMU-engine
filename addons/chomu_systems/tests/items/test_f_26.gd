extends RefCounted

const Impl := preload("res://addons/chomu_systems/ai/semantic_volumes.gd")

func run(t: Node) -> void:
	var sv := Impl.new()
	t.add_child(sv)
	
	# Test 1: Add two rooms with different tags
	var room1_aabb := AABB(Vector3(-10, 0, -10), Vector3(20, 5, 20))
	var room2_aabb := AABB(Vector3(20, 0, -10), Vector3(20, 5, 20))
	sv.add_volume("room", room1_aabb, "room_a")
	sv.add_volume("room", room2_aabb, "room_b")
	
	# Test 2: tags_at inside room_a
	var tags_inside := sv.tags_at(Vector3(-5, 2, -5))
	t.check("F-26 tags_at inside room_a", tags_inside.has("room"), "Position inside room_a should have 'room' tag")
	
	# Test 3: tags_at inside room_b
	tags_inside = sv.tags_at(Vector3(25, 2, -5))
	t.check("F-26 tags_at inside room_b", tags_inside.has("room"), "Position inside room_b should have 'room' tag")
	
	# Test 4: tags_at outside both rooms
	var tags_outside := sv.tags_at(Vector3(100, 2, 100))
	t.check("F-26 tags_at outside rooms", not tags_outside.has("room"), "Position outside rooms should not have 'room' tag")
	
	# Test 5: nearest returns closer room
	var nearest_info := sv.nearest("room", Vector3(-8, 2, -8))
	t.check("F-26 nearest room_a", nearest_info["name"] == "room_a", "Nearest room to (-8,2,-8) should be room_a")
	t.check("F-26 nearest distance", nearest_info["distance"] > 0.0, "Distance should be positive")
	
	# Test 6: nearest returns room_b when closer
	nearest_info = sv.nearest("room", Vector3(28, 2, -8))
	t.check("F-26 nearest room_b", nearest_info["name"] == "room_b", "Nearest room to (28,2,-8) should be room_b")
	
	# Test 7: auto_tag_hiding_spots - wall between threat and candidate yields hiding_spot
	# Create a wall (StaticBody3D with box collision) at x=0 between threat (-10,0,0) and candidate (5,0,0)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1, 3, 3)
	wall_shape.shape = box_shape
	wall.add_child(wall_shape)
	t.add_child(wall)
	wall.position = Vector3(0, 1.5, 0)  # Use local position since parent t is at origin
	# Wait for physics to add the static body
	await t.physics_frames(1)
	
	var space_state = t.get_world_3d().direct_space_state
	var candidates := PackedVector3Array([Vector3(5, 1, 0)])  # Behind wall from threat
	var threats := PackedVector3Array([Vector3(-10, 1, 0)])    # In front of wall
	
	sv.auto_tag_hiding_spots(candidates, threats, space_state)
	
	var hide_tags := sv.tags_at(Vector3(5, 1, 0))
	t.check("F-26 auto_tag hiding_spot behind wall", hide_tags.has("hiding_spot"), "Candidate behind wall should be tagged hiding_spot")
	
	# Clean up wall
	wall.queue_free()
	await t.physics_frames(1)
	
	# Test 8: auto_tag_hiding_spots - open candidate is not tagged
	var sv2 := Impl.new()
	t.add_child(sv2)
	var space_state2 = t.get_world_3d().direct_space_state
	
	var open_candidates := PackedVector3Array([Vector3(5, 1, 0)])
	var open_threats := PackedVector3Array([Vector3(-10, 1, 0)])
	
	sv2.auto_tag_hiding_spots(open_candidates, open_threats, space_state2)
	
	var open_tags := sv2.tags_at(Vector3(5, 1, 0))
	t.check("F-26 auto_tag open candidate not tagged", not open_tags.has("hiding_spot") and not open_tags.has("cover"), "Open candidate with no occlusion should not be tagged")
	
	# Test 9: auto_tag_hiding_spots - cover when occluded from half threats
	var sv3 := Impl.new()
	t.add_child(sv3)
	
	# Two threats, one occluded by wall, one not
	var wall2 := StaticBody3D.new()
	var wall_shape2 := CollisionShape3D.new()
	var box_shape2 := BoxShape3D.new()
	box_shape2.size = Vector3(1, 3, 3)
	wall_shape2.shape = box_shape2
	wall2.add_child(wall_shape2)
	t.add_child(wall2)
	wall2.position = Vector3(0, 1.5, 0)  # Use local position since parent t is at origin
	# Wait for physics to add the static body
	await t.physics_frames(1)
	
	var space_state3 = t.get_world_3d().direct_space_state
	var cover_candidates := PackedVector3Array([Vector3(5, 1, 0)])
	var cover_threats := PackedVector3Array([Vector3(-10, 1, 0), Vector3(10, 1, 0)])  # One behind wall, one in front
	
	sv3.auto_tag_hiding_spots(cover_candidates, cover_threats, space_state3)
	
	var cover_tags := sv3.tags_at(Vector3(5, 1, 0))
	t.check("F-26 auto_tag cover half occluded", cover_tags.has("cover"), "Candidate occluded from half threats should be tagged cover")
	t.check("F-26 auto_tag not hiding_spot when half", not cover_tags.has("hiding_spot"), "Candidate occluded from half should not be hiding_spot")
	
	wall2.queue_free()
	await t.physics_frames(1)
	
	# Test 10: nearest returns empty dict for non-existent tag
	var empty_nearest := sv.nearest("nonexistent", Vector3(0, 0, 0))
	t.check("F-26 nearest empty for missing tag", empty_nearest.is_empty(), "Nearest for missing tag should return empty dict")
	
	sv.queue_free()
	sv2.queue_free()
	sv3.queue_free()
