extends RefCounted
class_name ChomuGameStateMachine

## A data-driven Game State Machine for managing high-level game flow.
## Supports entry/exit callbacks, state-specific data, and serialization.
## Designed for mobile-first performance (low allocation, deterministic).

signal state_changed(old_state: String, new_state: String)

## Interface for state logic. Users should extend this to create custom states.
class GameState extends RefCounted:
	## Called when the machine enters this state.
	func enter(machine: ChomuGameStateMachine, data: Dictionary) -> void:
		pass
	
	## Called every physics frame while this state is active.
	func update(machine: ChomuGameStateMachine, delta: float) -> void:
		pass
	
	## Called when the machine exits this state.
	func exit(machine: ChomuGameStateMachine) -> void:
		pass
	
	## Returns a dictionary of state-specific variables for saving.
	func get_save_data() -> Dictionary:
		return {}
	
	## Restores state-specific variables from a dictionary.
	func load_save_data(data: Dictionary) -> void:
		pass

var _states: Dictionary = {} # String -> GameState
var _current_state_name: String = ""
var _current_state_obj: GameState = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Initializes the machine with a seed for deterministic behavior within states.
func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value

## Registers a state object with a unique name.
func add_state(state_name: String, state_obj: GameState) -> void:
	_states[state_name] = state_obj

## Transitions to the specified state.
## [param data] Optional dictionary passed to the enter() method of the new state.
func transition_to(state_name: String, data: Dictionary = {}) -> bool:
	if not _states.has(state_name):
		return false
	
	if _current_state_name == state_name:
		return true
	
	# Exit current
	if _current_state_obj:
		_current_state_obj.exit(self)
	
	var old_state = _current_state_name
	_current_state_name = state_name
	_current_state_obj = _states[state_name]
	
	# Enter new
	_current_state_obj.enter(self, data)
	
	state_changed.emit(old_state, state_name)
	return true

## Updates the active state. Should be called from a Node's _physics_process.
func update(delta: float) -> void:
	if _current_state_obj:
		_current_state_obj.update(self, delta)

## Returns the name of the currently active state.
func get_current_state() -> String:
	return _current_state_name

## Returns the RNG instance for use within states to maintain determinism.
func get_rng() -> RandomNumberGenerator:
	return _rng

## Captures the current state and the save data of the active state.
func save_state() -> Dictionary:
	var data = {
		"current_state": _current_state_name
	}
	if _current_state_obj:
		data["state_data"] = _current_state_obj.get_save_data()
	return data

## Restores the machine to a previous state and injects data into the state object.
func load_state(data: Dictionary) -> bool:
	var state_name = data.get("current_state", "")
	if state_name == "" or not _states.has(state_name):
		return false
	
	transition_to(state_name)
	
	if _current_state_obj and data.has("state_data"):
		_current_state_obj.load_save_data(data["state_data"])
	
	return true
