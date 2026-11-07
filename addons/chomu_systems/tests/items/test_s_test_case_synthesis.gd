extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/test_case_synthesis.gd")

func run(t: Node) -> void:
	var synth: ChomuTestCaseSynthesis = Impl.new()

	# Default config generates 10 cases.
	synth.generate()
	t.check("S-133 default case count", synth.case_count() == 10, "expected 10, got %d" % synth.case_count())

	# Seeded generation is deterministic.
	synth.seed(42)
	synth.generate()
	var state_a: Dictionary = synth.save_state()
	synth.seed(42)
	synth.generate()
	var state_b: Dictionary = synth.save_state()
	t.check("S-133 deterministic output", JSON.stringify(state_a) == JSON.stringify(state_b), "same seed should yield identical state")

	# Custom config respected.
	synth.set_config({"case_count": 3, "min_steps": 2, "max_steps": 2, "step_types": ["click"], "difficulty": 0.0})
	synth.generate()
	t.check("S-133 custom case count", synth.case_count() == 3, "expected 3, got %d" % synth.case_count())
	var all_click: bool = true
	for c in synth.get_cases():
		if c["steps"].size() != 2:
			all_click = false
		for s in c["steps"]:
			if s["step_type"] != "click":
				all_click = false
	t.check("S-133 custom steps and types", all_click, "all cases should have 2 click steps")

	# Difficulty affects expected result.
	synth.set_config({"case_count": 1, "min_steps": 1, "max_steps": 1, "step_types": ["input"], "difficulty": 0.9})
	synth.generate()
	t.check("S-133 high difficulty expected fail", synth.get_cases()[0]["expected_result"] == "fail", "high difficulty should expect fail")

	# Save/load roundtrip.
	synth.set_config({"case_count": 5, "min_steps": 1, "max_steps": 3, "step_types": ["wait", "assert"], "difficulty": 0.5})
	synth.seed(7)
	synth.generate()
	var saved: Dictionary = synth.save_state()
	var synth2: ChomuTestCaseSynthesis = Impl.new()
	synth2.load_state(saved)
	t.check("S-133 save/load case count", synth2.case_count() == 5, "loaded case count mismatch")
	t.check("S-133 save/load determinism", JSON.stringify(synth.save_state()) == JSON.stringify(synth2.save_state()), "loaded state should match original")

	# Empty config yields no cases.
	synth.set_config({"case_count": 0, "min_steps": 0, "max_steps": 0, "step_types": [], "difficulty": 0.5})
	synth.generate()
	t.check("S-133 zero cases", synth.case_count() == 0, "expected 0 cases")
