extends RefCounted
class_name ChomuAnimationMasking

## ChomuAnimationMasking implements a data-driven animation masking system.
## It allows blending different animations on different parts of a skeleton
## by defining masks (sets of bones) and managing their weights.
##
## This is a core implementation for "Upper body shooting / Lower body running" scenarios.

## Defines a mask of bones and their influence weights.
class Mask:
	var bone_weights: Dictionary = {} # Bone Name (String) -> Weight (float 0..1)

	func _init(weights: Dictionary = {}):
		bone_weights = weights

	## Returns the weight for a specific bone, defaulting to 0.0.
	func get_weight(bone_name: String) -> float:
		return bone_weights.get(bone_name, 0.0)

	## Returns a list of all bones affected by this mask.
	func get_affected_bones() -> Array:
		return Array(bone_weights.keys())

## Represents a layer of animation that can be masked.
class AnimationLayer:
	var name: String
	var weight: float = 1.0
	var mask: Mask
	var is_active: bool = true

	func _init(layer_name: String, mask_obj: Mask):
		name = layer_name
		mask = mask_obj

## The main controller for animation masking.
## It calculates the final blend weights for bones across multiple layers.
## This class is designed to be used by an AnimationTree or a custom Skeleton3D driver.
## It does not modify the Skeleton3D directly to remain headless-testable.

var layers: Array[AnimationLayer] = []

## Adds a new animation layer with a specific mask.
func add_layer(layer_name: String, mask_data: Dictionary) -> AnimationLayer:
	var mask := Mask.new(mask_data)
	var layer := AnimationLayer.new(layer_name, mask)
	layers.append(layer)
	return layer

## Removes a layer by name.
func remove_layer(layer_name: String) -> bool:
	for i in range(layers.size()):
		if layers[i].name == layer_name:
			layers.remove_at(i)
			return true
	return false

## Sets the weight of a specific layer.
func set_layer_weight(layer_name: String, weight: float) -> bool:
	for layer in layers:
		if layer.name == layer_name:
			layer.weight = clampf(weight, 0.0, 1.0)
			return true
	return false

## Calculates the final blend weight for a specific bone.
func get_bone_blend_weight(bone_name: String, layer_name: String) -> float:
	for layer in layers:
		if layer.name == layer_name:
			if not layer.is_active:
				return 0.0
			return layer.mask.get_weight(bone_name) * layer.weight
	return 0.0

## Returns the total influence of all layers on a bone.
func get_total_bone_influence(bone_name: String) -> float:
	var total: float = 0.0
	for layer in layers:
		if layer.is_active:
			total += layer.mask.get_weight(bone_name) * layer.weight
	return total

## Saves the current state of layers and weights to a Dictionary.
func save_state() -> Dictionary:
	var state: Dictionary = {}
	var layer_states: Array = []
	for layer in layers:
		layer_states.append({
			"name": layer.name,
			"weight": layer.weight,
			"is_active": layer.is_active,
			"mask": layer.mask.bone_weights
		})
	state["layers"] = layer_states
	return state

## Loads the state from a Dictionary.
func load_state(data: Dictionary) -> void:
	if not data.has("layers"):
		return
	
	layers.clear()
	for l_data in data["layers"]:
		var mask := Mask.new(l_data["mask"])
		var layer := AnimationLayer.new(l_data["name"], mask)
		layer.weight = l_data.get("weight", 1.0)
		layer.is_active = l_data.get("is_active", true)
		layers.append(layer)

## Utility to create a common "Upper Body" mask.
static func create_upper_body_mask(bone_names: Array[String]) -> Dictionary:
	var weights: Dictionary = {}
	for b in bone_names:
		weights[b] = 1.0
	return weights

## Utility to create a common "Lower Body" mask.
static func create_lower_body_mask(bone_names: Array[String]) -> Dictionary:
	var weights: Dictionary = {}
	for b in bone_names:
		weights[b] = 1.0
	return weights
