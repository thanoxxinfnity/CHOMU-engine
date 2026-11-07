extends RefCounted

const Impl := preload("res://addons/chomu_systems/ai/decision_timeline.gd")

func run(t: Node) -> void:
	var timeline := Impl.new(10) # Small capacity to test ring buffer
	
	# 1. Basic recording and retrieval
	timeline.record(10, "bot1", "Idle", {"score": 0.1}, {"hp": 100})
	timeline.record(20, "bot1", "Patrol", {"score": 0.5}, {"hp": 90})
	
	var entry = timeline.at("bot1", 15)
	t.check("F-53 resolve to latest earlier tick", entry.has("state") and entry["state"] == "Idle", "Should resolve tick 15 to tick 10")
	
	# 2. Ring buffer capacity
	for i in range(20):
		timeline.record(100 + i, "bot1", "State%d" % i)
	
	var agents = timeline.agents()
	t.check("F-53 agent tracking", agents.has("bot1"), "bot1 should be in agents list")
	
	# The first few records (tick 10, 20) should be gone since capacity is 10
	var old_entry = timeline.at("bot1", 15)
	t.check("F-53 ring capacity respected", old_entry.is_empty(), "Old records should be evicted, returning empty dict")
	
	# 3. Transitions detection
	timeline.record(200, "bot2", "A")
	timeline.record(201, "bot2", "A")
	timeline.record(202, "bot2", "B")
	timeline.record(203, "bot2", "B")
	timeline.record(204, "bot2", "C")
	
	var trans = timeline.transitions("bot2")
	t.check("F-53 transition count", trans.size() == 2, "Should detect A->B and B->C")
	t.check("F-53 transition detail", trans[0]["from"] == "A" and trans[0]["to"] == "B", "First transition A to B")
	
	# 4. JSON Round trip
	var json_data = timeline.to_json()
	var timeline2 := Impl.new(10)
	timeline2.from_json(json_data)
	var round_entry = timeline2.at("bot2", 204)
	t.check("F-53 JSON round trip", round_entry.has("state") and round_entry["state"] == "C", "Data should persist through JSON")
	
	# 5. Scrubber UI logic
	var scrubber = timeline.build_scrubber("bot2")
	t.add_child(scrubber)
	var label = scrubber.get_child(0) as Label
	var slider = scrubber.get_child(1) as HSlider
	
	slider.value = 200.0
	t.check("F-53 scrubber label update", "State: A" in label.text, "Label should update when slider moves")
	
	scrubber.queue_free()
