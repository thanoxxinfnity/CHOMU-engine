extends RefCounted
class_name ChomuDecisionTimeline

## F-53 AI Decision Timeline.
## Records a deterministic history of AI states, scores, and blackboard data per agent.
## Supports scrubbing, replay serialization, and HFSM integration.

var _capacity: int
var _data: Dictionary = {} # agent_id -> Array[Dictionary]

func _init(capacity: int = 600) -> void:
	_capacity = capacity

## Records a snapshot of the AI's decision state.
func record(tick: int, agent: String, state_path: String, scores: Dictionary = {}, blackboard: Dictionary = {}) -> void:
	if not _data.has(agent):
		_data[agent] = []
	
	var buffer: Array = _data[agent]
	var entry = {
		"tick": tick,
		"state": state_path,
		"scores": scores.duplicate(true),
		"blackboard": blackboard.duplicate(true)
	}
	
	buffer.append(entry)
	if buffer.size() > _capacity:
		buffer.remove_at(0)

## Returns list of agents who have recorded data.
func agents() -> Array[String]:
	var list: Array[String] = []
	for k in _data.keys():
		list.append(k)
	return list

## Returns the latest record for the agent where record.tick <= requested_tick.
func at(agent: String, tick: int) -> Dictionary:
	if not _data.has(agent):
		return {}
	
	var buffer: Array = _data[agent]
	if buffer.is_empty():
		return {}
	
	# Since records are appended chronologically, we search backwards
	for i in range(buffer.size() - 1, -1, -1):
		var entry = buffer[i]
		if entry["tick"] <= tick:
			return entry.duplicate(true)
	
	return {}

## Returns all records for an agent between from_tick and to_tick (inclusive).
func range(agent: String, from_tick: int, to_tick: int) -> Array:
	if not _data.has(agent):
		return []
	
	var result: Array = []
	for entry in _data[agent]:
		if entry["tick"] >= from_tick and entry["tick"] <= to_tick:
			result.append(entry.duplicate(true))
	return result

## Detects state changes for an agent.
func transitions(agent: String) -> Array:
	if not _data.has(agent):
		return []
	
	var buffer: Array = _data[agent]
	var trans: Array = []
	if buffer.size() < 2:
		return trans
	
	for i in range(1, buffer.size()):
		var prev = buffer[i-1]
		var curr = buffer[i]
		if prev["state"] != curr["state"]:
			trans.append({
				"tick": curr["tick"],
				"from": prev["state"],
				"to": curr["state"]
			})
	return trans

## Connects a ChomuHFSM to this timeline.
func attach_hfsm(hfsm: Node, agent: String, tick_source: Callable) -> void:
	if not hfsm is ChomuHFSM:
		return
	
	# Connect HFSM signal to record the state change
	hfsm.state_entered.connect(func(path: String):
		var tick: int = 0
		if tick_source.is_valid():
			tick = tick_source.call()
		record(tick, agent, path, {}, hfsm.blackboard)
	)

## Serializes all recorded data to JSON.
func to_json() -> String:
	return JSON.stringify(_data)

## Deserializes data from JSON.
func from_json(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed

## Builds a simple UI scrubber for a specific agent.
func build_scrubber(agent: String) -> Control:
	if not _data.has(agent):
		return Control.new()
	
	var container := VBoxContainer.new()
	var label := Label.new()
	var slider := HSlider.new()
	
	var buffer: Array = _data[agent]
	var min_tick = buffer[0]["tick"]
	var max_tick = buffer[-1]["tick"]
	
	slider.min_value = float(min_tick)
	slider.max_value = float(max_tick)
	slider.step = 1.0
	slider.value = float(max_tick)
	
	var update_label = func(_val: float):
		var entry = at(agent, int(_val))
		if entry.is_empty():
			label.text = "No data at tick %d" % int(_val)
		else:
			label.text = "Tick %d | State: %s" % [int(_val), entry["state"]]
	
	slider.value_changed.connect(update_label)
	update_label.call(slider.value)
	
	container.add_child(label)
	container.add_child(slider)
	return container
