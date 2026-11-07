extends RefCounted
class_name ChomuReplicationSchema

## Handles attribute-driven replication for objects.
## Expects a constant REPLICATE = {"field": {"priority": "high"/"low", "quantize": "pos16", "interp": "hermite"/"linear"}}

var _config: Dictionary = {}

func _init(config: Dictionary = {}):
	_config = config

static func from_object(obj: Object) -> ChomuReplicationSchema:
	var script = obj.get_script()
	if not script:
		return ChomuReplicationSchema.new()
	
	var constants = script.get_script_constant_map()
	var replicate_cfg = constants.get("REPLICATE", {})
	return ChomuReplicationSchema.new(replicate_cfg)

func capture(obj: Object) -> Dictionary:
	var state := {}
	for field in _config.keys():
		if field in obj:
			state[field] = obj.get(field)
	return state

func build_delta(baseline: Dictionary, obj: Object, tick: int) -> Dictionary:
	var delta := {}
	var current = capture(obj)
	
	# Fix: _config.keys() returns a plain Array, cannot assign to Array[String] directly
	var fields = _config.keys()
	fields.sort_custom(func(a, b):
		var p_a = _config[a].get("priority", "high")
		var p_b = _config[b].get("priority", "high")
		return p_a == "high" and p_b == "low"
	)
	
	for field in fields:
		var cfg = _config[field]
		var priority = cfg.get("priority", "high")
		
		# Low priority only every 10 ticks
		if priority == "low" and (tick % 10 != 0):
			continue
			
		var val = current.get(field)
		var base_val = baseline.get(field)
		
		if val != base_val:
			var processed_val = val
			if cfg.get("quantize") == "pos16" and val is Vector3:
				processed_val = _quantize_pos16(val)
			
			delta[field] = processed_val
			
	return delta

func apply(obj: Object, delta: Dictionary) -> void:
	for field in delta.keys():
		var val = delta[field]
		if _config.has(field) and _config[field].get("quantize") == "pos16" and val is PackedInt32Array:
			val = _dequantize_pos16(val)
		
		if field in obj:
			obj.set(field, val)

static func interpolate(prev: Dictionary, next: Dictionary, t: float, config: Dictionary) -> Dictionary:
	var result := {}
	for field in next.keys():
		if not prev.has(field):
			result[field] = next[field]
			continue
			
		var v0 = prev[field]
		var v1 = next[field]
		var interp_type = config.get(field, {}).get("interp", "linear")
		
		if interp_type == "hermite" and v0 is Vector3 and v1 is Vector3:
			result[field] = hermite(v0, Vector3.ZERO, v1, Vector3.ZERO, t)
		elif v0 is Vector3 and v1 is Vector3:
			result[field] = v0.lerp(v1, t)
		elif v0 is float and v1 is float:
			result[field] = lerp(v0, v1, t)
		else:
			result[field] = v1 if t > 0.5 else v0
			
	return result

static func hermite(p0: Vector3, v0: Vector3, p1: Vector3, v1: Vector3, t: float) -> Vector3:
	var t2 = t * t
	var t3 = t2 * t
	var h00 = 2.0 * t3 - 3.0 * t2 + 1.0
	var h10 = t3 - 2.0 * t2 + t
	var h01 = -2.0 * t3 + 3.0 * t2
	var h11 = t3 - t2
	return p0 * h00 + v0 * h10 + p1 * h01 + v1 * h11

func _quantize_pos16(v: Vector3) -> PackedInt32Array:
	return PackedInt32Array([
		int(v.x * 100.0),
		int(v.y * 100.0),
		int(v.z * 100.0)
	])

func _dequantize_pos16(data: PackedInt32Array) -> Vector3:
	return Vector3(
		float(data[0]) / 100.0,
		float(data[1]) / 100.0,
		float(data[2]) / 100.0
	)
