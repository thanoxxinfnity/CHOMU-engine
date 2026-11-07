extends RefCounted
class_name ChomuUtilityAiScoringEngine

## Utility AI Scoring Engine.
## Context-based decision making where AI weighs multiple survival/attack actions.
## Data-driven, deterministic (seeded RNG), headless-safe, save/load via Dictionary.
## Standard shipped-game design: score each candidate action by evaluating weighted
## considerations (curves) against blackboard context, then pick the argmax.

class ConsiderationConfig:
	var name: String = ""
	var weight: float = 1.0
	var curve: String = "linear" # linear, ease_in, ease_out, sigmoid, step
	var min_input: float = 0.0
	var max_input: float = 1.0
	var min_output: float = 0.0
	var max_output: float = 1.0

class ActionConfig:
	var name: String = ""
	var priority: float = 0.0 # static tie-breaker bias
	var considerations: Array[ConsiderationConfig] = []
	var cooldown_seconds: float = 0.0

class ActionInstance:
	var config: ActionConfig
	var last_used_tick: int = -999999
	var cooldown_remaining: float = 0.0

var seed: int = 12345
var rng: RandomNumberGenerator
var blackboard: Dictionary = {}
var actions: Array[ActionInstance] = []
var current_tick: int = 0
var debug_last_scores: Dictionary = {}

func _init(seed: int = 12345) -> void:
	self.seed = seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed

## Register an action config (copied internally).
func register_action(config: ActionConfig) -> void:
	var inst: ActionInstance = ActionInstance.new()
	inst.config = config
	actions.append(inst)

## Set blackboard context value used by considerations.
func set_context(key: String, value: Variant) -> void:
	blackboard[key] = value

## Get blackboard context value.
func get_context(key: String, default: Variant = null) -> Variant:
	return blackboard.get(key, default)

## Advance simulation tick and cooldowns.
func tick() -> void:
	current_tick += 1
	for inst in actions:
		if inst.cooldown_remaining > 0.0:
			inst.cooldown_remaining -= 1.0 # assumes 1 tick = 1 second; callers can scale

## Evaluate a single consideration against blackboard input.
func _evaluate_consideration(conf: ConsiderationConfig) -> float:
	var raw: float = 0.0
	var val: Variant = blackboard.get(conf.name, 0.0)
	if val is float:
		raw = val
	elif val is int:
		raw = float(val)
	raw = clampf(raw, conf.min_input, conf.max_input)
	var t: float = 0.0
	if conf.max_input > conf.min_input:
		t = (raw - conf.min_input) / (conf.max_input - conf.min_input)
	t = clampf(t, 0.0, 1.0)
	var out: float = _apply_curve(t, conf.curve)
	out = lerpf(conf.min_output, conf.max_output, out)
	return out * conf.weight

func _apply_curve(t: float, curve: String) -> float:
	match curve:
		"linear":
			return t
		"ease_in":
			return t * t
		"ease_out":
			return 1.0 - (1.0 - t) * (1.0 - t)
		"sigmoid":
			# smoothstep
			return t * t * (3.0 - 2.0 * t)
		"step":
			return 1.0 if t >= 0.5 else 0.0
		_:
			return t

## Score all actions and return sorted list of {name, score, config}.
func score_actions() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	debug_last_scores = {}
	for inst in actions:
		var score: float = inst.config.priority
		var usable: bool = true
		if inst.cooldown_remaining > 0.0:
			usable = false
		if usable:
			for cconf in inst.config.considerations:
				score += _evaluate_consideration(cconf)
		score = clampf(score, 0.0, 1e6)
		debug_last_scores[inst.config.name] = {"score": score, "usable": false}
		results.append({"name": inst.config.name, "score": score, "usable": usable, "config": inst.config})
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	return results

## Select the best usable action (argmax). Returns name or "" if none usable.
func select_action() -> String:
	var best_name: String = ""
	var best_score: float = -1e9
	for inst in actions:
		if inst.cooldown_remaining > 0.0:
			continue
		var score: float = inst.config.priority
		for cconf in inst.config.considerations:
			score += _evaluate_consideration(cconf)
		if score > best_score:
			best_score = score
			best_name = inst.config.name
	return best_name

## Execute selected action: starts its cooldown. Returns true if executed.
func execute_action(name: String) -> bool:
	for inst in actions:
		if inst.config.name == name:
			if inst.cooldown_remaining > 0.0:
				return false
			inst.cooldown_remaining = inst.config.cooldown_seconds
			inst.last_used_tick = current_tick
			return true
	return false

## Convenience: score, select, execute in one step. Returns chosen name or "".
func decide_and_execute() -> String:
	var results: Array[Dictionary] = score_actions()
	var i: int = 0
	while i < results.size():
		var r: Dictionary = results[i]
		if r.has("usable") and r["usable"] and execute_action(r["name"]):
			return r["name"]
		i += 1
	return ""

## Save mutable state to Dictionary.
func save_state() -> Dictionary:
	var d: Dictionary = {}
	d["seed"] = seed
	d["current_tick"] = current_tick
	d["blackboard"] = blackboard.duplicate()
	var acts: Array[Dictionary] = []
	for inst in actions:
		acts.append({
			"name": inst.config.name,
			"last_used_tick": inst.last_used_tick,
			"cooldown_remaining": inst.cooldown_remaining,
		})
	d["actions"] = acts
	return d

## Load state from Dictionary.
func load_state(data: Dictionary) -> void:
	seed = data.get("seed", seed)
	rng.seed = seed
	current_tick = data.get("current_tick", 0)
	blackboard = data.get("blackboard", {}).duplicate()
	var acts: Array[Dictionary] = data.get("actions", [])
	var i: int = 0
	while i < acts.size():
		var a: Dictionary = acts[i]
		var name: String = a.get("name", "")
		for inst in actions:
			if inst.config.name == name:
				inst.last_used_tick = a.get("last_used_tick", -999999)
				inst.cooldown_remaining = a.get("cooldown_remaining", 0.0)
				break
		i += 1
