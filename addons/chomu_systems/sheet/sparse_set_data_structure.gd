extends RefCounted
class_name ChomuSparseSetDataStructure

## Sparse Set Data Structure for O(1) entity-component lookup.
## Uses two arrays: dense (entities in iteration order) and sparse (entity -> dense index mapping).
## When sparse[entity] = i, then dense[i] = entity. Invalid mappings store -1.
## Memory: O(n) where n = number of stored entities.
## Operations: insert/remove O(1), lookup O(1), iteration O(n).

var _dense: Array[int] = []
var _sparse: PackedInt32Array = []
var _size: int = 0

## Returns the number of entities in the set.
func size() -> int:
	return _size

## Returns true if the set contains no entities.
func is_empty() -> bool:
	return _size == 0

## Adds an entity to the set. Returns true if entity was newly added.
## If entity already exists, returns false (no-op).
func insert(entity: int) -> bool:
	if contains(entity):
		return false
	
	# Ensure sparse array is large enough
	if entity >= _sparse.size():
		var new_sparse := PackedInt32Array()
		new_sparse.resize(entity + 1)
		for i in range(entity + 1):
			new_sparse[i] = -1
		# Copy old values
		for i in range(_sparse.size()):
			new_sparse[i] = _sparse[i]
		_sparse = new_sparse
	
	_dense.append(entity)
	_sparse[entity] = _size
	_size += 1
	return true

## Removes an entity from the set. Returns true if entity was found and removed.
func erase(entity: int) -> bool:
	if not contains(entity):
		return false
	
	var idx: int = _sparse[entity]
	var last_entity: int = _dense[_size - 1]
	
	# Swap with last element
	_dense[idx] = last_entity
	_sparse[last_entity] = idx
	
	_dense.pop_back()
	_sparse[entity] = -1
	_size -= 1
	return true

## Returns true if the entity is in the set.
func contains(entity: int) -> bool:
	if entity < 0 or entity >= _sparse.size():
		return false
	return _sparse[entity] != -1 and _sparse[entity] < _size and _dense[_sparse[entity]] == entity

## Returns the dense array (entities in iteration order).
func to_array() -> Array[int]:
	return _dense.slice(0, _size)

## Clears all entities from the set.
func clear() -> void:
	_dense.clear()
	_sparse.clear()
	_size = 0

## Returns a copy of the internal state as a Dictionary for serialization.
func get_state() -> Dictionary:
	return {
		"dense": _dense.duplicate(),
		"sparse": _sparse,
		"size": _size
	}

## Restores state from a Dictionary.
func set_state(state: Dictionary) -> void:
	_dense = state.get("dense", []).duplicate()
	_sparse = state.get("sparse", PackedInt32Array())
	_size = state.get("size", 0)
