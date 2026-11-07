class_name ChomuGridBasedNavmeshPathfinding
extends RefCounted
## Grid-based navmesh / pathfinding (ghost chase) — CHoMU blueprint S-15.
##
## A self-contained, deterministic, mobile-first navigation stack used by ghost
## chase AI (Pac-Man style) and any other grid-locked agent.
##
## Data layout
## -----------
## The world is a uniform 2D grid of cells. Each cell stores a bitmask of
## [enum ChomuGridBasedNavmeshPathfinding.CellFlag] values. The grid is stored
## as a flat [PackedInt32Array] of row-major bitmasks (one int per cell) so it
## is cheap to copy, serialize and keep in RAM on mobile.
##
## Pathfinding
## -----------
## [method find_path] runs a deterministic A* over the grid. Neighbour order is
## fixed (E, W, S, N, then diagonals) and ties are broken by insertion order,
## so identical inputs always produce identical paths. Diagonal moves are only
## allowed when both orthogonal neighbours are free (no corner cutting).
##
## Dynamic obstacles
## -----------------
## [method set_cell_blocked] / [method clear_cell] mutate the grid at runtime.
## Every mutation bumps [member version], which invalidates cached paths so
## agents re-plan when the world changes.
##
## Ghost chase helpers
## -------------------
## [method scatter_targets] returns the four classic corner targets and
## [method chase_target] implements the standard distance-to-target tile rule.
## [method ghost_step] combines those into a one-call "pick next tile" helper
## that respects the current [member mode] (chase / scatter / frightened /
## eaten) and the no-reversal rule.

const CELL_FREE := 0
const CELL_BLOCKED := 1
const CELL_DOOR := 2
const CELL_TUNNEL := 4
const CELL_GHOST_HOUSE := 8
const CELL_ONE_WAY_UP := 16
const CELL_ONE_WAY_DOWN := 32

const MODE_SCATTER := 0
const MODE_CHASE := 1
const MODE_FRIGHTENED := 2
const MODE_EATEN := 3

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAG_DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var width: int = 0
var height: int = 0
var cells: PackedInt32Array = PackedInt32Array()
var version: int = 0
var allow_diagonal: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(p_width: int = 0, p_height: int = 0, p_allow_diagonal: bool = false) -> void:
	width = maxi(0, p_width)
	height = maxi(0, p_height)
	allow_diagonal = p_allow_diagonal
	cells.resize(width * height)
	cells.fill(CELL_FREE)
	rng.randomize()

# ------------------------------------------------------------------ grid API

## Resize the grid, preserving overlapping content when growing.
func resize(p_width: int, p_height: int) -> void:
	var new_cells := PackedInt32Array()
	new_cells.resize(maxi(0, p_width) * maxi(0, p_height))
	new_cells.fill(CELL_FREE)
	var copy_w := mini(width, p_width)
	var copy_h := mini(height, p_height)
	for y in range(copy_h):
		for x in range(copy_w):
			new_cells[y * p_width + x] = cells[y * width + x]
	width = maxi(0, p_width)
	height = maxi(0, p_height)
	cells = new_cells
	version += 1

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height

func idx(x: int, y: int) -> int:
	return y * width + x

func get_cell(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return CELL_BLOCKED
	return cells[idx(x, y)]

func set_cell(x: int, y: int, flags: int) -> void:
	if not in_bounds(x, y):
		return
	cells[idx(x, y)] = flags
	version += 1

func set_cell_blocked(x: int, y: int, blocked: bool = true) -> void:
	if not in_bounds(x, y):
		return
	var i := idx(x, y)
	if blocked:
		cells[i] |= CELL_BLOCKED
	else:
		cells[i] &= ~CELL_BLOCKED
	version += 1

func clear_cell(x: int, y: int) -> void:
	if not in_bounds(x, y):
		return
	cells[idx(x, y)] = CELL_FREE
	version += 1

func is_blocked(x: int, y: int) -> bool:
	return (get_cell(x, y) & CELL_BLOCKED) != 0

func is_walkable(x: int, y: int) -> bool:
	return in_bounds(x, y) and (get_cell(x, y) & CELL_BLOCKED) == 0

## Load a grid from an array of strings. '#' / 'X' = wall, '.' = floor,
## '-' = door, 'o' = tunnel, 'G' = ghost house, '^' = one-way up, 'v' = one-way down.
func load_from_strings(rows: Array[String]) -> void:
	height = rows.size()
	width = 0
	for row in rows:
		width = maxi(width, row.length())
	cells.resize(width * height)
	cells.fill(CELL_FREE)
	for y in range(height):
		var row: String = rows[y]
		for x in range(width):
			var ch := "."
			if x < row.length():
				ch = row[x]
			var flags := CELL_FREE
			match ch:
				"#", "X":
					flags = CELL_BLOCKED
				"-":
					flags = CELL_DOOR
				"o":
					flags = CELL_TUNNEL
				"G":
					flags = CELL_GHOST_HOUSE
				"^":
					flags = CELL_ONE_WAY_UP
				"v":
					flags = CELL_ONE_WAY_DOWN
			cells[idx(x, y)] = flags
	version += 1

func to_strings() -> Array[String]:
	var out: Array[String] = []
	for y in range(height):
		var line := ""
		for x in range(width):
			var f := get_cell(x, y)
			var ch := "."
			if (f & CELL_BLOCKED) != 0:
				ch = "#"
			elif (f & CELL_DOOR) != 0:
				ch = "-"
			elif (f & CELL_TUNNEL) != 0:
				ch = "o"
			elif (f & CELL_GHOST_HOUSE) != 0:
				ch = "G"
			elif (f & CELL_ONE_WAY_UP) != 0:
				ch = "^"
			elif (f & CELL_ONE_WAY_DOWN) != 0:
				ch = "v"
			line += ch
		out.append(line)
	return out

# ------------------------------------------------------------------ pathfind

## Deterministic A*. Returns an array of Vector2i from [param start] to [param goal]
## (inclusive). Empty array when unreachable. [param max_nodes] caps work per call.
func find_path(start: Vector2i, goal: Vector2i, max_nodes: int = 20000) -> Array[Vector2i]:
	if not in_bounds(start.x, start.y) or not in_bounds(goal.x, goal.y):
		return []
	if is_blocked(start.x, start.y) or is_blocked(goal.x, goal.y):
		return []
	if start == goal:
		return [start]

	var start_i := idx(start.x, start.y)
	var goal_i := idx(goal.x, goal.y)
	var g_score := PackedFloat32Array()
	var came_from := PackedInt32Array()
	var closed := PackedByteArray()
	var in_open := PackedByteArray()
	g_score.resize(cells.size())
	came_from.resize(cells.size())
	closed.resize(cells.size())
	in_open.resize(cells.size())
	g_score.fill(INF)
	came_from.fill(-1)
	closed.fill(0)
	in_open.fill(0)
	g_score[start_i] = 0.0

	# Binary min-heap of (f, node) kept as two parallel arrays.
	var heap_f: Array[float] = []
	var heap_n: Array[int] = []
	heap_f.append(0.0)
	heap_n.append(start_i)
	in_open[start_i] = 1

	var expanded := 0
	while heap_n.size() > 0:
		var current_i := _heap_pop(heap_f, heap_n)
		if closed[current_i] == 1:
			continue
		closed[current_i] = 1
		in_open[current_i] = 0
		expanded += 1
		if expanded > max_nodes:
			return []
		if current_i == goal_i:
			return _reconstruct(came_from, current_i, start_i)

		var cx := current_i % width
		var cy := current_i / width
		for d in DIRS:
			var nx = cx + d.x
			var ny = cy + d.y
			if not _can_step(cx, cy, nx, ny, d):
				continue
			var ni := idx(nx, ny)
			if closed[ni] == 1:
				continue
			var tentative: float = g_score[current_i] + 1.0
			if tentative < g_score[ni]:
				g_score[ni] = tentative
				came_from[ni] = current_i
				_heap_push(heap_f, heap_n, tentative + _heuristic(nx, ny, goal.x, goal.y), ni)
				in_open[ni] = 1
		if allow_diagonal:
			for d in DIAG_DIRS:
				var nx = cx + d.x
				var ny = cy + d.y
				if not _can_step(cx, cy, nx, ny, d):
					continue
				# No corner cutting: both orthogonal neighbours must be free.
				if is_blocked(cx + d.x, cy) or is_blocked(cx, cy + d.y):
					continue
				var ni := idx(nx, ny)
				if closed[ni] == 1:
					continue
				var tentative: float = g_score[current_i] + 1.41421356237
				if tentative < g_score[ni]:
					g_score[ni] = tentative
					came_from[ni] = current_i
					_heap_push(heap_f, heap_n, tentative + _heuristic(nx, ny, goal.x, goal.y), ni)
					in_open[ni] = 1
	return []

func _can_step(from_x: int, from_y: int, to_x: int, to_y: int, d: Vector2i) -> bool:
	if not in_bounds(to_x, to_y):
		return false
	if is_blocked(to_x, to_y):
		return false
	var from_flags := get_cell(from_x, from_y)
	var to_flags := get_cell(to_x, to_y)
	# One-way tiles only permit their configured direction.
	if (from_flags & CELL_ONE_WAY_UP) != 0 and not (d.y < 0):
		return false
	if (from_flags & CELL_ONE_WAY_DOWN) != 0 and not (d.y > 0):
		return false
	if (to_flags & CELL_ONE_WAY_UP) != 0 and not (d.y < 0):
		return false
	if (to_flags & CELL_ONE_WAY_DOWN) != 0 and not (d.y > 0):
		return false
	return true

func _heuristic(ax: int, ay: int, bx: int, by: int) -> float:
	var dx := absf(float(ax - bx))
	var dy := absf(float(ay - by))
	if allow_diagonal:
		return dx + dy - 1.41421356237 * mini(dx, dy)
	return dx + dy

func _reconstruct(came_from: PackedInt32Array, current_i: int, start_i: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var node := current_i
	while node != -1:
		path.append(Vector2i(node % width, node / width))
		if node == start_i:
			break
		node = came_from[node]
	path.reverse()
	return path

func _heap_push(heap_f: Array[float], heap_n: Array[int], f: float, node: int) -> void:
	heap_f.append(f)
	heap_n.append(node)
	var i := heap_f.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap_f[parent] <= heap_f[i]:
			break
		var tf := heap_f[parent]
		heap_f[parent] = heap_f[i]
		heap_f[i] = tf
		var tn := heap_n[parent]
		heap_n[parent] = heap_n[i]
		heap_n[i] = tn
		i = parent

func _heap_pop(heap_f: Array[float], heap_n: Array[int]) -> int:
	var top := heap_n[0]
	var last_f := heap_f[heap_f.size() - 1]
	var last_n := heap_n[heap_n.size() - 1]
	heap_f.remove_at(heap_f.size() - 1)
	heap_n.remove_at(heap_n.size() - 1)
	if heap_f.size() > 0:
		heap_f[0] = last_f
		heap_n[0] = last_n
		var i := 0
		var size := heap_f.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var smallest := i
			if l < size and heap_f[l] < heap_f[smallest]:
				smallest = l
			if r < size and heap_f[r] < heap_f[smallest]:
				smallest = r
			if smallest == i:
				break
			var tf := heap_f[smallest]
			heap_f[smallest] = heap_f[i]
			heap_f[i] = tf
			var tn := heap_n[smallest]
			heap_n[smallest] = heap_n[i]
			heap_n[i] = tn
			i = smallest
	return top

# ------------------------------------------------------------------ flow field

## Breadth-first distance field from [param sources] over walkable cells.
## Blocked and unreachable cells get -1. Used for "flee the player" behaviour.
func compute_distance_field(sources: Array[Vector2i]) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(cells.size())
	dist.fill(-1)
	var queue: Array[int] = []
	for s in sources:
		if in_bounds(s.x, s.y) and not is_blocked(s.x, s.y):
			var si := idx(s.x, s.y)
			if dist[si] == -1:
				dist[si] = 0
				queue.append(si)
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		var cx := cur % width
		var cy := cur / width
		for d in DIRS:
			var nx = cx + d.x
			var ny = cy + d.y
			if not is_walkable(nx, ny):
				continue
			var ni := idx(nx, ny)
			if dist[ni] == -1:
				dist[ni] = dist[cur] + 1
				queue.append(ni)
	return dist

# ------------------------------------------------------------------ ghost AI

## Classic scatter corners: top-left, top-right, bottom-left, bottom-right.
func scatter_targets() -> Array[Vector2i]:
	return [
		Vector2i(0, 0),
		Vector2i(width - 1, 0),
		Vector2i(0, height - 1),
		Vector2i(width - 1, height - 1),
	]

## Standard chase rule: target a tile [param lookahead] cells ahead of the player.
func chase_target(player: Vector2i, player_dir: Vector2i, lookahead: int = 4) -> Vector2i:
	return Vector2i(player.x + player_dir.x * lookahead, player.y + player_dir.y * lookahead)

## Pick the next tile for a ghost. Honours the no-reversal rule, the current
## [param mode] and (in frightened mode) a seeded random choice.
func ghost_step(ghost: Vector2i, prev: Vector2i, player: Vector2i, player_dir: Vector2i, mode: int, ghost_index: int = 0) -> Vector2i:
	var target := player
	match mode:
		MODE_SCATTER:
			var corners := scatter_targets()
			target = corners[ghost_index % corners.size()]
		MODE_CHASE:
			target = chase_target(player, player_dir)
		MODE_EATEN:
			target = Vector2i(width / 2, height / 2)
		MODE_FRIGHTENED:
			var options: Array[Vector2i] = []
			for d in DIRS:
				var nx = ghost.x + d.x
				var ny = ghost.y + d.y
				if not is_walkable(nx, ny):
					continue
				if Vector2i(nx, ny) == prev:
					continue
				options.append(Vector2i(nx, ny))
			if options.is_empty():
				return prev
			return options[rng.randi_range(0, options.size() - 1)]

	var best := ghost
	var best_dist := INF
	var best_is_reverse := false
	for d in DIRS:
		var nx = ghost.x + d.x
		var ny = ghost.y + d.y
		if not is_walkable(nx, ny):
			continue
		var candidate := Vector2i(nx, ny)
		var is_reverse := candidate == prev
		var dist := _heuristic(nx, ny, target.x, target.y)
		if is_reverse and not best_is_reverse:
			continue
		if not is_reverse and best_is_reverse:
			best = candidate
			best_dist = dist
			best_is_reverse = false
			continue
		if dist < best_dist:
			best = candidate
			best_dist = dist
			best_is_reverse = is_reverse
	return best

# ------------------------------------------------------------------ state IO

func save_state() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"allow_diagonal": allow_diagonal,
		"version": version,
		"cells": cells.duplicate(),
	}

func load_state(data: Dictionary) -> bool:
	if not data.has("width") or not data.has("height") or not data.has("cells"):
		return false
	var w := int(data.get("width", 0))
	var h := int(data.get("height", 0))
	if w <= 0 or h <= 0:
		return false
	var raw: Variant = data["cells"]
	if not (raw is PackedInt32Array) and not (raw is Array):
		return false
	var loaded := PackedInt32Array()
	if raw is PackedInt32Array:
		loaded = (raw as PackedInt32Array).duplicate()
	else:
		for v in raw:
			loaded.append(int(v))
	if loaded.size() != w * h:
		return false
	width = w
	height = h
	allow_diagonal = bool(data.get("allow_diagonal", false))
	version = int(data.get("version", 0))
	cells = loaded
	return true
