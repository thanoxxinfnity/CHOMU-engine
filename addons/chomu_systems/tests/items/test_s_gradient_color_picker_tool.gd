extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/gradient_color_picker_tool.gd")

func run(t: Node) -> void:
	var tool := Impl.new()
	
	t.check("S-96 basic sampling", true, "Should sample exact stop colors")
	var id1 = tool.add_stop(0.0, Color.RED)
	var id2 = tool.add_stop(1.0, Color.BLUE)
	t.check("S-96 sample start", tool.sample(0.0).is_equal_approx(Color.RED), "Start should be red")
	t.check("S-96 sample end", tool.sample(1.0).is_equal_approx(Color.BLUE), "End should be blue")
	
	t.check("S-96 interpolation", true, "Should interpolate linearly")
	var mid = tool.sample(0.5)
	t.check("S-96 mid color", mid.is_equal_approx(Color(0.5, 0, 0.5, 1.0)), "Mid should be purple")
	
	t.check("S-96 multi-stop", true, "Should handle multiple stops")
	tool.add_stop(0.25, Color.GREEN)
	var quarter_mid = tool.sample(0.125)
	t.check("S-96 quarter mid", quarter_mid.is_equal_approx(Color(0.5, 0.5, 0, 1.0)), "Should be yellow-ish")
	
	t.check("S-96 update stop", true, "Should update stop position")
	tool.update_stop(id1, 0.1, Color.RED)
	t.check("S-96 sample before first", tool.sample(0.0).is_equal_approx(Color.RED), "Should clamp to first stop")
	
	t.check("S-96 partial update", true, "Should update only offset if color is sentinel")
	var id_green = tool.get_stops()[1].id
	var old_color = tool.get_stops()[1].color
	tool.update_stop(id_green, 0.3, Color(-1, -1, -1, -1))
	t.check("S-96 color preserved", tool.get_stops()[1].color.is_equal_approx(old_color), "Color should not change")
	t.check("S-96 offset changed", tool.get_stops()[1].offset == 0.3, "Offset should change")
	
	t.check("S-96 remove stop", true, "Should remove stop and recalculate")
	tool.remove_stop(id_green)
	var new_mid = tool.sample(0.55)
	# t=0.55 is between 0.1 and 1.0. local_t = (0.55 - 0.1) / (1.0 - 0.1) = 0.5
	t.check("S-96 post-removal mid", new_mid.is_equal_approx(Color(0.5, 0, 0.5, 1.0)), "Should interpolate between remaining")
	
	t.check("S-96 serialization", true, "Should save and load state")
	var state = tool.save_state()
	var tool2 = Impl.new()
	tool2.load_state(state)
	t.check("S-96 load sample", tool2.sample(0.55).is_equal_approx(tool.sample(0.55)), "Loaded tool should match original")
	t.check("S-96 load stop count", tool2.get_stops().size() == tool.get_stops().size(), "Stop count should match")
