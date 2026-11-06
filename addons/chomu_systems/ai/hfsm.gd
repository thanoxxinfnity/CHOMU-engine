class_name ChomuHFSM
extends Node
## F-49 Hierarchical state machine. States nest; transitions on an outer state
## are checked before inner ones, so "Alert -> Flee" overrides any sub-state.
## Each state can carry a behaviour tree (ChomuBT) as its leaf behaviour,
## giving the HFSM (mode) + utility/BT (action) hybrid from the blueprint.
##
##   var fsm := ChomuHFSM.new()
##   var idle := fsm.add_state("Idle")
##   var hunt := fsm.add_state("Hunt")
##   var search := fsm.add_state("Search", hunt)
##   fsm.add_transition("Idle", "Hunt", func(): return sees_player)
##   fsm.start("Idle")

signal state_entered(path: String)
signal state_exited(path: String)

class HState:
	extends RefCounted
	var name: String
	var parent: HState
	var children: Array[HState] = []
	var initial: HState
	var on_enter: Callable
	var on_exit: Callable
	var on_update: Callable    ## func(delta)
	var behavior: ChomuBT       ## optional BT ticked while this is the leaf
	var transitions: Array = [] ## [{to: HState, cond: Callable}]
	func path() -> String:
		return name if parent == null else parent.path() + "/" + name

@export var auto_update := true
var states := {}        ## name -> HState
var active: Array[HState] = [] ## root .. leaf
var blackboard := {}
var history: Array[String] = []  ## last entered leaf paths (decision timeline-lite)
var _started := false

func _exit_tree() -> void:
	clear()

## Breaks the parent/child reference cycles so states are freed.
func clear() -> void:
	for s in states.values():
		var hs: HState = s
		hs.parent = null
		hs.initial = null
		hs.children.clear()
		hs.transitions.clear()
		hs.behavior = null
	states.clear()
	active.clear()
	_started = false

func add_state(sname: String, parent: HState = null, on_enter := Callable(), on_exit := Callable(), on_update := Callable()) -> HState:
	var s := HState.new()
	s.name = sname
	s.parent = parent
	s.on_enter = on_enter
	s.on_exit = on_exit
	s.on_update = on_update
	if parent:
		parent.children.append(s)
		if parent.initial == null:
			parent.initial = s
	states[sname] = s
	return s

func add_transition(from: String, to: String, cond: Callable) -> void:
	(states[from] as HState).transitions.append({"to": states[to], "cond": cond})

func set_behavior(sname: String, bt: ChomuBT) -> void:
	(states[sname] as HState).behavior = bt

func start(sname: String) -> void:
	_started = true
	active.clear()
	_enter_down(states[sname])

func leaf() -> HState:
	return active.back() if not active.is_empty() else null

func current_path() -> String:
	var l := leaf()
	return l.path() if l else ""

func is_in(sname: String) -> bool:
	for s in active:
		if s.name == sname:
			return true
	return false

func change_to(sname: String) -> void:
	_transition(states[sname])

func _physics_process(delta: float) -> void:
	if auto_update and _started:
		update(delta)

func update(delta: float) -> void:
	# outermost first
	for s in active.duplicate():
		for t in s.transitions:
			var c: Callable = t["cond"]
			if c.is_valid() and c.call():
				_transition(t["to"])
				return
	for s in active:
		if s.on_update.is_valid():
			s.on_update.call(delta)
	var l := leaf()
	if l and l.behavior:
		l.behavior.tick(blackboard, delta)

func _transition(target: HState) -> void:
	# common ancestor
	var chain: Array[HState] = []
	var p := target
	while p:
		chain.push_front(p)
		p = p.parent
	var keep := 0
	while keep < active.size() and keep < chain.size() and active[keep] == chain[keep]:
		keep += 1
	if keep == chain.size() and keep == active.size():
		keep -= 1 # self-transition: re-enter the leaf
	while active.size() > keep:
		var s: HState = active.pop_back()
		if s.on_exit.is_valid():
			s.on_exit.call()
		state_exited.emit(s.path())
	for i in range(keep, chain.size() - 1):
		_enter_one(chain[i])
	_enter_down(target)

func _enter_one(s: HState) -> void:
	active.append(s)
	if s.on_enter.is_valid():
		s.on_enter.call()
	state_entered.emit(s.path())

func _enter_down(s: HState) -> void:
	var c := s
	while c:
		_enter_one(c)
		c = c.initial
	history.append(current_path())
	if history.size() > 64:
		history.remove_at(0)
