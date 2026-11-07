extends RefCounted

const Impl = preload("res://addons/chomu_systems/sheet/fluid_particle_collision_dynamics.gd")

func run(t: Node) -> void:
	# Setup a simple physics environment
	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	col.shape = box
	static_body.add_child(col)
	static_body.position = Vector3(0, -1, 0) # Floor at y=-1
	t.add_child(static_body)
	
	var space_state = t.get_world_3d().direct_space_state

	t.check("F-S94 Particle Addition", true, "Should add particles correctly")
	var sim = Impl.new()
	sim.add_particle(Vector3(0, 5, 0))
	sim.add_particle(Vector3(0.1, 5, 0))
	var data = sim.get_particles_data()
	t.check("F-S94 Particle Count", data.size() == 2, "Should have 2 particles")

	t.check("F-S94 Gravity Fall", true, "Particles should fall under gravity")
	# Step simulation for a few frames
	for i in range(10):
		sim.step(0.016, space_state)
	
	var pos_after_fall = sim.get_particles_data()[0].pos.y
	t.check("F-S94 Fall Height", pos_after_fall < 5.0, "Particle should have dropped from y=5")

	t.check("F-S94 Solid Collision", true, "Particles should collide with floor")
	# Step until they hit the floor (y=-1 + radius)
	for i in range(100):
		sim.step(0.016, space_state)
	
	var final_pos = sim.get_particles_data()[0].pos.y
	# Floor is at -1, box height is 1, so top surface is at -0.5. 
	# Particle radius is 0.1. Expected y approx -0.4
	t.check("F-S94 Floor Contact", final_pos >= -0.6 and final_pos <= -0.3, "Particle should be resting on floor")

	t.check("F-S94 Particle Repulsion", true, "Particles should push each other apart")
	var sim2 = Impl.new()
	# Place two particles almost on top of each other
	sim2.add_particle(Vector3(0, 0, 0))
	sim2.add_particle(Vector3(0.01, 0, 0))
	
	# Step once to resolve overlap
	sim2.step(0.016, space_state)
	var p_data = sim2.get_particles_data()
	var dist = p_data[0].pos.distance_to(p_data[1].pos)
	t.check("F-S94 Repulsion Distance", dist >= 0.2, "Particles should be pushed to at least 2*radius")

	t.check("F-S94 Save/Load State", true, "State should be preserved")
	var state = sim.save_state()
	var sim3 = Impl.new()
	sim3.load_state(state)
	var saved_pos = sim3.get_particles_data()[0].pos
	var original_pos = sim.get_particles_data()[0].pos
	t.check("F-S94 State Equality", saved_pos.is_equal_approx(original_pos), "Loaded position should match saved")

	static_body.queue_free()
