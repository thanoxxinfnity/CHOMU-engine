class_name ChomuGOAP
extends RefCounted
## F-50 GOAP planner: A* over a Dictionary world state (blueprint asks for a
## bitset; a Dictionary keeps it GDScript-friendly). Time-sliceable: call
## start() then step(budget) each frame, or plan() for a blocking search.
##
##   var g := ChomuGOAP.new()
##   g.add_action("get_key", {"has_key": false}, {"has_key": true}, 2.0)
##   g.add_action("open_door", {"has_key": true}, {"door_open": true}, 1.0)
##   var plan := g.plan({"has_key": false}, {"door_open": true}) # ["get_key", "open_door"]

enum { IDLE, SEARCHING, FOUND, FAILED }

class GAction:
	extends RefCounted
	var name: String
	var pre: Dictionary
	var eff: Dictionary
	var cost: float
	var cost_fn: Callable ## optional dynamic cost: func(state) -> float

var actions: Array[GAction] = []
var max_expansions := 4000
var status := IDLE
var result: Array[String] = []
var expansions := 0

var _goal: Dictionary
var _open: Array = []      ## [{f, g, key}]
var _nodes := {}           ## key -> {state, g, parent_key, action}
var _closed := {}

func add_action(aname: String, pre: Dictionary, eff: Dictionary, cost := 1.0, cost_fn := Callable()) -> GAction:
	var a := GAction.new()
	a.name = aname
	a.pre = pre
	a.eff = eff
	a.cost = cost
	a.cost_fn = cost_fn
	actions.append(a)
	return a

static func satisfies(state: Dictionary, cond: Dictionary) -> bool:
	for k in cond:
		if state.get(k, null) != cond[k]:
			# a missing boolean key counts as false
			if not (cond[k] is bool and cond[k] == false and not state.has(k)):
				return false
	return true

static func heuristic(state: Dictionary, goal: Dictionary) -> float:
	var h := 0.0
	for k in goal:
		if state.get(k, null) != goal[k]:
			h += 1.0
	return h

static func state_key(state: Dictionary) -> String:
	var keys := state.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s=%s" % [k, state[k]])
	return "|".join(parts)

func plan(start_state: Dictionary, goal: Dictionary) -> Array[String]:
	start(start_state, goal)
	while status == SEARCHING:
		step(1 << 30)
	return result

func start(start_state: Dictionary, goal: Dictionary) -> void:
	_goal = goal
	_open.clear()
	_nodes.clear()
	_closed.clear()
	result = []
	expansions = 0
	var k := state_key(start_state)
	_nodes[k] = {"state": start_state.duplicate(), "g": 0.0, "parent": "", "action": ""}
	_open.append({"f": heuristic(start_state, goal), "g": 0.0, "key": k})
	status = SEARCHING

## Expands up to `budget` nodes. Returns status.
func step(budget: int) -> int:
	if status != SEARCHING:
		return status
	var n := 0
	while n < budget:
		if _open.is_empty() or expansions >= max_expansions:
			status = FAILED
			return status
		# pop lowest f (linear scan is fine for small action sets)
		var bi := 0
		for i in range(1, _open.size()):
			if _open[i]["f"] < _open[bi]["f"]:
				bi = i
		var cur: Dictionary = _open[bi]
		_open.remove_at(bi)
		var key: String = cur["key"]
		if _closed.has(key):
			continue
		_closed[key] = true
		expansions += 1
		n += 1
		var node: Dictionary = _nodes[key]
		var st: Dictionary = node["state"]
		if satisfies(st, _goal):
			_build(key)
			status = FOUND
			return status
		for a in actions:
			if not satisfies(st, a.pre):
				continue
			var ns := st.duplicate()
			for ek in a.eff:
				ns[ek] = a.eff[ek]
			var nk := state_key(ns)
			if _closed.has(nk):
				continue
			var c := a.cost
			if a.cost_fn.is_valid():
				c = float(a.cost_fn.call(st))
			var g: float = float(node["g"]) + c
			if _nodes.has(nk) and float(_nodes[nk]["g"]) <= g:
				continue
			_nodes[nk] = {"state": ns, "g": g, "parent": key, "action": a.name}
			_open.append({"f": g + heuristic(ns, _goal), "g": g, "key": nk})
	return status

func _build(key: String) -> void:
	var out: Array[String] = []
	var k := key
	while k != "":
		var nd: Dictionary = _nodes[k]
		if nd["action"] != "":
			out.push_front(nd["action"])
		k = nd["parent"]
	result = out

func plan_cost(p: Array) -> float:
	var c := 0.0
	for nm in p:
		for a in actions:
			if a.name == nm:
				c += a.cost
	return c
