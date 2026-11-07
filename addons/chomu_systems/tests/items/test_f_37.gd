extends RefCounted

const Impl := preload("res://addons/chomu_systems/net/net_conditioner.gd")

func run(t: Node) -> void:
	# 1. Test Latency
	var cond_lat := Impl.new(123)
	cond_lat.latency_ms = 100
	cond_lat.submit(1000, "pkt1")
	t.check("F-37 latency delay", cond_lat.drain(1050).is_empty(), "Packet should not arrive before 1100ms")
	t.check("F-37 latency delivery", cond_lat.drain(1100).size() == 1, "Packet should arrive at 1100ms")

	# 2. Test Loss (Statistical)
	var cond_loss := Impl.new(456)
	cond_loss.loss = 0.5
	var received := 0
	for i in range(1000):
		cond_loss.submit(0, i)
	var results := cond_loss.drain(0)
	received = results.size()
	t.check("F-37 loss probability", received > 400 and received < 600, "Loss 0.5 should result in ~500/1000 packets. Got: %d" % received)

	# 3. Test Determinism
	var c1 := Impl.new(789)
	var c2 := Impl.new(789)
	c1.loss = 0.3
	c2.loss = 0.3
	for i in range(100):
		c1.submit(0, i)
		c2.submit(0, i)
	t.check("F-37 determinism", c1.drain(0).size() == c2.drain(0).size(), "Same seed must produce same loss/jitter patterns")

	# 4. Test Diff States (Nested Dict and Array)
	var state_a := {
		"player": {"pos": Vector3(1, 2, 3), "inv": ["sword", "shield"]},
		"world": {"time": 10, "entities": [101, 102]}
	}
	var state_b := {
		"player": {"pos": Vector3(1, 2, 4), "inv": ["sword", "potion"]},
		"world": {"time": 11, "entities": [101, 103]}
	}
	var diffs := Impl.diff_states(state_a, state_b)
	t.check("F-37 diff nested dict", diffs.has("player/pos"), "Should detect nested change in player/pos")
	t.check("F-37 diff nested array", diffs.has("player/inv/1"), "Should detect change in array element player/inv[1]")
	t.check("F-37 diff array element", diffs.has("world/entities/1"), "Should detect change in array element world/entities[1]")
	t.check("F-37 diff root", diffs.has("world/time"), "Should detect change in world/time")
	t.check("F-37 diff count", diffs.size() == 4, "Should find exactly 4 differences")

	# 5. Test Dump Desync
	var path := "user://desync_test.json"
	Impl.dump_desync(42, state_a, state_b, path)
	t.check("F-37 dump file", FileAccess.file_exists(path), "Desync report should be written to disk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
