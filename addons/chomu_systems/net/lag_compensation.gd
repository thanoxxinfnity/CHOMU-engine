extends RefCounted
class_name ChomuLagCompensation

var _tick_rate: int
var _history_seconds: float
var _capacity: int
var _buffer: Array[Dictionary]  # each entry: {tick: int, entities: Dictionary[int, Dictionary]}
var _head: int = 0
var _count: int = 0
var _oldest_tick: int = 0
var _newest_tick: int = 0
var _initialized: bool = false

func _init(tick_rate: int = 60, history_seconds: float = 1.0) -> void:
	_tick_rate = tick_rate
	_history_seconds = history_seconds
	_capacity = int(ceil(tick_rate * history_seconds))
	_buffer = []
	_buffer.resize(_capacity)
	for i in range(_capacity):
		_buffer[i] = { "tick": 0, "entities": {} }
	_initialized = true

func record(tick: int, id: int, center: Vector3, radius: float) -> void:
	if not _initialized:
		return
	
	var idx = tick % _capacity
	var entry = _buffer[idx]
	
	if _count == 0:
		_oldest_tick = tick
		_newest_tick = tick
		_count = 1
		entry.tick = tick
		entry.entities = { id: { "center": center, "radius": radius } }
		_head = idx
		return
	
	if tick == entry.tick:
		entry.entities[id] = { "center": center, "radius": radius }
		if tick > _newest_tick:
			_newest_tick = tick
		return
	
	if tick > _newest_tick:
		var ticks_advanced = tick - _newest_tick
		if ticks_advanced >= _capacity:
			clear_old_entries(tick)
		else:
			advance_head(ticks_advanced, tick)
		_newest_tick = tick
	elif tick < _oldest_tick:
		return
	
	idx = tick % _capacity
	entry = _buffer[idx]
	entry.tick = tick
	entry.entities[id] = { "center": center, "radius": radius }
	
	if tick < _oldest_tick:
		_oldest_tick = tick

func clear_old_entries(new_tick: int) -> void:
	for i in range(_capacity):
		_buffer[i].tick = 0
		_buffer[i].entities.clear()
	_oldest_tick = new_tick
	_newest_tick = new_tick
	_count = 1
	_head = new_tick % _capacity

func advance_head(ticks_advanced: int, new_tick: int) -> void:
	var old_oldest = _oldest_tick
	_oldest_tick = new_tick - _capacity + 1
	if _oldest_tick < old_oldest:
		_oldest_tick = old_oldest
	
	var start_clear = (_head + 1) % _capacity
	var end_clear = new_tick % _capacity
	var idx = start_clear
	while idx != end_clear:
		if _buffer[idx].tick >= old_oldest and _buffer[idx].tick < _oldest_tick:
			_buffer[idx].entities.clear()
		idx = (idx + 1) % _capacity
	_head = new_tick % _capacity

func position_at(id: int, tick: int) -> Vector3:
	if not _initialized or _count == 0:
		return Vector3.ZERO
	
	tick = clamp_tick(tick)
	
	var exact_idx = tick % _capacity
	var exact_entry = _buffer[exact_idx]
	if exact_entry.tick == tick and exact_entry.entities.has(id):
		return exact_entry.entities[id].center
	
	var prev_tick = -1
	var next_tick = -1
	var prev_center = Vector3.ZERO
	var next_center = Vector3.ZERO
	
	var search_tick = tick
	for _i in range(_capacity):
		var idx = search_tick % _capacity
		var entry = _buffer[idx]
		if entry.tick == search_tick and entry.entities.has(id):
			if search_tick <= tick:
				prev_tick = search_tick
				prev_center = entry.entities[id].center
			else:
				next_tick = search_tick
				next_center = entry.entities[id].center
				break
		search_tick -= 1
		if search_tick < _oldest_tick:
			break
	
	if next_tick == -1:
		search_tick = tick + 1
		for _i in range(_capacity):
			var idx = search_tick % _capacity
			var entry = _buffer[idx]
			if entry.tick == search_tick and entry.entities.has(id):
				next_tick = search_tick
				next_center = entry.entities[id].center
				break
			search_tick += 1
			if search_tick > _newest_tick:
				break
	
	if prev_tick == -1 and next_tick == -1:
		return Vector3.ZERO
	if prev_tick == -1:
		return next_center
	if next_tick == -1:
		return prev_center
	
	var t = float(tick - prev_tick) / float(next_tick - prev_tick)
	return prev_center.lerp(next_center, t)

func raycast_at(tick: int, from: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	if not _initialized or _count == 0:
		return {}
	
	tick = clamp_tick(tick)
	var idx = tick % _capacity
	var entry = _buffer[idx]
	
	if entry.tick != tick:
		return {}
	
	var best_hit: Dictionary = {}
	var best_dist: float = max_dist
	var dir_norm = dir.normalized()
	
	for id in entry.entities:
		var ent = entry.entities[id]
		var center = ent.center
		var radius = ent.radius
		
		var oc = from - center
		var a = dir_norm.dot(dir_norm)
		var b = 2.0 * oc.dot(dir_norm)
		var c = oc.dot(oc) - radius * radius
		var disc = b * b - 4.0 * a * c
		
		if disc < 0.0:
			continue
		
		var sqrt_disc = sqrt(disc)
		var t1 = (-b - sqrt_disc) / (2.0 * a)
		var t2 = (-b + sqrt_disc) / (2.0 * a)
		
		var t = t1 if t1 >= 0.0 else t2
		if t < 0.0 or t > max_dist:
			continue
		
		if t < best_dist:
			best_dist = t
			best_hit = { "id": id, "point": from + dir_norm * t, "distance": t }
	
	return best_hit

func clamp_tick(tick: int) -> int:
	if tick < _oldest_tick:
		return _oldest_tick
	if tick > _newest_tick:
		return _newest_tick
	return tick

func oldest_tick() -> int:
	return _oldest_tick

func newest_tick() -> int:
	return _newest_tick

func get_capacity() -> int:
	return _capacity

func get_tick_rate() -> int:
	return _tick_rate

func get_history_seconds() -> float:
	return _history_seconds
