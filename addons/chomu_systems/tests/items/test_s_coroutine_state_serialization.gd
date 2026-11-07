extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/coroutine_state_serialization.gd")

func run(t: Node) -> void:
	var sched: ChomuCoroutineStateSerialization = Impl.new()
	
	# F-73 add_task returns unique ids and schedules a one-shot delayed task
	var id1: int = sched.add_task(1.0, "on_ready", ["a"])
	var id2: int = sched.add_task(0.5, "on_ready", ["b"])
	t.check("F-73 add_task returns unique ids", id1 != id2, "ids: %d, %d" % [id1, id2])
	
	# F-73 step advances elapsed time and fires due tasks
	var due: Array[Dictionary] = sched.step(0.3)
	t.check("F-73 step 0.3s fires nothing", due.size() == 0, "due size: %d" % due.size())
	due = sched.step(0.3)
	t.check("F-73 step 0.6s total fires id2", due.size() == 1 and due[0]["id"] == id2, "due: %s" % str(due))
	due = sched.step(0.5)
	t.check("F-73 step 1.1s total fires id1", due.size() == 1 and due[0]["id"] == id1, "due: %s" % str(due))
	
	# F-73 add_timer creates repeating timers that fire multiple times
	var tid: int = sched.add_timer(0.4, "on_tick", [], true)
	var fires: int = 0
	due = sched.step(0.4)
	for d in due:
		if d["id"] == tid:
			fires += 1
	due = sched.step(0.4)
	for d in due:
		if d["id"] == tid:
			fires += 1
	t.check("F-73 repeating timer fires twice in 0.8s", fires == 2, "fires: %d" % fires)
	
	# F-73 non-looping timer fires once then done
	var tid2: int = sched.add_timer(0.2, "on_once", [], false)
	due = sched.step(0.2)
	var fired_once: bool = false
	for d in due:
		if d["id"] == tid2:
			fired_once = true
	due = sched.step(0.5)
	var fired_again: bool = false
	for d in due:
		if d["id"] == tid2:
			fired_again = true
	t.check("F-73 non-looping timer fires once only", fired_once and not fired_again, "once: %s, again: %s" % [fired_once, fired_again])
	
	# F-73 cancel removes a pending task
	var id3: int = sched.add_task(5.0, "late", [])
	var cancelled: bool = sched.cancel(id3)
	var still_pending: bool = sched.pending_task_count() > 0
	t.check("F-73 cancel removes task", cancelled and not still_pending, "cancelled: %s, pending: %d" % [cancelled, sched.pending_task_count()])
	
	# F-73 cancel on already-done or missing id returns false
	var cancelled_again: bool = sched.cancel(id1)
	var cancelled_missing: bool = sched.cancel(99999)
	t.check("F-73 cancel returns false for done/missing", not cancelled_again and not cancelled_missing, "again: %s, missing: %s" % [cancelled_again, cancelled_missing])
	
	# F-73 save_state produces a valid dictionary with expected layout
	var state: Dictionary = sched.save_state()
	t.check("F-73 save_state has version/next_id/tasks/timers", state.has("version") and state.has("next_id") and state.has("tasks") and state.has("timers"), "keys: %s" % str(state.keys()))
	t.check("F-73 save_state version is 1", int(state["version"]) == 1, "version: %s" % str(state["version"]))
	
	# F-73 load_state restores state so pending counts match
	var pending_before: int = sched.pending_task_count() + sched.pending_timer_count()
	var sched2: ChomuCoroutineStateSerialization = Impl.new()
	var loaded: bool = sched2.load_state(state)
	t.check("F-73 load_state returns true", loaded, "loaded: %s" % loaded)
	t.check("F-73 loaded state has same pending count", sched2.pending_task_count() + sched2.pending_timer_count() == pending_before, "before: %d, after: %d" % [pending_before, sched2.pending_task_count() + sched2.pending_timer_count()])
	
	# F-73 loaded scheduler behaves identically (deterministic restore)
	# After save: id1/id2 done, tid pending (elapsed 0.8 of 0.4 interval -> next fire at 0.4s more),
	# tid2 done, id3 cancelled. Stepping 0.4s fires tid.
	due = sched2.step(0.4)
	t.check("F-73 restored scheduler fires tid at 0.4s", due.size() == 1 and due[0]["id"] == tid, "due: %s" % str(due))
	
	# F-73 load_state rejects mismatched version
	var bad_state: Dictionary = state.duplicate()
	bad_state["version"] = 99
	var rejected: bool = not sched2.load_state(bad_state)
	t.check("F-73 load_state rejects mismatched version", rejected, "rejected: %s" % rejected)
	
	# F-73 clear resets everything
	sched.clear()
	t.check("F-73 clear empties all queues", sched.pending_task_count() == 0 and sched.pending_timer_count() == 0, "tasks: %d, timers: %d" % [sched.pending_task_count(), sched.pending_timer_count()])
	
	# F-73 seeded RNG is deterministic (seeded RandomNumberGenerator)
	sched.seed(42)
	var r1: float = sched._rng.randf_range(0.0, 1.0)
	sched.seed(42)
	var r2: float = sched._rng.randf_range(0.0, 1.0)
	t.check("F-73 seeded RNG produces deterministic values", r1 == r2, "r1: %f, r2: %f" % [r1, r2])
