extends RefCounted
class_name ChomuInterestGrid

## Spatial hash grid for interest management.
## Tracks entities and clients to determine which entities are relevant to which clients.

var _cell_size: float
var _entities: Dictionary = {} # id: Vector3
var _clients: Dictionary = {} # id: {pos: Vector3, radius: float, current_set: Array[int]}
var _grid: Dictionary = {} # Vector3i: Array[int]

## Debugging: tracks how many cells were scanned during the last relevant() call.
var last_cells_scanned: int = 0

func _init(p_cell_size: float = 16.0) -> void:
	_cell_size = p_cell_size

func _get_cell_coords(pos: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(pos.x / _cell_size)),
		int(floor(pos.y / _cell_size)),
		int(floor(pos.z / _cell_size))
	)

func upsert_entity(id: int, pos: Vector3) -> void:
	var old_pos = _entities.get(id)
	if old_pos != null:
		var old_cell = _get_cell_coords(old_pos)
		var cell_list = _grid.get(old_cell, [])
		cell_list.erase(id)
		if cell_list.is_empty():
			_grid.erase(old_cell)
	
	_entities[id] = pos
	var new_cell = _get_cell_coords(pos)
	if not _grid.has(new_cell):
		_grid[new_cell] = []
	_grid[new_cell].append(id)

func remove_entity(id: int) -> void:
	var pos = _entities.get(id)
	if pos == null:
		return
	
	var cell = _get_cell_coords(pos)
	var cell_list = _grid.get(cell, [])
	cell_list.erase(id)
	if cell_list.is_empty():
		_grid.erase(cell)
	
	_entities.erase(id)

func set_client(client_id: int, pos: Vector3, radius: float) -> void:
	if not _clients.has(client_id):
		_clients[client_id] = {
			"pos": pos,
			"radius": radius,
			"current_set": []
		}
	else:
		_clients[client_id]["pos"] = pos
		_clients[client_id]["radius"] = radius

func relevant(client_id: int) -> Array[int]:
	var client = _clients.get(client_id)
	if client == null:
		return []
	
	var pos: Vector3 = client["pos"]
	var radius: float = client["radius"]
	var radius_sq: float = radius * radius
	var results: Array[int] = []
	
	var min_cell = _get_cell_coords(pos - Vector3(radius, radius, radius))
	var max_cell = _get_cell_coords(pos + Vector3(radius, radius, radius))
	
	last_cells_scanned = 0
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for z in range(min_cell.z, max_cell.z + 1):
				last_cells_scanned += 1
				var cell_coords = Vector3i(x, y, z)
				var cell_entities = _grid.get(cell_coords)
				if cell_entities:
					for ent_id in cell_entities:
						var ent_pos = _entities[ent_id]
						if pos.distance_squared_to(ent_pos) <= radius_sq:
							results.append(ent_id)
	
	return results

func update() -> Dictionary:
	var changes: Dictionary = {}
	
	for client_id in _clients.keys():
		var client = _clients[client_id]
		var new_set = relevant(client_id)
		var old_set = client["current_set"]
		
		var entered: Array[int] = []
		var left: Array[int] = []
		
		var new_set_map = {}
		for id in new_set: new_set_map[id] = true
		var old_set_map = {}
		for id in old_set: old_set_map[id] = true
		
		for id in new_set:
			if not old_set_map.has(id):
				entered.append(id)
		
		for id in old_set:
			if not new_set_map.has(id):
				left.append(id)
		
		client["current_set"] = new_set
		if not entered.is_empty() or not left.is_empty():
			changes[client_id] = {
				"entered": entered,
				"left": left
			}
			
	return changes
