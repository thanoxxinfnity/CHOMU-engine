class_name ChomuWorldStreamer
extends Node3D
## F-71 World partition streamer. The XZ plane is split into square cells
## (default 128 m). Cells within `load_radius` of the tracked node are loaded
## asynchronously with ResourceLoader.load_threaded_request and instanced at
## most `max_instances_per_frame` per frame; cells beyond
## `load_radius + unload_margin` are freed (hysteresis avoids thrash).
##
## Cell source: `cell_path_pattern` with {x} and {z} placeholders
## (e.g. "res://world/cell_{x}_{z}.tscn"), or `cell_path_provider`
## Callable(Vector2i) -> String. Missing files are simply skipped.

signal cell_requested(cell: Vector2i)
signal cell_loaded(cell: Vector2i, node: Node)
signal cell_unloaded(cell: Vector2i)

@export var target: Node3D
@export var cell_size := 128.0
@export var load_radius := 1          ## in cells (1 -> 3x3 around the player)
@export var unload_margin := 1
@export var cell_path_pattern := ""
@export var offset_cells := true      ## place each cell at its grid origin
@export var max_instances_per_frame := 1
@export var use_sub_threads := false
@export var update_interval := 0.25

var cell_path_provider: Callable
var loaded := {}     ## Vector2i -> Node
var pending := {}    ## Vector2i -> path
var current_cell := Vector2i(1 << 30, 0)
var _timer := 0.0
var _ready_queue: Array[Vector2i] = []

func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / cell_size), floori(p.z / cell_size))

func cell_origin(c: Vector2i) -> Vector3:
	return Vector3(c.x * cell_size, 0.0, c.y * cell_size)

func path_for(c: Vector2i) -> String:
	if cell_path_provider.is_valid():
		return str(cell_path_provider.call(c))
	if cell_path_pattern.is_empty():
		return ""
	return cell_path_pattern.replace("{x}", str(c.x)).replace("{z}", str(c.y))

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		refresh()
	_poll()
	_instance_ready()

## Recomputes wanted cells (call after teleports).
func refresh() -> void:
	if target == null or not is_instance_valid(target):
		return
	var c := world_to_cell(target.global_position)
	current_cell = c
	var wanted: Array[Vector2i] = []
	for dz in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			wanted.append(c + Vector2i(dx, dz))
	# nearest first
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - c).length_squared() < (b - c).length_squared())
	for w in wanted:
		if loaded.has(w) or pending.has(w):
			continue
		var p := path_for(w)
		if p.is_empty() or not ResourceLoader.exists(p):
			continue
		var err := ResourceLoader.load_threaded_request(p, "PackedScene", use_sub_threads)
		if err == OK:
			pending[w] = p
			cell_requested.emit(w)
	var keep := load_radius + unload_margin
	for lc in loaded.keys():
		var d: Vector2i = lc - c
		if absi(d.x) > keep or absi(d.y) > keep:
			unload_cell(lc)
	for pc in pending.keys():
		var d2: Vector2i = pc - c
		if absi(d2.x) > keep or absi(d2.y) > keep:
			pending.erase(pc) # result is dropped when it lands

func _poll() -> void:
	for c in pending.keys():
		var p: String = pending[c]
		var st := ResourceLoader.load_threaded_get_status(p)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			if not _ready_queue.has(c):
				_ready_queue.append(c)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("ChomuWorldStreamer: failed to load %s" % p)
			pending.erase(c)

func _instance_ready() -> void:
	var n := 0
	while n < max_instances_per_frame and not _ready_queue.is_empty():
		var c: Vector2i = _ready_queue.pop_front()
		if not pending.has(c):
			continue
		var p: String = pending[c]
		pending.erase(c)
		var ps := ResourceLoader.load_threaded_get(p) as PackedScene
		if ps == null:
			continue
		var inst := ps.instantiate()
		inst.name = "Cell_%d_%d" % [c.x, c.y]
		add_child(inst)
		if offset_cells and inst is Node3D:
			(inst as Node3D).position = cell_origin(c) - global_position
		loaded[c] = inst
		cell_loaded.emit(c, inst)
		n += 1

func unload_cell(c: Vector2i) -> void:
	if not loaded.has(c):
		return
	var n: Node = loaded[c]
	loaded.erase(c)
	if is_instance_valid(n):
		n.queue_free()
	cell_unloaded.emit(c)

func unload_all() -> void:
	for c in loaded.keys():
		unload_cell(c)
	pending.clear()
	_ready_queue.clear()
