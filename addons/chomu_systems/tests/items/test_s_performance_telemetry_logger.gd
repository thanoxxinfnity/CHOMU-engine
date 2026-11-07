extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/performance_telemetry_logger.gd")

func run(t: Node) -> void:
	# Test 1: Basic Sampling
	var logger := Impl.new()
	logger.sample()
	var frame := logger.get_latest_frame()
	t.check("S-46 basic sample", frame.timestamp_ms > 0, "Timestamp should be recorded")
	
	# Test 2: Buffer Wrap-around
	var config := Impl.Config.new()
	config.buffer_size = 10
	config.sample_rate_ms = 0 # Sample every call
	var small_logger := Impl.new(config)
	
	for i in range(15):
		small_logger.sample()
	
	t.check("S-46 buffer wrap", small_logger._is_full == true, "Buffer should be marked full after 10 samples")
	t.check("S-46 write index wrap", small_logger._write_index == 5, "Write index should wrap to 5 after 15 samples")
	
	# Test 3: Metrics Calculation
	# Manually inject data for deterministic check
	for i in range(10):
		var f = small_logger._buffer[i]
		f.frame_time_ms = 16.0 + i # 16, 17... 25
	
	var avg := small_logger.get_avg_frame_time()
	t.check("S-46 avg calculation", abs(avg - 20.5) < 0.1, "Average of 16..25 should be 20.5")
	
	var max_f := small_logger.get_max_frame_time()
	t.check("S-46 max calculation", max_f == 25.0, "Max should be 25.0")
	
	# Test 4: Save/Load State
	var state := small_logger.save_state()
	var new_logger := Impl.new()
	new_logger.load_state(state)
	
	t.check("S-46 state load index", new_logger._write_index == small_logger._write_index, "Write index should be restored")
	t.check("S-46 state load data", new_logger._buffer[0].frame_time_ms == 16.0, "Sample data should be restored")
	
	# Test 5: Sample Rate Throttling
	var throttled_logger := Impl.new()
	throttled_logger._config.sample_rate_ms = 1000 # 1 second
	throttled_logger.sample()
	var first_ts := throttled_logger.get_latest_frame().timestamp_ms
	throttled_logger.sample() # Immediate call
	var second_ts := throttled_logger.get_latest_frame().timestamp_ms
	t.check("S-46 throttling", first_ts == second_ts, "Should not sample if interval not elapsed")
