extends RefCounted

const WindGrid := preload("res://addons/chomu_systems/physics/wind_grid.gd")

func run(t: Node) -> void:
	var grid := WindGrid.new(4, 2.0, Vector3.ZERO)
	
	# 1. Test: Sample at grid node equals stored value (approx)
	grid.step(0.1) # Update first slice
	var node_pos := Vector3(0, 0, 0)
	var val_at_node := grid.sample(node_pos)
	t.check("F-57 sample at node", val_at_node.length() > 0, "Wind should be initialized")
	
	# 2. Test: Trilinear interpolation
	var mid_pos := Vector3(1.0, 0, 0) # Exactly between node 0 and 1
	var val_mid := grid.sample(mid_pos)
	var val_0 := grid.sample(Vector3(0, 0, 0))
	var val_1 := grid.sample(Vector3(2.0, 0, 0))
	var expected := (val_0 + val_1) * 0.5
	t.check("F-57 trilinear interpolation", val_mid.is_equal_approx(expected), "Midpoint should be average of neighbors")
	
	# 3. Test: Impulse effect and decay
	var imp_pos := Vector3(5, 5, 5)
	var imp_vel := Vector3(100, 0, 0)
	var wind_before := grid.sample(imp_pos)
	grid.add_impulse(imp_pos, imp_vel, 2.0, 1.0)
	var wind_after := grid.sample(imp_pos)
	t.check("F-57 impulse raises wind", wind_after.x > wind_before.x, "Impulse should increase local velocity")
	
	# Simulate decay
	grid.step(1.1) # Impulse life was 1.0, should be gone
	var wind_decayed := grid.sample(imp_pos)
	t.check("F-57 impulse decays", wind_decayed.x < wind_after.x, "Wind should return to normal after impulse expires")
	
	# 4. Test: Time-sliced updates
	var pos_z0 := Vector3(0, 0, 0)
	var v0_start := grid.sample(pos_z0)
	for i in range(10): grid.step(0.1)
	var v0_end := grid.sample(pos_z0)
	t.check("F-57 time-sliced update", v0_end != v0_start, "Grid values should evolve over time")
	
	# 5. Test: Gerstner height bounds
	var waves = [
		{"dir": Vector3(1, 0, 0), "amp": 1.0, "wavelength": 10.0, "steepness": 0.5},
		{"dir": Vector3(0, 0, 1), "amp": 0.5, "wavelength": 5.0, "steepness": 0.2}
	]
	var h := WindGrid.gerstner_height(1.2, 3.4, 5.6, waves)
	t.check("F-57 gerstner height bounds", abs(h) <= 1.5, "Height should be bounded by sum of amplitudes")
	
	# 6. Test: Gerstner periodicity
	var h1 := WindGrid.gerstner_height(1.0, 1.0, 0.0, waves)
	var h2 := WindGrid.gerstner_height(1.0, 1.0, 100.0, waves)
	t.check("F-57 gerstner dynamic", h1 != h2, "Water height should change over time")
