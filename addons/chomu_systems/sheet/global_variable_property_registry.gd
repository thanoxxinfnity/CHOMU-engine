extends RefCounted
class_name ChomuGlobalVariablePropertyRegistry

## Global Variable & Property Registry (S-95)
## A safe, centralized table for sharing data between scripts.
## Supports typed variables, property-like access, and state serialization.
## Designed for low RAM overhead and deterministic behavior.

## Represents a registered variable with metadata.
class VariableEntry:
	var name: String
	var value: Variant
	var type_hint: int # Using Godot's Variant.Type
	var is_read_only: bool
	
	func _init(p_name: String, p_value: Variant, p_type: int, p_read_only: bool):
		name = p_name
		value = p_value
		type_hint = p_type
		is_read_only = p_read_only

var _registry: Dictionary = {} # String -> VariableEntry
var _rng: RandomNumberGenerator

func _init(seed_val: int = 12345):
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val

## Registers a new variable in the global registry.
## If the variable already exists, it will be overwritten unless it is read-only.
## Returns true if registration was successful.
func register_variable(var_name: String, initial_value: Variant, type_hint: int = TYPE_NIL, read_only: bool = false) -> bool:
	if _registry.has(var_name):
		var existing = _registry[var_name] as VariableEntry
		if existing.is_read_only:
			return false
	
	var entry = VariableEntry.new(var_name, initial_value, type_hint, read_only)
	_registry[var_name] = entry
	return true

## Sets the value of a registered variable.
## Returns true if the value was updated, false if the variable doesn't exist or is read-only.
func set_variable(var_name: String, value: Variant) -> bool:
	if not _registry.has(var_name):
		return false
	
	var entry = _registry[var_name] as VariableEntry
	if entry.is_read_only:
		return false
	
	# Type validation if a hint is provided
	if entry.type_hint != TYPE_NIL:
		if typeof(value) != entry.type_hint:
			return false
			
	entry.value = value
	return true

## Gets the value of a registered variable.
## Returns the default_value if the variable is not found.
func get_variable(var_name: String, default_value: Variant = null) -> Variant:
	if not _registry.has(var_name):
		return default_value
	return _registry[var_name].value

## Checks if a variable is registered.
func has_variable(var_name: String) -> bool:
	return _registry.has(var_name)

## Removes a variable from the registry.
func unregister_variable(var_name: String) -> bool:
	if not _registry.has(var_name):
		return false
	var entry = _registry[var_name] as VariableEntry
	if entry.is_read_only:
		return false
	_registry.erase(var_name)
	return true

## Returns a dictionary of all current variable values for serialization.
func save_state() -> Dictionary:
	var state: Dictionary = {}
	for key in _registry:
		state[key] = _registry[key].value
	return state

## Restores variable values from a dictionary. 
## Only updates existing variables to maintain registry structure/type safety.
func load_state(state: Dictionary) -> void:
	for key in state:
		if _registry.has(key):
			set_variable(key, state[key])

## Utility to get a random float based on the internal seeded RNG.
func get_random_float(min_val: float = 0.0, max_val: float = 1.0) -> float:
	return _rng.randf_range(min_val, max_val)

## Returns a list of all registered variable names.
func get_all_variable_names() -> Array[String]:
	var names: Array[String] = []
	for key in _registry.keys():
		names.append(key)
	return names
