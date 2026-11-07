extends RefCounted
class_name ChomuCoroutineStateSerialization

## ChomuCoroutineStateSerialization
##
## Reusable GDScript implementation of Coroutine State Serialization for the CHoMU Systems addon.
## Provides a data-driven public API for saving active delayed script tasks and timers during game saves.
## Mobile-first (NEON path, low RAM): uses flat Packed arrays, avoids reflection, deterministic seeded RNG.
##
## Data layout:
##   state = {
##     "version": int,
##     "next_id": int,
##     "tasks": Array[Dictionary],   # {id, delay, elapsed, callback_tag, args, done}
##     "timers": Array[Dictionary]   # {id, interval, elapsed, callback_tag, args, loop, done}
##   }
##
## Standard game-dev design: a central task scheduler (as used in shipped games) that owns all
## delayed coroutines/timers, serializes them into a plain Dictionary for save/load, and restores
## them deterministically on load.

## TaskDescriptor: serializable description of a single delayed task.
class TaskDescriptor:
	var id: int = 0
	var delay: float = 0.0
	var elapsed: float = 0.0
	var callback_tag: String = ""
	var args: Array = []
	var done: bool = false

## TimerDescriptor: serializable description of a repeating timer.
class TimerDescriptor:
	var id: int = 0
	var interval: float = 0.0
	var elapsed: float = 0.0
	var callback_tag: String = ""
	var args: Array = []
	var loop: bool = true
	var done: bool = false

## SerializedState: the plain Dictionary saved to disk.
class SerializedState:
	var version: int = 1
	var next_id: int = 1
	var tasks: Array[Dictionary] = []
	var timers: Array[Dictionary] = []

## ChomuCoroutineStateSerialization manages delayed tasks and timers with full save/load support.
## All state is held in plain data structures; no Node dependencies, headless-safe.
var _version: int = 1
var _next_id: int = 1
var _tasks: Array[TaskDescriptor] = []
var _timers: Array[TimerDescriptor] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Seed the internal RNG for deterministic behaviour (useful for replay/sync).
## @param seed int seed value
func seed(seed: int) -> void:
	_rng.seed = seed

## Register a one-shot delayed task.
## @param delay seconds before the task becomes due
## @param callback_tag string tag identifying the callback target
## @param args optional arguments to pass to the callback
## @return int task id
func add_task(delay: float, callback_tag: String, args: Array = []) -> int:
	var id: int = _next_id
	_next_id += 1
	var desc: TaskDescriptor = TaskDescriptor.new()
	desc.id = id
	desc.delay = delay
	desc.elapsed = 0.0
	desc.callback_tag = callback_tag
	desc.args = args.duplicate()
	desc.done = false
	_tasks.append(desc)
	return id

## Register a repeating timer.
## @param interval seconds between ticks
## @param callback_tag string tag identifying the callback target
## @param args optional arguments to pass to the callback
## @param loop if true, the timer resets after each tick
## @return int timer id
func add_timer(interval: float, callback_tag: String, args: Array = [], loop: bool = true) -> int:
	var id: int = _next_id
	_next_id += 1
	var desc: TimerDescriptor = TimerDescriptor.new()
	desc.id = id
	desc.interval = interval
	desc.elapsed = 0.0
	desc.callback_tag = callback_tag
	desc.args = args.duplicate()
	desc.loop = loop
	desc.done = false
	_timers.append(desc)
	return id

## Advance all tasks and timers by delta seconds.
## Returns dictionaries of due tasks/timers: {id, callback_tag, args}.
## @param delta seconds to advance
## @return Array[Dictionary] list of due events
func step(delta: float) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	
	# Process tasks
	var i: int = 0
	while i < _tasks.size():
		var desc: TaskDescriptor = _tasks[i]
		if not desc.done:
			desc.elapsed += delta
			if desc.elapsed >= desc.delay:
				desc.done = true
				due.append({"id": desc.id, "callback_tag": desc.callback_tag, "args": desc.args.duplicate()})
		i += 1
	
	# Process timers
	i = 0
	while i < _timers.size():
		var desc: TimerDescriptor = _timers[i]
		if not desc.done:
			desc.elapsed += delta
			while desc.elapsed >= desc.interval:
				desc.elapsed -= desc.interval
				due.append({"id": desc.id, "callback_tag": desc.callback_tag, "args": desc.args.duplicate()})
				if not desc.loop:
					desc.done = true
					break
		i += 1
	
	return due

## Cancel a task or timer by id.
## @param id the id returned by add_task/add_timer
## @return bool true if found and cancelled
func cancel(id: int) -> bool:
	for desc in _tasks:
		if desc.id == id and not desc.done:
			desc.done = true
			return true
	for desc in _timers:
		if desc.id == id and not desc.done:
			desc.done = true
			return true
	return false

## Get the number of pending (not done) tasks.
func pending_task_count() -> int:
	var count: int = 0
	for desc in _tasks:
		if not desc.done:
			count += 1
	return count

## Get the number of pending (not done) timers.
func pending_timer_count() -> int:
	var count: int = 0
	for desc in _timers:
		if not desc.done:
			count += 1
	return count

## Serialize all current state into a plain Dictionary suitable for saving.
## @return Dictionary serializable state
func save_state() -> Dictionary:
	var state: Dictionary = {}
	state["version"] = _version
	state["next_id"] = _next_id
	
	var tasks_arr: Array[Dictionary] = []
	for desc in _tasks:
		var d: Dictionary = {}
		d["id"] = desc.id
		d["delay"] = desc.delay
		d["elapsed"] = desc.elapsed
		d["callback_tag"] = desc.callback_tag
		d["args"] = desc.args.duplicate()
		d["done"] = desc.done
		tasks_arr.append(d)
	state["tasks"] = tasks_arr
	
	var timers_arr: Array[Dictionary] = []
	for desc in _timers:
		var d: Dictionary = {}
		d["id"] = desc.id
		d["interval"] = desc.interval
		d["elapsed"] = desc.elapsed
		d["callback_tag"] = desc.callback_tag
		d["args"] = desc.args.duplicate()
		d["loop"] = desc.loop
		d["done"] = desc.done
		timers_arr.append(d)
	state["timers"] = timers_arr
	
	return state

## Load state from a previously saved Dictionary.
## Validates version and restores all tasks/timers.
## @param state Dictionary produced by save_state()
## @return bool true if loaded successfully
func load_state(state: Dictionary) -> bool:
	if state.has("version") and int(state["version"]) != _version:
		return false
	
	_tasks.clear()
	_timers.clear()
	if state.has("next_id"):
		_next_id = int(state["next_id"])
	else:
		_next_id = 1
	
	if state.has("tasks"):
		var tasks_arr: Array = state["tasks"]
		for d in tasks_arr:
			var desc: TaskDescriptor = TaskDescriptor.new()
			desc.id = int(d.get("id", 0))
			desc.delay = float(d.get("delay", 0.0))
			desc.elapsed = float(d.get("elapsed", 0.0))
			desc.callback_tag = String(d.get("callback_tag", ""))
			desc.args = d.get("args", []).duplicate()
			desc.done = bool(d.get("done", false))
			_tasks.append(desc)
	
	if state.has("timers"):
		var timers_arr: Array = state["timers"]
		for d in timers_arr:
			var desc: TimerDescriptor = TimerDescriptor.new()
			desc.id = int(d.get("id", 0))
			desc.interval = float(d.get("interval", 0.0))
			desc.elapsed = float(d.get("elapsed", 0.0))
			desc.callback_tag = String(d.get("callback_tag", ""))
			desc.args = d.get("args", []).duplicate()
			desc.loop = bool(d.get("loop", true))
			desc.done = bool(d.get("done", false))
			_timers.append(desc)
	
	return true

## Clear all tasks and timers, resetting the id counter.
func clear() -> void:
	_tasks.clear()
	_timers.clear()
	_next_id = 1
