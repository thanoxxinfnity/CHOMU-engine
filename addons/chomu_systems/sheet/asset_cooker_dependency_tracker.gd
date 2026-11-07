extends RefCounted
class_name ChomuAssetCookerDependencyTracker

## S-55 Asset Cooker & Dependency Tracker
## Handles the conversion of raw assets into engine-friendly formats (cooking)
## and tracks the directed acyclic graph (DAG) of asset dependencies.
##
## This system ensures that if a dependency (e.g., a texture) changes, 
## all dependent assets (e.g., materials) are marked as dirty and re-cooked.

## Represents a cooked asset's metadata and its current state.
class AssetRecord:
	var path: String
	var hash: String
	var cooked_path: String
	var dependencies: Array[String] = []
	var is_dirty: bool = true
	var last_cooked_time: int = 0

	func _init(p_path: String):
		path = p_path

	func to_dict() -> Dictionary:
		return {
			"path": path,
			"hash": hash,
			"cooked_path": cooked_path,
			"dependencies": dependencies,
			"is_dirty": is_dirty,
			"last_cooked_time": last_cooked_time,
		}

	static func from_dict(d: Dictionary) -> AssetRecord:
		var rec = AssetRecord.new(d["path"])
		rec.hash = d["hash"]
		rec.cooked_path = d["cooked_path"]
		rec.dependencies = d["dependencies"]
		rec.is_dirty = d["is_dirty"]
		rec.last_cooked_time = d["last_cooked_time"]
		return rec

var _registry: Dictionary = {} # String (path) -> AssetRecord
var _rng: RandomNumberGenerator

func _init(seed_val: int = 42):
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val

## Registers an asset and its dependencies. 
## If the asset already exists, it updates the dependency list.
func register_asset(path: String, dependencies: Array[String] = []) -> void:
	var rec: AssetRecord
	if _registry.has(path):
		rec = _registry[path]
		rec.dependencies = dependencies
	else:
		rec = AssetRecord.new(path)
		rec.dependencies = dependencies
		_registry[path] = rec
	
	# Ensure all dependencies are also registered (even if empty)
	for dep in dependencies:
		if not _registry.has(dep):
			register_asset(dep)

## Marks an asset as dirty. Recursively marks all assets that depend on this one.
func mark_dirty(path: String) -> void:
	if not _registry.has(path):
		return
	
	var rec = _registry[path]
	if rec.is_dirty:
		return # Already dirty, stop recursion
	
	rec.is_dirty = true
	
	# Find everything that depends on this asset
	for other_path in _registry:
		var other_rec = _registry[other_path]
		if path in other_rec.dependencies:
			mark_dirty(other_path)

## Simulates the "cooking" process. 
## In a real scenario, this would call external tools or Godot's Import system.
## Returns the path to the cooked asset.
func cook_asset(path: String, cook_fn: Callable) -> String:
	if not _registry.has(path):
		push_error("Asset not registered: %s" % path)
		return ""
	
	var rec = _registry[path]
	
	# Check if dependencies are cooked first (bottom-up)
	for dep in rec.dependencies:
		var dep_rec = _registry[dep]
		if dep_rec.is_dirty:
			# This is a simplified recursive cook. 
			# In production, we'd use a topological sort.
			cook_asset(dep, cook_fn)
	
	# Perform the cook
	var result = cook_fn.call(path)
	if result == "":
		push_error("Cooking failed for: %s" % path)
		return ""
	
	rec.cooked_path = result
	rec.is_dirty = false
	rec.last_cooked_time = Time.get_ticks_msec()
	rec.hash = _generate_mock_hash(path)
	
	return rec.cooked_path

## Returns a list of all assets that need cooking.
func get_dirty_assets() -> Array[String]:
	var dirty: Array[String] = []
	for path in _registry:
		if _registry[path].is_dirty:
			dirty.append(path)
	return dirty

## Generates a deterministic hash for the asset based on path and RNG.
func _generate_mock_hash(path: String) -> String:
	var seed_val = 0
	for i in range(path.length()):
		seed_val += path.unicode_at(i)
	_rng.seed = seed_val
	return "%08x" % _rng.randi()

## Saves the current registry state to a Dictionary.
func save_state() -> Dictionary:
	var state = {}
	for path in _registry:
		state[path] = _registry[path].to_dict()
	return state

## Loads the registry state from a Dictionary.
func load_state(data: Dictionary) -> void:
	_registry.clear()
	for path in data:
		_registry[path] = AssetRecord.from_dict(data[path])

## Returns the dependency chain for an asset (BFS).
func get_all_dependencies(path: String) -> Array[String]:
	var result: Array[String] = []
	var queue: Array[String] = []
	
	if _registry.has(path):
		queue.append(path)
	
	var visited = {}
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		
		if _registry.has(current):
			var rec = _registry[current]
			for dep in rec.dependencies:
				if dep != path:
					result.append(dep)
				queue.append(dep)
				
	return result
