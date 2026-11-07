extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/distance_attenuation.gd")

func run(t: Node) -> void:
	# Access the inner class via the script instance or the class_name
	# Since Impl is the preloaded GDScript, we use Impl.AttenuationConfig.new()
	
	# Test 1: Linear Attenuation
	var lin_cfg := Impl.AttenuationConfig.new(Impl.Model.LINEAR, 2.0, 12.0)
	t.check("S-82 Linear: at min", Impl.calculate(1.0, lin_cfg) == 1.0, "Should be 1.0 inside min")
	t.check("S-82 Linear: at min boundary", Impl.calculate(2.0, lin_cfg) == 1.0, "Should be 1.0 at min")
	t.check("S-82 Linear: midpoint", Impl.calculate(7.0, lin_cfg) == 0.5, "Should be 0.5 at midpoint")
	t.check("S-82 Linear: at max", Impl.calculate(12.0, lin_cfg) == 0.0, "Should be 0.0 at max")
	t.check("S-82 Linear: beyond max", Impl.calculate(15.0, lin_cfg) == 0.0, "Should be 0.0 beyond max")

	# Test 2: Inverse Attenuation
	var inv_cfg := Impl.AttenuationConfig.new(Impl.Model.INVERSE, 1.0, 100.0, 1.0)
	t.check("S-82 Inverse: at min", Impl.calculate(1.0, inv_cfg) == 1.0, "Should be 1.0 at min")
	# dist=2, min=1, rolloff=1 => 1 / (1 + 1*(2-1)) = 0.5
	t.check("S-82 Inverse: distance 2", Impl.calculate(2.0, inv_cfg) == 0.5, "Inverse distance 2 should be 0.5")
	# dist=3, min=1, rolloff=1 => 1 / (1 + 1*(3-1)) = 0.333...
	t.check("S-82 Inverse: distance 3", abs(Impl.calculate(3.0, inv_cfg) - 0.3333) < 0.001, "Inverse distance 3 should be ~0.33")

	# Test 3: Logarithmic Attenuation
	var log_cfg := Impl.AttenuationConfig.new(Impl.Model.LOGARITHMIC, 1.0, 10.0, 1.0)
	t.check("S-82 Log: at min", Impl.calculate(1.0, log_cfg) == 1.0, "Should be 1.0 at min")
	t.check("S-82 Log: at max", Impl.calculate(10.0, log_cfg) == 0.0, "Should be 0.0 at max")
	# Logarithmic should drop faster initially than linear
	var lin_mid := Impl.calculate(5.5, Impl.AttenuationConfig.new(Impl.Model.LINEAR, 1.0, 10.0))
	var log_mid := Impl.calculate(5.5, log_cfg)
	t.check("S-82 Log: curve shape", log_mid < lin_mid, "Logarithmic should be lower than linear at midpoint")

	# Test 4: Serialization
	var original := Impl.AttenuationConfig.new(Impl.Model.INVERSE, 5.0, 50.0, 2.5)
	var data := Impl.save_config(original)
	var loaded := Impl.load_config(data)
	t.check("S-82 Save/Load: model", loaded.model == original.model, "Model mismatch")
	t.check("S-82 Save/Load: min", loaded.min_distance == original.min_distance, "Min distance mismatch")
	t.check("S-82 Save/Load: max", loaded.max_distance == original.max_distance, "Max distance mismatch")
	t.check("S-82 Save/Load: rolloff", loaded.rolloff_factor == original.rolloff_factor, "Rolloff mismatch")
