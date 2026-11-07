extends RefCounted
class_name ChomuTestCaseSynthesis

## Test-case synthesis core.
## Generates synthetic test cases from a seed and a configuration dictionary.
## Deterministic via seeded RandomNumberGenerator. State is serializable as Dictionary.
##
## Data layout:
##   _config: Dictionary with keys:
##     - "case_count": int        Number of cases to generate.
##     - "min_steps": int         Minimum steps per case.
##     - "max_steps": int         Maximum steps per case.
##     - "step_types": Array[String]  Allowed step type names.
##     - "difficulty": float      0.0-1.0, affects step complexity.
##   _cases: Array[Dictionary]    Generated test cases.
##   _rng: RandomNumberGenerator  Seeded RNG for determinism.

var _config: Dictionary = {}
var _cases: Array = []
var _rng: RandomNumberGenerator

class TestCase:
	var id: int = 0
	var title: String = ""
	var steps: Array = []
	var expected_result: String = ""
	var tags: Array = []

class TestStep:
	var step_type: String = ""
	var description: String = ""
	var data: Dictionary = {}

## Creates a new synthesizer with default config.
func _init() -> void:
	_config = {
		"case_count": 10,
		"min_steps": 1,
		"max_steps": 5,
		"step_types": ["input", "assert", "wait", "click"],
		"difficulty": 0.5,
	}
	_cases = []
	_rng = RandomNumberGenerator.new()
	_rng.seed = 12345

## Sets the generation config. Validates keys and clamps values.
func set_config(config: Dictionary) -> void:
	var defaults: Dictionary = {
		"case_count": 10,
		"min_steps": 1,
		"max_steps": 5,
		"step_types": ["input", "assert", "wait", "click"],
		"difficulty": 0.5,
	}
	for k in defaults.keys():
		if config.has(k):
			_config[k] = config[k]
		else:
			_config[k] = defaults[k]
	_config["case_count"] = max(0, int(_config["case_count"]))
	_config["min_steps"] = max(0, int(_config["min_steps"]))
	_config["max_steps"] = max(_config["min_steps"], int(_config["max_steps"]))
	_config["difficulty"] = clamp(float(_config["difficulty"]), 0.0, 1.0)
	if not _config.has("step_types") or _config["step_types"] == []:
		_config["step_types"] = ["input", "assert", "wait", "click"]

## Returns a copy of the current config.
func get_config() -> Dictionary:
	return _config.duplicate(true)

## Seeds the internal RNG for deterministic generation.
func seed(seed: int) -> void:
	_rng.seed = seed

## Generates test cases according to config. Clears previous cases.
func generate() -> void:
	_cases = []
	var count: int = int(_config["case_count"])
	var min_steps: int = int(_config["min_steps"])
	var max_steps: int = int(_config["max_steps"])
	var types: Array = _config["step_types"]
	var difficulty: float = float(_config["difficulty"])
	for i in range(count):
		var tc: Dictionary = {}
		tc["id"] = i
		tc["title"] = "Test Case %d" % i
		tc["steps"] = []
		tc["expected_result"] = "pass"
		tc["tags"] = []
		var step_count: int = _rng.randi_range(min_steps, max_steps)
		for s in range(step_count):
			var step: Dictionary = {}
			var t_idx: int = _rng.randi_range(0, types.size() - 1)
			step["step_type"] = types[t_idx]
			step["description"] = "%s step %d" % [types[t_idx], s]
			step["data"] = {"difficulty": difficulty}
			tc["steps"].append(step)
		if difficulty > 0.7:
			tc["expected_result"] = "fail"
		elif difficulty > 0.4:
			tc["expected_result"] = "warning"
		_cases.append(tc)

## Returns the generated cases (read-only reference).
func get_cases() -> Array:
	return _cases

## Returns case count.
func case_count() -> int:
	return _cases.size()

## Serializes state to Dictionary.
func save_state() -> Dictionary:
	return {
		"config": _config.duplicate(true),
		"cases": _cases.duplicate(true),
		"seed": _rng.seed,
	}

## Loads state from Dictionary.
func load_state(state: Dictionary) -> void:
	if state.has("config"):
		set_config(state["config"])
	if state.has("seed"):
		_rng.seed = int(state["seed"])
	if state.has("cases"):
		_cases = state["cases"].duplicate(true)
	else:
		generate()
