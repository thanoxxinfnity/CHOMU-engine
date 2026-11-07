extends RefCounted
class_name ChomuDependencyGraphResolver

## S-43 Dependency Graph Resolver
## A reusable implementation for tracking and resolving dependencies between assets.
## Used for Asset Cookers, Pipeline Management, and Resource Tracking.
##
## This implementation uses a Directed Acyclic Graph (DAG) approach to track
## which assets depend on others, allowing for topological sorting and 
## recursive dirty-marking.

# Internal storage: { asset_id: { "deps": Array[String], "dependents": Array[String] } }
var _graph: Dictionary = {}

## Adds an asset to the graph. If it already exists, it updates its dependencies.
## [param asset_id]: Unique identifier for the asset (e.g., file path).
## [param dependencies]: List of asset IDs that this asset depends on.
func register_asset(asset_id: String, dependencies: Array[String]) -> void:
	if not _graph.has(asset_id):
		_graph[asset_id] = { "deps": [], "dependents": [] }
	
	var node = _graph[asset_id]
	
	# Remove old dependency links to avoid duplicates/stale refs
	for old_dep in node["deps"]:
		if _graph.has(old_dep):
			var dep_node = _graph[old_dep]
			dep_node["dependents"].erase(asset_id)
	
	node["deps"] = dependencies
	
	# Establish new links
	for dep in dependencies:
		if not _graph.has(dep):
			_graph[dep] = { "deps": [], "dependents": [] }
		_graph[dep]["dependents"].append(asset_id)

## Removes an asset and cleans up all references to it in the graph.
func remove_asset(asset_id: String) -> bool:
	if not _graph.has(asset_id):
		return false
	
	var node = _graph[asset_id]
	
	# Remove this asset from its dependencies' dependent lists
	for dep in node["deps"]:
		if _graph.has(dep):
			_graph[dep]["dependents"].erase(asset_id)
			
	# Remove this asset from its dependents' dependency lists
	for dependent in node["dependents"]:
		if _graph.has(dependent):
			_graph[dependent]["deps"].erase(asset_id)
			
	_graph.erase(asset_id)
	return true

## Returns a list of assets that must be processed before the target asset.
## Uses a depth-first search to find all recursive dependencies.
func get_dependencies_recursive(asset_id: String) -> Array[String]:
	var visited: Dictionary = {}
	var queue: Array[String] = [asset_id]
	
	while queue.size() > 0:
		var curr = queue.pop_back()
		if not visited.has(curr):
			visited[curr] = true
			if _graph.has(curr):
				for dep in _graph[curr]["deps"]:
					queue.append(dep)
	
	visited.erase(asset_id)
	var final_list: Array[String] = []
	for key in visited.keys():
		final_list.append(key)
	return final_list

## Returns a list of assets that depend on the target asset (directly or indirectly).
## Useful for marking assets "dirty" when a low-level texture changes.
func get_dependents_recursive(asset_id: String) -> Array[String]:
	var visited: Dictionary = {}
	var queue: Array[String] = [asset_id]
	
	while queue.size() > 0:
		var curr = queue.pop_back()
		if not visited.has(curr):
			visited[curr] = true
			if _graph.has(curr):
				for dep in _graph[curr]["dependents"]:
					queue.append(dep)
	
	visited.erase(asset_id)
	var final_list: Array[String] = []
	for key in visited.keys():
		final_list.append(key)
	return final_list

## Returns a topologically sorted list of all assets in the graph.
## Assets that have no dependencies come first.
func get_topological_sort() -> Array[String]:
	var sorted: Array[String] = []
	var visited: Dictionary = {}
	var visiting: Dictionary = {}
	
	var nodes = _graph.keys()
	
	for node in nodes:
		_topo_visit(node, visited, visiting, sorted)
		
	return sorted

func _topo_visit(node_id: String, visited: Dictionary, visiting: Dictionary, sorted: Array[String]) -> void:
	if visiting.has(node_id):
		return # Cycle detected, skip to avoid infinite loop
	if visited.has(node_id):
		return
		
	visiting[node_id] = true
	if _graph.has(node_id):
		for dep in _graph[node_id]["deps"]:
			_topo_visit(dep, visited, visiting, sorted)
	
	visiting.erase(node_id)
	visited[node_id] = true
	sorted.append(node_id)

## Serializes the current graph state to a Dictionary.
func save_state() -> Dictionary:
	var state = {}
	for id in _graph.keys():
		state[id] = _graph[id]["deps"]
	return state

## Loads the graph state from a Dictionary.
func load_state(data: Dictionary) -> void:
	_graph.clear()
	for id in data.keys():
		var deps = data[id]
		if not deps is Array:
			continue
		var typed_deps: Array[String] = []
		for d in deps:
			typed_deps.append(str(d))
		register_asset(id, typed_deps)
