extends RefCounted
class_name ChomuBehaviorSchema

const ChomuBT := preload("res://addons/chomu_systems/ai/behavior_tree.gd")

var _actions: Dictionary = {} # String -> Callable
var _conditions: Dictionary = {} # String -> Callable

## Register a function to be used as an action node.
## fn signature: func(bb: Dictionary, dt: float) -> int
func register_action(p_name: String, p_fn: Callable) -> void:
	_actions[p_name] = p_fn

## Register a function to be used as a condition node.
## fn signature: func(bb: Dictionary) -> bool
func register_condition(p_name: String, p_fn: Callable) -> void:
	_conditions[p_name] = p_fn

## Returns a dictionary describing the expected JSON structure for LLM prompting.
func schema() -> Dictionary:
	return {
		"node_types": {
			"sequence": {"fields": {"children": "Array[Node]"}, "desc": "Succeeds if all children succeed"},
			"selector": {"fields": {"children": "Array[Node]"}, "desc": "Succeeds if any child succeeds"},
			"utility": {"fields": {"children": "Array[Node]", "scores": "Array[String]"}, "desc": "Picks child with highest score from registered score functions"},
			"invert": {"fields": {"child": "Node"}, "desc": "Inverts SUCCESS/FAILURE"},
			"cooldown": {"fields": {"child": "Node", "seconds": "float"}, "desc": "Prevents execution until cooldown expires"},
			"condition": {"fields": {"name": "String"}, "desc": "Checks registered condition name"},
			"action": {"fields": {"name": "String"}, "desc": "Executes registered action name"}
		},
		"registered_actions": _actions.keys(),
		"registered_conditions": _conditions.keys()
	}

## Validates JSON text against the schema. Returns array of error strings.
func validate(json_text: String) -> Array[String]:
	var errors: Array[String] = []
	
	# Use JSON.parse to avoid the engine printing an ERROR to stderr on failure
	var json = JSON.new()
	var parse_err = json.parse(json_text)
	if parse_err != OK:
		errors.append("Invalid JSON format")
		return errors
	
	var data = json.data
	if not (data is Dictionary):
		errors.append("Root must be a JSON object")
		return errors

	_validate_node(data, 0, errors)
	return errors

func _validate_node(node: Variant, depth: int, errors: Array[String]) -> void:
	if depth > 32:
		errors.append("Tree depth exceeds maximum of 32")
		return
	
	if not (node is Dictionary):
		errors.append("Node must be an object")
		return
	
	var type = node.get("type", "")
	if type == "":
		errors.append("Node missing 'type' field")
		return
	
	match type:
		"sequence", "selector":
			var kids = node.get("children")
			if kids == null or not (kids is Array):
				errors.append("Type %s requires 'children' array" % type)
			elif kids.size() == 0:
				errors.append("Type %s cannot have empty children" % type)
			else:
				for k in kids:
					_validate_node(k, depth + 1, errors)
		"utility":
			var kids = node.get("children")
			var scores = node.get("scores")
			if kids == null or not (kids is Array):
				errors.append("Utility requires 'children' array")
			if scores == null or not (scores is Array):
				errors.append("Utility requires 'scores' array")
			if kids is Array and scores is Array and kids.size() != scores.size():
				errors.append("Utility children and scores arrays must match in size")
			if kids is Array:
				for k in kids:
					_validate_node(k, depth + 1, errors)
		"invert", "cooldown":
			var child = node.get("child")
			if child == null:
				errors.append("Type %s requires 'child' object" % type)
			else:
				_validate_node(child, depth + 1, errors)
			if type == "cooldown":
				var sec = node.get("seconds")
				if sec == null or not (sec is float or sec is int):
					errors.append("Cooldown requires 'seconds' as float")
		"condition":
			var name = node.get("name")
			if name == null or not (name is String):
				errors.append("Condition requires 'name' string")
			elif not _conditions.has(name):
				errors.append("Unknown condition: %s" % name)
		"action":
			var name = node.get("name")
			if name == null or not (name is String):
				errors.append("Action requires 'name' string")
			elif not _actions.has(name):
				errors.append("Unknown action: %s" % name)
		_:
			errors.append("Unknown node type: %s" % type)

## Builds a ChomuBT from JSON. Returns null if validation fails.
func build(json_text: String) -> ChomuBT:
	var errors = validate(json_text)
	if errors.size() > 0:
		return null
	
	var data = JSON.parse_string(json_text)
	var root_node = _build_node(data)
	return ChomuBT.new(root_node)

func _build_node(node: Dictionary) -> ChomuBT.BTNode:
	var type = node.get("type", "")
	match type:
		"sequence":
			var kids: Array = []
			for k in node.children:
				kids.append(_build_node(k))
			return ChomuBT.sequence(kids)
		"selector":
			var kids: Array = []
			for k in node.children:
				kids.append(_build_node(k))
			return ChomuBT.selector(kids)
		"utility":
			var kids: Array = []
			var scores: Array = []
			for i in node.children.size():
				kids.append(_build_node(node.children[i]))
				var score_name = node.scores[i]
				scores.append(_conditions.get(score_name, func(_bb): return 0.0))
			return ChomuBT.utility(kids, scores)
		"invert":
			return ChomuBT.invert(_build_node(node.child))
		"cooldown":
			return ChomuBT.cooldown(_build_node(node.child), float(node.seconds))
		"condition":
			return ChomuBT.condition(_conditions[node.name])
		"action":
			return ChomuBT.action(_actions[node.name])
	return null
