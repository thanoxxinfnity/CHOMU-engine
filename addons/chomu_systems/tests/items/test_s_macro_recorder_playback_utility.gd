extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/macro_recorder_playback_utility.gd")

func run(t: Node) -> void:
	var macro = Impl.new()
	
	# Test 1: Basic Recording
	macro.start_recording()
	macro.record_event("key_down", "W")
	await t.physics_frames(2)
	macro.record_event("key_down", "S")
	macro.stop_recording()
	
	t.check("S-21 Record count", macro.get_event_count() == 2, "Should have recorded 2 events")
	
	# Test 2: Playback Sequence
	var played_events: Array[String] = []
	macro.event_played.connect(func(id, data): played_events.append(id))
	
	macro.start_playback(1.0)
	# Wait enough time for the events to trigger based on the recording gap
	await t.physics_frames(10)
	macro.update() 
	
	t.check("S-21 Playback sequence", played_events.size() >= 2, "Should have played back recorded events")
	
	# Test 3: Serialization
	var state = macro.save_state()
	var macro2 = Impl.new()
	macro2.load_state(state)
	t.check("S-21 Serialization count", macro2.get_event_count() == 2, "Loaded macro should have same event count")
	
	# Test 4: Playback Speed (Fast Forward)
	var fast_played: Array[String] = []
	var macro3 = Impl.new()
	macro3.start_recording()
	macro3.record_event("e1")
	# Create a significant gap
	await t.physics_frames(20)
	macro3.record_event("e2")
	macro3.stop_recording()
	
	macro3.event_played.connect(func(id, data): fast_played.append(id))
	# Play at 100x speed to ensure the gap is bridged almost instantly
	macro3.start_playback(100.0)
	# Wait a tiny bit for the clock to advance
	await t.physics_frames(1)
	macro3.update()
	
	t.check("S-21 Fast playback", fast_played.size() == 2, "Fast playback should trigger events quickly")
	
	# Test 5: Empty state handling
	var macro_empty = Impl.new()
	macro_empty.start_playback()
	t.check("S-21 Empty playback", macro_empty.is_playing() == false, "Should not be playing if no events exist")
