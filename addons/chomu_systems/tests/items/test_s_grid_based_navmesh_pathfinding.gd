extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/grid_based_navmesh_pathfinding.gd")

func run(t: Node) -> void:
	# ---------------------------------------------------------------- layout
	var grid := Impl.new(5, 5, false)
	grid.load_from_strings([
		"#####",
		"#...#",
		"#.#.#",
		"#...#",
		"#####",
	])
	t.check("S-15 layout parses walls and floor", grid.width == 5 and grid.height == 5, "size mismatch")
	t.check("S-15 wall cell flagged blocked", grid.is_blocked(0, 0), "corner should be wall")
	t.check("S-15 interior cell walkable", grid.is_walkable(1, 1), "interior should be free")

	# ---------------------------------------------------------------- pathing
	var path := grid.find_path(Vector2i(1, 1), Vector2i(3, 3))
	t.check("S-15 A* finds path around pillar", path.size() > 0 and path[0] == Vector2i(1, 1) and path[path.size() - 1] == Vector2i(3, 3), "path endpoints wrong")
	var no_corner_cut := true
	for p in path:
		if p == Vector2i(2, 2):
			no_corner_cut = false
	t.check("S-15 path never cuts the blocked pillar", no_corner_cut, "path stepped onto wall")

	var blocked := grid.find_path(Vector2i(1, 1), Vector2i(0, 0))
	t.check("S-15 unreachable goal returns empty path", blocked.is_empty(), "should not path into wall")

	# ------------------------------------------------------------- determinism
	var a := grid.find_path(Vector2i(1, 1), Vector2i(3, 1))
	var b := grid.find_path(Vector2i(1, 1), Vector2i(3, 1))
	t.check("S-15 A* is deterministic", a == b, "two identical queries diverged")

	# -------------------------------------------------------- dynamic obstacle
	grid.set_cell_blocked(2, 1, true)
	var rerouted := grid.find_path(Vector2i(1, 1), Vector2i(3, 1))
	t.check("S-15 dynamic obstacle forces detour", rerouted.size() > a.size(), "path did not grow after blocking")
	t.check("S-15 version bumps on mutation", grid.version > 0, "version did not change")
	grid.set_cell_blocked(2, 1, false)

	# ------------------------------------------------------------- flow field
	var field := grid.compute_distance_field([Vector2i(1, 1)])
	t.check("S-15 distance field marks source zero", field[grid.idx(1, 1)] == 0, "source distance wrong")
	t.check("S-15 distance field reaches neighbour", field[grid.idx(2, 1)] == 1, "neighbour distance wrong")
	t.check("S-15 distance field leaves walls at -1", field[grid.idx(0, 0)] == -1, "wall should be -1")

	# -------------------------------------------------------------- ghost AI
	var chase := grid.ghost_step(Vector2i(1, 1), Vector2i(1, 2), Vector2i(3, 1), Vector2i(1, 0), Impl.MODE_CHASE)
	t.check("S-15 ghost chase moves toward player", chase == Vector2i(2, 1), "ghost did not advance toward player")
	var no_reverse := grid.ghost_step(Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 0), Impl.MODE_CHASE)
	t.check("S-15 ghost never reverses", no_reverse != Vector2i(2, 1), "ghost reversed direction")
	var corners := grid.scatter_targets()
	t.check("S-15 scatter corners are the four map corners", corners.size() == 4 and corners[0] == Vector2i(0, 0) and corners[3] == Vector2i(4, 4), "corner set wrong")

	# ------------------------------------------------------------- save/load
	var saved := grid.save_state()
	var clone := Impl.new(1, 1, false)
	t.check("S-15 load_state accepts saved dictionary", clone.load_state(saved), "load_state returned false")
	t.check("S-15 round trip preserves grid", clone.to_strings() == grid.to_strings(), "grid text differs after round trip")
	t.check("S-15 round trip preserves pathing", clone.find_path(Vector2i(1, 1), Vector2i(3, 3)) == grid.find_path(Vector2i(1, 1), Vector2i(3, 3)), "path differs after round trip")
	t.check("S-15 load_state rejects malformed data", not clone.load_state({"width": 3}), "bad payload accepted")
