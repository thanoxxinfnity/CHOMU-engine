extends RefCounted
class_name ChomuMaterialPropertyBlockSystem

## Material Property Block System (S-107)
## Implements a data-driven system to manage per-instance material properties 
## without creating unique material resources for every object.
## 
## In Godot 4, this is primarily achieved via 'set_instance_shader_parameter'.
## This system abstracts the management of these parameters, providing 
## a centralized way to track, update, and serialize instance-specific data.

## Represents a block of properties for a specific instance.
class PropertyBlock:
	var properties: Dictionary = {} # String -> Variant
	
	## Sets a property value in this block.
	func set_property(p_name: String, p_value: Variant) -> void:
		properties[p_name] = p_value
		
	## Gets a property value or a default.
	func get_property(p_name: String, p_default: Variant = null) -> Variant:
		return properties.get(p_name, p_default)
	
	## Returns all properties as a dictionary.
	func get_all() -> Dictionary:
		return properties.duplicate()

var _instance_blocks: Dictionary = {} # int (instance_id) -> PropertyBlock
var _default_block: PropertyBlock = PropertyBlock.new()

## Sets a default value for all instances that don't have an override.
func set_default_property(p_name: String, p_value: Variant) -> void:
	_default_block.set_property(p_name, p_value)

## Gets the effective value for an instance (override or default).
func get_effective_property(instance_id: int, p_name: String, p_default: Variant = null) -> Variant:
	if _instance_blocks.has(instance_id):
		var block = _instance_blocks[instance_id]
		if block.properties.has(p_name):
			return block.get_property(p_name)
	return _default_block.get_property(p_name, p_default)

## Sets a property override for a specific instance.
func set_instance_property(instance_id: int, p_name: String, p_value: Variant) -> void:
	if not _instance_blocks.has(instance_id):
		_instance_blocks[instance_id] = PropertyBlock.new()
	_instance_blocks[instance_id].set_property(p_name, p_value)

## Removes an override for a specific instance, reverting it to default.
func remove_instance_property(instance_id: int, p_name: String) -> void:
	if _instance_blocks.has(instance_id):
		_instance_blocks[instance_id].properties.erase(p_name)

## Removes all overrides for an instance (e.g., when the object is destroyed).
func clear_instance(instance_id: int) -> void:
	_instance_blocks.erase(instance_id)

## Applies the stored properties to a GeometryInstance3D.
## This uses Godot's instance shader parameters.
func apply_to_instance(instance: GeometryInstance3D) -> void:
	var id = instance.get_instance_id()
	
	# Apply defaults first
	for prop_name in _default_block.properties:
		var val := _default_block.get_property(prop_name)
		# Check if instance has an override
		if _instance_blocks.has(id):
			var block = _instance_blocks[id]
			if block.properties.has(prop_name):
				val = block.get_property(prop_name)
		instance.set_instance_shader_parameter(prop_name, val)
		
	# Apply overrides that aren't in defaults
	if _instance_blocks.has(id):
		var block = _instance_blocks[id]
		for prop_name in block.properties:
			if not _default_block.properties.has(prop_name):
				instance.set_instance_shader_parameter(prop_name, block.get_property(prop_name))

## Serializes the current state of all blocks to a Dictionary.
func save_state() -> Dictionary:
	var state := {
		"defaults": _default_block.get_all(),
		"instances": {}
	}
	for id in _instance_blocks:
		state["instances"][str(id)] = _instance_blocks[id].get_all()
	return state

## Loads state from a Dictionary.
func load_state(data: Dictionary) -> void:
	if not data.has("defaults"): return
	
	_default_block.properties = data["defaults"].duplicate()
	_instance_blocks.clear()
	
	if data.has("instances"):
		for id_str in data["instances"]:
			var id = id_str.to_int()
			var block = PropertyBlock.new()
			block.properties = data["instances"][id_str].duplicate()
			_instance_blocks[id] = block
