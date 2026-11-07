extends RefCounted

const Impl = preload("res://addons/chomu_systems/net/replication_schema.gd")

class MockEntity extends Node3D:
	const REPLICATE = {
		"position": {"priority": "high", "quantize": "pos16", "interp": "hermite"},
		"health": {"priority": "low"}
	}
	var health: float = 100.0

func run(t: Node) -> void:
	var entity = MockEntity.new()
	t.add_child(entity)
	
	var schema = Impl.from_object(entity)
	
	# 1. Test capture
	var state = schema.capture(entity)
	t.check("F-32 capture reads fields", state.has("health") and state.has("position"), "Should capture REPLICATE fields")
	
	# 2. Test empty delta
	var delta_empty = schema.build_delta(state, entity, 1)
	t.check("F-32 empty delta", delta_empty.is_empty(), "No changes should result in empty delta")
	
	# 3. Test high priority immediate, low priority delayed
	entity.position = Vector3(1, 2, 3)
	entity.health = 50.0
	
	# Tick 1: High priority (position) should be here, low (health) should not
	var delta1 = schema.build_delta(state, entity, 1)
	t.check("F-32 high priority immediate", delta1.has("position"), "Position should be in delta")
	t.check("F-32 low priority delayed", not delta1.has("health"), "Health should be skipped on tick 1")
	
	# Tick 10: Low priority should now be included
	var delta10 = schema.build_delta(state, entity, 10)
	t.check("F-32 low priority included", delta10.has("health"), "Health should be in delta on tick 10")
	
	# 4. Test quantization
	if delta1.has("position"):
		var pos_val = delta1["position"]
		t.check("F-32 pos16 quantization", pos_val is PackedInt32Array, "Position should be quantized to PackedInt32Array")
	
	# 5. Test apply
	var entity2 = MockEntity.new()
	t.add_child(entity2)
	schema.apply(entity2, delta10)
	t.check("F-32 apply sets fields", entity2.health == 50.0, "Apply should restore health")
	t.check("F-32 apply sets position", entity2.position.is_equal_approx(Vector3(1, 2, 3)), "Apply should restore position")
	
	# 6. Test Hermite Interpolation
	var p0 = Vector3(0, 0, 0)
	var p1 = Vector3(10, 0, 0)
	var v0 = Vector3.ZERO
	var v1 = Vector3.ZERO
	
	var mid = Impl.hermite(p0, v0, p1, v1, 0.5)
	t.check("F-32 hermite midpoint", mid.is_equal_approx(Vector3(5, 0, 0)), "Midpoint of zero-velocity hermite should be linear")
	
	var start = Impl.hermite(p0, v0, p1, v1, 0.0)
	t.check("F-32 hermite start", start.is_equal_approx(p0), "t=0 should be p0")
	
	var end = Impl.hermite(p0, v0, p1, v1, 1.0)
	t.check("F-32 hermite end", end.is_equal_approx(p1), "t=1 should be p1")
	
	entity.queue_free()
	entity2.queue_free()
