class_name ChomuBT
extends RefCounted
## F-49 Small behaviour tree with a utility selector.
##
##   var bt := ChomuBT.new(ChomuBT.selector([
##       ChomuBT.sequence([ChomuBT.condition(func(bb): return bb.sees), ChomuBT.action(chase)]),
##       ChomuBT.action(wander)]))
##   bt.tick(blackboard, delta)
## Actions/conditions receive (blackboard: Dictionary, delta: float) - conditions
## may take only the blackboard. Actions return SUCCESS / FAILURE / RUNNING.

enum { SUCCESS, FAILURE, RUNNING }

class BTNode:
	extends RefCounted
	var label := ""
	func tick(_bb: Dictionary, _dt: float) -> int:
		return FAILURE
	func reset() -> void:
		pass

class Sequence:
	extends BTNode
	var kids: Array = []
	var _i := 0
	func tick(bb: Dictionary, dt: float) -> int:
		while _i < kids.size():
			var r: int = kids[_i].tick(bb, dt)
			if r == RUNNING:
				return RUNNING
			if r == FAILURE:
				_i = 0
				return FAILURE
			_i += 1
		_i = 0
		return SUCCESS
	func reset() -> void:
		_i = 0
		for k in kids:
			k.reset()

class Selector:
	extends BTNode
	var kids: Array = []
	func tick(bb: Dictionary, dt: float) -> int:
		for k in kids:
			var r: int = k.tick(bb, dt)
			if r != FAILURE:
				return r
		return FAILURE

## Picks the child with the highest score (utility AI); ties keep the first.
class UtilitySelector:
	extends BTNode
	var kids: Array = []
	var scores: Array = [] ## Callable(bb) -> float, parallel to kids
	var last_choice := -1
	func tick(bb: Dictionary, dt: float) -> int:
		var best := -1
		var best_s := -INF
		for i in kids.size():
			var sc: float = scores[i].call(bb)
			if sc > best_s:
				best_s = sc
				best = i
		if best < 0:
			return FAILURE
		if best != last_choice and last_choice >= 0:
			kids[last_choice].reset()
		last_choice = best
		return kids[best].tick(bb, dt)

class Inverter:
	extends BTNode
	var child: BTNode
	func tick(bb: Dictionary, dt: float) -> int:
		var r := child.tick(bb, dt)
		if r == SUCCESS:
			return FAILURE
		if r == FAILURE:
			return SUCCESS
		return RUNNING

class Condition:
	extends BTNode
	var fn: Callable
	func tick(bb: Dictionary, _dt: float) -> int:
		return SUCCESS if fn.call(bb) else FAILURE

class Action:
	extends BTNode
	var fn: Callable
	func tick(bb: Dictionary, dt: float) -> int:
		return int(fn.call(bb, dt))

class Cooldown:
	extends BTNode
	var child: BTNode
	var seconds := 1.0
	var _left := 0.0
	func tick(bb: Dictionary, dt: float) -> int:
		_left -= dt
		if _left > 0.0:
			return FAILURE
		var r := child.tick(bb, dt)
		if r == SUCCESS:
			_left = seconds
		return r

var root: BTNode
var last_status := FAILURE

func _init(r: BTNode = null) -> void:
	root = r

func tick(bb: Dictionary, dt: float = 0.0) -> int:
	if root == null:
		return FAILURE
	last_status = root.tick(bb, dt)
	return last_status

static func sequence(kids: Array, lbl := "") -> Sequence:
	var n := Sequence.new()
	n.kids = kids
	n.label = lbl
	return n

static func selector(kids: Array, lbl := "") -> Selector:
	var n := Selector.new()
	n.kids = kids
	n.label = lbl
	return n

static func utility(kids: Array, scores: Array, lbl := "") -> UtilitySelector:
	var n := UtilitySelector.new()
	n.kids = kids
	n.scores = scores
	n.label = lbl
	return n

static func invert(child: BTNode) -> Inverter:
	var n := Inverter.new()
	n.child = child
	return n

static func condition(fn: Callable, lbl := "") -> Condition:
	var n := Condition.new()
	n.fn = fn
	n.label = lbl
	return n

static func action(fn: Callable, lbl := "") -> Action:
	var n := Action.new()
	n.fn = fn
	n.label = lbl
	return n

static func cooldown(child: BTNode, seconds: float) -> Cooldown:
	var n := Cooldown.new()
	n.child = child
	n.seconds = seconds
	return n
