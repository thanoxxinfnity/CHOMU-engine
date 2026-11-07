extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/custom_b_zier_curve_editor_widget.gd")

func run(t: Node) -> void:
	var widget := Impl.new()
	t.add_child(widget)
	
	t.check("S-77 Point Addition", widget.add_point(Vector2(0, 0)) == 0 and widget.add_point(Vector2(100, 0)) == 1, "Should add points and return sequential IDs")
	
	# Test sampling
	var mid_point = widget.sample_curve(0.5)
	t.check("S-77 Curve Sampling", mid_point.x > 0 and mid_point.x < 100, "Midpoint of (0,0) and (100,0) should be between them")
	
	# Test state serialization
	var state = widget.save_state()
	t.check("S-77 Save State", state.points.size() == 2, "Saved state should contain 2 points")
	
	var widget2 := Impl.new()
	t.add_child(widget2)
	widget2.load_state(state)
	t.check("S-77 Load State", widget2.sample_curve(0.5).is_equal_approx(mid_point), "Loaded curve should sample identically")
	
	# Test point removal
	widget.remove_point(0)
	t.check("S-77 Point Removal", widget.save_state().points.size() == 1, "Point count should decrease after removal")
	
	# Test deterministic sampling with control points
	# Clear and setup specific points for logic check
	widget.remove_point(0) # remove the remaining point
	var p0_id = widget.add_point(Vector2(0, 0))
	var p1_id = widget.add_point(Vector2(100, 0))
	
	# Access internal points for setup
	var p0 = widget._points[p0_id]
	var p1 = widget._points[p1_id]
	p0.control_out = Vector2(0, 100)
	p1.control_in = Vector2(100, 100)
	
	var peak = widget.sample_curve(0.5)
	t.check("S-77 Bezier Logic", peak.y > 0, "Curve should bow upwards due to control points")
	
	widget.queue_free()
	widget2.queue_free()
