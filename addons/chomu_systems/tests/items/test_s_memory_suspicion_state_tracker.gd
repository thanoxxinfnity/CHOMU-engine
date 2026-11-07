extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/memory_suspicion_state_tracker.gd")

func run(t: Node) -> void:
	var tracker := Impl.new()
	var config := Impl.TrackerConfig.new()
	config.suspicion_gain_rate = 1.0 
	config.suspicion_decay_rate = 0.5
	config.suspicion_threshold = 0.3
	config.alert_threshold = 0.8
	config.memory_lifetime = 0.5 # Very short for reliable test
	tracker.set_config(config)

	# Test 1: Suspicion Gain
	tracker.update_entity("player", Vector3(10, 0, 10), 0.5)
	var state1 = tracker.get_entity_state("player")
	t.check("S-09 suspicion gain", state1.suspicion == 0.5, "Suspicion should increase when target is visible")
	t.check("S-09 state label", state1.state == "SUSPICIOUS", "0.5 should be SUSPICIOUS")

	# Test 2: Alert Threshold
	tracker.update_entity("player", Vector3(11, 0, 11), 0.4) # Total 0.9
	var state2 = tracker.get_entity_state("player")
	t.check("S-09 alert state", state2.state == "ALERT", "0.9 should be ALERT")

	# Test 3: Suspicion Decay and Investigation
	tracker.update_entity("player", null, 0.2) # Target lost
	var state3 = tracker.get_entity_state("player")
	t.check("S-09 decay", state3.suspicion < 0.9, "Suspicion should decay when target is lost")
	t.check("S-09 investigation start", state3.is_investigating == true, "Should investigate LKP when target lost but suspicion high")
	t.check("S-09 LKP accuracy", state3.lkp == Vector3(11, 0, 11), "LKP should be the last seen position")

	# Test 4: Memory Lifetime
	# Reset state to ensure we are tracking
	tracker.update_entity("player", Vector3(12, 0, 12), 0.1) 
	# Wait longer than memory_lifetime
	await t.get_tree().create_timer(0.7).timeout
	# Must call update_entity to trigger the internal expiration check
	tracker.update_entity("player", null, 0.1)
	var state4 = tracker.get_entity_state("player")
	t.check("S-09 memory expiration", state4.is_tracked == false, "Target should be forgotten after memory_lifetime")

	# Test 5: Save/Load State
	var tracker2 := Impl.new()
	tracker2.set_config(config)
	var save_data = tracker.save_state()
	tracker2.load_state(save_data)
	var state_loaded = tracker2.get_entity_state("player")
	t.check("S-09 serialization", state_loaded.suspicion == state4.suspicion, "Loaded suspicion should match saved")
