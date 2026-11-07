extends RefCounted

const ChomuBehaviorSchema := preload("res://addons/chomu_systems/ai/behavior_schema.gd")
const ChomuBT := preload("res://addons/chomu_systems/ai/behavior_tree.gd")

func run(t: Node) -> void:
	var schema := ChomuBehaviorSchema.new()
	
	# Setup registered behaviors
	var bb := {"executed": false, "condition_met": true}
	var action_fn = func(b, _dt): 
		b["executed"] = true
		return ChomuBT.SUCCESS
	var cond_fn = func(b): 
		return b["condition_met"]
	
	schema.register_action("test_act", action_fn)
	schema.register_condition("test_cond", cond_fn)
	
	# 1. Valid JSON builds and executes
	var valid_json = '{"type": "sequence", "children": [{"type": "condition", "name": "test_cond"}, {"type": "action", "name": "test_act"}]}'
	var bt = schema.build(valid_json)
	t.check("F-23 Valid build", bt != null, "BT should be created from valid JSON")
	if bt:
		bt.tick(bb, 0.1)
		t.check("F-23 Valid execution", bb["executed"] == true, "Action should have been called")

	# 2. Unknown action error
	var unknown_act_json = '{"type": "action", "name": "ghost_action"}'
	var errs_act = schema.validate(unknown_act_json)
	t.check("F-23 Unknown action error", errs_act.size() > 0 and "Unknown action" in errs_act[0], "Should report unknown action")

	# 3. Malformed JSON error
	var malformed_json = '{"type": "action", "name": "test_act"' # Missing closing brace
	var errs_mal = schema.validate(malformed_json)
	t.check("F-23 Malformed JSON error", errs_mal.size() > 0 and "Invalid JSON" in errs_mal[0], "Should report JSON parse error")

	# 4. Missing children error
	var missing_kids_json = '{"type": "sequence", "children": []}'
	var errs_kids = schema.validate(missing_kids_json)
	t.check("F-23 Missing children error", errs_kids.size() > 0 and "cannot have empty children" in errs_kids[0], "Sequence needs children")

	# 5. Build returns null for invalid
	var bt_invalid = schema.build(unknown_act_json)
	t.check("F-23 Build null on invalid", bt_invalid == null, "Build must return null if validation fails")

	# 6. Depth limit check
	var deep_json = '{"type": "action", "name": "test_act"}'
	for i in range(33):
		deep_json = '{"type": "invert", "child": %s}' % deep_json
	
	var errs_deep = schema.validate(deep_json)
	t.check("F-23 Depth limit", errs_deep.size() > 0 and "depth exceeds maximum" in errs_deep[0], "Should catch stack overflow/depth")
