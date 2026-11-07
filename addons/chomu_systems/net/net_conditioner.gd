extends RefCounted
class_name ChomuNetConditioner

## F-37 Network Conditioner and Desync Forensics.
## Simulates network instability (latency, jitter, loss, duplication) deterministically.
## Provides utilities to diff state dictionaries and arrays for desync analysis.

@export var latency_ms: int = 0
@export var jitter_ms: int = 0
@export var loss: float = 0.0        ## 0.0 to 1.0
@export var duplicate: float = 0.0    ## 0.0 to 1.0

var _rng := RandomNumberGenerator.new()
var _queue: Array[Dictionary] = []

func _init(p_seed: int) -> void:
	_rng.seed = p_seed

## Queues a packet for delivery.
func submit(now_ms: int, packet: Variant) -> void:
	if _rng.randf() < loss:
		return
	
	var delivery_time := now_ms + latency_ms
	if jitter_ms > 0:
		delivery_time += _rng.randi_range(-jitter_ms, jitter_ms)
	
	_queue.append({"time": delivery_time, "data": packet})
	
	if _rng.randf() < duplicate:
		_queue.append({"time": delivery_time, "data": packet})
	
	# Keep queue sorted by delivery time
	_queue.sort_custom(func(a, b): return a["time"] < b["time"])

## Returns all packets whose delivery time has passed.
func drain(now_ms: int) -> Array:
	var ready: Array = []
	while _queue.size() > 0 and _queue[0]["time"] <= now_ms:
		var item := _queue.pop_front()
		ready.append(item["data"])
	return ready

## Recursively finds all keys/indices where two values differ.
static func diff_states(a: Variant, b: Variant, path: String = "") -> Array[String]:
	var diffs: Array[String] = []
	
	if a is Dictionary and b is Dictionary:
		var all_keys: Array = []
		all_keys.append_array(a.keys())
		for k in b.keys():
			if not a.has(k):
				all_keys.append(k)
		
		for k in all_keys:
			var current_path := path + ("/" if path != "" else "") + str(k)
			diffs.append_array(diff_states(a.get(k), b.get(k), current_path))
			
	elif a is Array and b is Array:
		var max_len := max(a.size(), b.size())
		for i in range(max_len):
			var current_path := path + ("/" if path != "" else "") + str(i)
			var val_a = a[i] if i < a.size() else null
			var val_b = b[i] if i < b.size() else null
			diffs.append_array(diff_states(val_a, val_b, current_path))
			
	elif a != b:
		diffs.append(path)
			
	return diffs

## Writes a JSON report of the desync between two states.
static func dump_desync(tick: int, a: Variant, b: Variant, file_path: String) -> void:
	var report := {
		"tick": tick,
		"diffs": diff_states(a, b),
		"state_a": a,
		"state_b": b
	}
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
