extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/cross_fade_transition_interpolation.gd")

func run(t: Node) -> void:
	var cf := Impl.new()
	
	# Test 1: Linear Float Interpolation
	cf.transition_to(0.0, 10.0, 1.0, Impl.BlendMode.LINEAR)
	var val1 := cf.update(0.5)
	t.check("S-42 Linear Float Mid", val1 == 5.0, "Expected 5.0 at 0.5s of 1.0s transition")
	val1 = cf.update(0.5)
	t.check("S-42 Linear Float End", val1 == 10.0, "Expected 10.0 at 1.0s")
	t.check("S-42 Linear Float Finished", not cf.is_transitioning(), "Transition should be inactive")

	# Test 2: Vector3 Interpolation
	var start_pos := Vector3(0, 0, 0)
	var end_pos := Vector3(10, 20, 30)
	cf.transition_to(start_pos, end_pos, 2.0, Impl.BlendMode.LINEAR)
	var pos_val := cf.update(1.0)
	t.check("S-42 Vector3 Mid", pos_val.is_equal_approx(Vector3(5, 10, 15)), "Expected midpoint Vector3")

	# Test 3: Smoothstep Curve
	cf.transition_to(0.0, 1.0, 1.0, Impl.BlendMode.SMOOTHSTEP)
	var s_val := cf.update(0.25)
	# Smoothstep(0.25) = 0.25 * 0.25 * (3 - 0.5) = 0.0625 * 2.5 = 0.15625
	t.check("S-42 Smoothstep Curve", s_val < 0.25, "Smoothstep should start slower than linear")

	# Test 4: State Save/Load
	cf.transition_to(0.0, 100.0, 1.0, Impl.BlendMode.LINEAR)
	cf.update(0.3)
	var state := cf.save_state()
	
	var cf2 := Impl.new()
	cf2.load_state(state)
	t.check("S-42 State Load Active", cf2.is_transitioning(), "Loaded state should be active")
	var val2 := cf2.update(0.0) # Just sample
	t.check("S-42 State Load Value", abs(val2 - 30.0) < 0.1, "Loaded state should maintain progress")

	# Test 5: Transform3D Interpolation
	var t1 := Transform3D(Basis(), Vector3(0,0,0))
	var t2 := Transform3D(Basis().rotated(Vector3.UP, PI/2), Vector3(1,1,1))
	cf.transition_to(t1, t2, 1.0, Impl.BlendMode.LINEAR)
	var res_t := cf.update(0.5)
	t.check("S-42 Transform3D Mid", res_t.origin.is_equal_approx(Vector3(0.5, 0.5, 0.5)), "Transform origin should interpolate")
