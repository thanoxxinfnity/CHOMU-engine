extends RefCounted
class_name ChomuPerformanceTelemetryLogger

## Performance Telemetry Logger (S-46)
## Real-time collection of frame times, draw calls, and memory usage metrics.
## Designed for mobile-first performance: low allocation, fixed-size buffers.

## Configuration for the telemetry logger
class Config:
	var buffer_size: int = 600 # 10 seconds at 60fps
	var sample_rate_ms: int = 16 # Target sampling interval
	var enable_memory_tracking: bool = true
	var enable_gpu_tracking: bool = true

## A single snapshot of performance metrics
class TelemetryFrame:
	var timestamp_ms: int = 0
	var frame_time_ms: float = 0.0
	var draw_calls: int = 0
	var memory_usage_mb: float = 0.0
	var fps: float = 0.0

## Main logger implementation
var _config: Config = Config.new()
var _buffer: Array[TelemetryFrame] = []
var _write_index: int = 0
var _is_full: bool = false
var _last_sample_time: int = 0

## Initializes the logger with a specific configuration.
func _init(config: Config = null) -> void:
	if config:
		_config = config
	_buffer.resize(_config.buffer_size)
	for i in range(_config.buffer_size):
		_buffer[i] = TelemetryFrame.new()

## Samples current engine performance metrics.
## Should be called once per frame or at the configured sample rate.
func sample() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sample_time < _config.sample_rate_ms:
		return
	
	_last_sample_time = now
	var frame := _buffer[_write_index]
	
	frame.timestamp_ms = now
	# Performance.get_monitor returns values in seconds for time
	frame.frame_time_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	frame.fps = 1.0 / max(0.0001, Performance.get_monitor(Performance.TIME_PROCESS))
	
	if _config.enable_gpu_tracking:
		# Note: draw_calls is a general monitor, may vary by renderer
		frame.draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	
	if _config.enable_memory_tracking:
		# Static memory in bytes to MB
		frame.memory_usage_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	
	_write_index += 1
	if _write_index >= _config.buffer_size:
		_write_index = 0
		_is_full = true

## Returns the average frame time over the current buffer.
func get_avg_frame_time() -> float:
	var count := _config.buffer_size if _is_full else _write_index
	if count == 0: return 0.0
	
	var sum := 0.0
	for i in range(count):
		sum += _buffer[i].frame_time_ms
	return sum / float(count)

## Returns the maximum frame time (spike) in the current buffer.
func get_max_frame_time() -> float:
	var count := _config.buffer_size if _is_full else _write_index
	if count == 0: return 0.0
	
	var max_val := 0.0
	for i in range(count):
		max_val = max(max_val, _buffer[i].frame_time_ms)
	return max_val

## Returns the most recent telemetry frame.
func get_latest_frame() -> TelemetryFrame:
	var idx := _write_index - 1
	if idx < 0:
		idx = _config.buffer_size - 1 if _is_full else 0
	return _buffer[idx]

## Exports the current buffer state as a Dictionary for persistence.
func save_state() -> Dictionary:
	var data: Dictionary = {
		"config": {
			"buffer_size": _config.buffer_size,
			"sample_rate_ms": _config.sample_rate_ms,
			"enable_memory_tracking": _config.enable_memory_tracking,
			"enable_gpu_tracking": _config.enable_gpu_tracking
		},
		"write_index": _write_index,
		"is_full": _is_full,
		"samples": []
	}
	
	var count := _config.buffer_size if _is_full else _write_index
	for i in range(count):
		var f := _buffer[i]
		data["samples"].append({
			"t": f.timestamp_ms,
			"ft": f.frame_time_ms,
			"dc": f.draw_calls,
			"mem": f.memory_usage_mb
		})
	return data

## Restores the logger state from a Dictionary.
func load_state(data: Dictionary) -> void:
	var c_data := data.get("config", {})
	_config.buffer_size = c_data.get("buffer_size", 600)
	_config.sample_rate_ms = c_data.get("sample_rate_ms", 16)
	_config.enable_memory_tracking = c_data.get("enable_memory_tracking", true)
	_config.enable_gpu_tracking = c_data.get("enable_gpu_tracking", true)
	
	_buffer.clear()
	_buffer.resize(_config.buffer_size)
	for i in range(_config.buffer_size):
		_buffer[i] = TelemetryFrame.new()
		
	var samples := data.get("samples", [])
	for i in range(samples.size()):
		if i >= _config.buffer_size: break
		var s = samples[i]
		var f := _buffer[i]
		f.timestamp_ms = s.get("t", 0)
		f.frame_time_ms = s.get("ft", 0.0)
		f.draw_calls = s.get("dc", 0)
		f.memory_usage_mb = s.get("mem", 0.0)
		
	_write_index = data.get("write_index", 0)
	_is_full = data.get("is_full", false)
