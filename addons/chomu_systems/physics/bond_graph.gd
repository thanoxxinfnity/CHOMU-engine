extends Node3D
class_name ChomuBondGraph

signal chunk_released(index: int)

var _chunks: Array[RigidBody3D] = []
var _anchored: Array[bool] = []
var _adjacency: Array[Dictionary] = []  # index -> {neighbor_index: strength}
var _active_bonds: Dictionary = {}  # "a,b" (sorted) -> strength

func _init() -> void:
	_chunks = []
	_anchored = []
	_adjacency = []
	_active_bonds = {}

func add_chunk(body: RigidBody3D, anchored: bool = false) -> int:
	var idx := _chunks.size()
	_chunks.append(body)
	_anchored.append(anchored)
	_adjacency.append({})
	if not anchored:
		body.freeze = true
	return idx

func add_bond(a: int, b: int, strength: float) -> void:
	if a < 0 or a >= _chunks.size() or b < 0 or b >= _chunks.size():
		push_error("Invalid chunk index for bond")
		return
	if a == b:
		return
	_adjacency[a][b] = strength
	_adjacency[b][a] = strength
	var key := _bond_key(a, b)
	_active_bonds[key] = strength

func _bond_key(a: int, b: int) -> String:
	if a > b:
		var tmp = a
		a = b
		b = tmp
	return "%d,%d" % [a, b]

func apply_impact(chunk: int, force: float) -> void:
	if chunk < 0 or chunk >= _chunks.size():
		return
	
	# BFS stress propagation
	var queue: Array[Array] = [[chunk, force, -1]]  # [node, stress, parent]
	var visited: Dictionary = {}
	var broken_bonds: Array[String] = []
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var node = current[0]
		var stress = current[1]
		var parent = current[2]
		
		if visited.has(node):
			continue
		visited[node] = true
		
		for neighbor in _adjacency[node]:
			var bond_strength = _adjacency[node][neighbor]
			var key = _bond_key(node, neighbor)
			
			if not _active_bonds.has(key):
				continue
			
			if stress > bond_strength:
				broken_bonds.append(key)
			else:
				var next_stress = stress * 0.5
				if next_stress > 0.001:  # threshold to stop propagation
					queue.append([neighbor, next_stress, node])
	
	# Break bonds
	for key in broken_bonds:
		_active_bonds.erase(key)
		var parts = key.split(",")
		var a = int(parts[0])
		var b = int(parts[1])
		_adjacency[a].erase(b)
		_adjacency[b].erase(a)
	
	# Find connected components and release those without anchors
	_release_unanchored_components()

func _release_unanchored_components() -> void:
	var visited: Array[bool] = []
	visited.resize(_chunks.size())
	visited.fill(false)
	
	for i in range(_chunks.size()):
		if visited[i]:
			continue
		
		var component: Array[int] = []
		var has_anchor = false
		var stack: Array[int] = [i]
		
		while stack.size() > 0:
			var node = stack.pop_back()
			if visited[node]:
				continue
			visited[node] = true
			component.append(node)
			if _anchored[node]:
				has_anchor = true
			
			for neighbor in _adjacency[node]:
				if _active_bonds.has(_bond_key(node, neighbor)):
					stack.append(neighbor)
		
		if not has_anchor and component.size() > 0:
			for idx in component:
				if not _anchored[idx]:
					_chunks[idx].freeze = false
					emit_signal("chunk_released", idx)

func bonds_remaining() -> int:
	return _active_bonds.size()

func is_connected_to_anchor(i: int) -> bool:
	if i < 0 or i >= _chunks.size():
		return false
	if _anchored[i]:
		return true
	
	var visited: Array[bool] = []
	visited.resize(_chunks.size())
	visited.fill(false)
	var stack: Array[int] = [i]
	
	while stack.size() > 0:
		var node = stack.pop_back()
		if visited[node]:
			continue
		visited[node] = true
		if _anchored[node]:
			return true
		for neighbor in _adjacency[node]:
			if _active_bonds.has(_bond_key(node, neighbor)):
				stack.append(neighbor)
	
	return false
