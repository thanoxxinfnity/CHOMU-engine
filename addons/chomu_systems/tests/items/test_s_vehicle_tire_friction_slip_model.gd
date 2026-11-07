extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/vehicle_tire_friction_slip_model.gd")

func run(t: Node) -> void:
	var model := Impl.new()
	
	# Test 1: Basic initialization and defaults
	t.check("S-29 model initializes with defaults", model != null, "Model instance created")
	var res = model.get_last_result()
	t.check("S-29 default last result has zero forces", res.lateral_force == 0.0 and res.longitudinal_force == 0.0 and res.aligning_torque == 0.0, "Forces zeroed")
	
	# Test 2: Pure lateral slip (cornering)
	var lat = model.compute_forces(deg_to_rad(5.0), 0.0, 4000.0)
	t.check("S-29 pure lateral slip generates lateral force", abs(lat.lateral_force) > 100.0, "Fy = %f" % lat.lateral_force)
	t.check("S-29 pure lateral has near-zero longitudinal", abs(lat.longitudinal_force) < 1.0, "Fx = %f" % lat.longitudinal_force)
	t.check("S-29 pure lateral generates aligning torque", abs(lat.aligning_torque) > 0.1, "Mz = %f" % lat.aligning_torque)
	t.check("S-29 combined factor is 1.0 for pure slip", abs(lat.combined_slip_factor - 1.0) < 0.001, "Factor = %f" % lat.combined_slip_factor)
	
	# Test 3: Pure longitudinal slip (acceleration/braking)
	var lon = model.compute_forces(0.0, 0.1, 4000.0)
	t.check("S-29 pure longitudinal slip generates longitudinal force", abs(lon.longitudinal_force) > 100.0, "Fx = %f" % lon.longitudinal_force)
	t.check("S-29 pure longitudinal has near-zero lateral", abs(lon.lateral_force) < 1.0, "Fy = %f" % lon.lateral_force)
	t.check("S-29 pure longitudinal has near-zero aligning", abs(lon.aligning_torque) < 1.0, "Mz = %f" % lon.aligning_torque)
	
	# Test 4: Combined slip reduces forces (friction ellipse)
	var comb = model.compute_forces(deg_to_rad(5.0), 0.1, 4000.0)
	t.check("S-29 combined slip reduces lateral vs pure", abs(comb.lateral_force) < abs(lat.lateral_force), "Combined Fy=%f < Pure Fy=%f" % [comb.lateral_force, lat.lateral_force])
	t.check("S-29 combined slip reduces longitudinal vs pure", abs(comb.longitudinal_force) < abs(lon.longitudinal_force), "Combined Fx=%f < Pure Fx=%f" % [comb.longitudinal_force, lon.longitudinal_force])
	t.check("S-29 combined factor < 1.0", comb.combined_slip_factor < 1.0, "Factor = %f" % comb.combined_slip_factor)
	
	# Test 5: Load sensitivity (sublinear scaling)
	var load1 = model.compute_forces(deg_to_rad(5.0), 0.0, 2000.0)
	var load2 = model.compute_forces(deg_to_rad(5.0), 0.0, 8000.0)
	var ratio = abs(load2.lateral_force / load1.lateral_force) if load1.lateral_force != 0.0 else 0.0
	t.check("S-29 load sensitivity sublinear (ratio < 4.0 for 4x load)", ratio < 4.0 and ratio > 2.0, "Ratio = %f" % ratio)
	
	# Test 6: Camber affects aligning torque
	var camber0 = model.compute_forces(deg_to_rad(3.0), 0.0, 4000.0, 0.0)
	var camber_pos = model.compute_forces(deg_to_rad(3.0), 0.0, 4000.0, deg_to_rad(5.0))
	var camber_neg = model.compute_forces(deg_to_rad(3.0), 0.0, 4000.0, deg_to_rad(-5.0))
	t.check("S-29 positive camber increases aligning torque", camber_pos.aligning_torque > camber0.aligning_torque, "Mz: pos=%f base=%f" % [camber_pos.aligning_torque, camber0.aligning_torque])
	t.check("S-29 negative camber decreases aligning torque", camber_neg.aligning_torque < camber0.aligning_torque, "Mz: neg=%f base=%f" % [camber_neg.aligning_torque, camber0.aligning_torque])
	
	# Test 7: Input clamping
	var clamped = model.compute_forces(deg_to_rad(90.0), 5.0, 4000.0)
	t.check("S-29 slip angle clamped to max", abs(clamped.slip_angle) <= model.max_slip_angle + 0.001, "SA = %f" % clamped.slip_angle)
	t.check("S-29 slip ratio clamped to max", abs(clamped.slip_ratio) <= model.max_slip_ratio + 0.001, "SR = %f" % clamped.slip_ratio)
	
	# Test 8: Friction circle vs ellipse
	model.set_friction_ellipse(false, 1.1)
	var circle = model.compute_forces(deg_to_rad(5.0), 0.1, 4000.0)
	model.set_friction_ellipse(true, 1.1)
	var ellipse = model.compute_forces(deg_to_rad(5.0), 0.1, 4000.0)
	t.check("S-29 friction circle and ellipse produce different results", abs(circle.lateral_force - ellipse.lateral_force) > 1.0 or abs(circle.longitudinal_force - ellipse.longitudinal_force) > 1.0, "Circle vs Ellipse differ")
	
	# Test 9: Save/load state roundtrip
	model.set_pacejka_lateral(11.0, 2.0, 1.1, 0.95)
	model.set_load_sensitivity(0.85)
	var state = model.save_state()
	var model2 := Impl.new()
	model2.load_state(state)
	t.check("S-29 save/load preserves pacejka lateral B", abs(model2.pacejka_lateral_b - 11.0) < 0.001, "B = %f" % model2.pacejka_lateral_b)
	t.check("S-29 save/load preserves load sensitivity", abs(model2.load_sensitivity - 0.85) < 0.001, "Sens = %f" % model2.load_sensitivity)
	t.check("S-29 save/load preserves last result", abs(model2.get_last_result().lateral_force - model.get_last_result().lateral_force) < 0.001, "Last result matches")
	
	# Test 10: Deterministic computation (same inputs = same outputs)
	var r1 = model.compute_forces(deg_to_rad(7.5), 0.08, 3500.0, deg_to_rad(2.0))
	var r2 = model.compute_forces(deg_to_rad(7.5), 0.08, 3500.0, deg_to_rad(2.0))
	t.check("S-29 deterministic: repeated calls match", r1.lateral_force == r2.lateral_force and r1.longitudinal_force == r2.longitudinal_force and r1.aligning_torque == r2.aligning_torque, "Forces identical")
	
	# Test 11: Zero load produces zero forces
	var zero_load = model.compute_forces(deg_to_rad(10.0), 0.2, 0.0)
	t.check("S-29 zero normal load yields zero forces", zero_load.lateral_force == 0.0 and zero_load.longitudinal_force == 0.0 and zero_load.aligning_torque == 0.0, "All forces zero")
	
	# Test 12: Negative slip angles produce opposite lateral force
	var neg = model.compute_forces(deg_to_rad(-5.0), 0.0, 4000.0)
	var pos = model.compute_forces(deg_to_rad(5.0), 0.0, 4000.0)
	t.check("S-29 negative slip angle flips lateral force sign", neg.lateral_force * pos.lateral_force < 0.0, "Signs opposite: %f vs %f" % [neg.lateral_force, pos.lateral_force])
	t.check("S-29 negative slip angle flips aligning torque sign", neg.aligning_torque * pos.aligning_torque < 0.0, "Mz signs opposite")
	
	# RefCounted auto-frees when reference goes out of scope; no manual free() needed.
