extends RefCounted

const Impl := preload("res://addons/chomu_systems/debug/diagnostics.gd")

func run(t: Node) -> void:
	var diag := Impl.new()
	t.add_child(diag)
	
	# 1. Test measurement and rolling average
	diag.register_system("test_sys")
	var busy_fn = func():
		var sum: int = 0
		for i in range(1000):
			sum += i
		return sum
	
	for i in range(10):
		diag.measure("test_sys", busy_fn)
	
	var snap := diag.snapshot()
	t.check("F-65 measurement avg > 0", snap["test_sys"].avg_usec > 0, "CPU usage should be recorded")
	t.check("F-65 measurement calls", snap["test_sys"].calls == 10, "Call count should be 10")
	
	# 2. Test restarts and errors
	diag.report_restart("test_sys")
	diag.report_error("test_sys", "Trap 1")
	diag.report_error("test_sys", "Trap 2")
	diag.report_error("test_sys", "Trap 3")
	
	snap = diag.snapshot()
	t.check("F-65 restart count", snap["test_sys"].restarts == 1, "Restart should be incremented")
	t.check("F-65 error count", snap["test_sys"].errors.size() == 3, "Errors should be tracked")
	t.check("F-65 error content", snap["test_sys"].errors[-1] == "Trap 3", "Last error should be Trap 3")
	
	# 3. Test error ring buffer (max 8)
	for i in range(10):
		diag.report_error("test_sys", "Err %d" % i)
	snap = diag.snapshot()
	t.check("F-65 error buffer limit", snap["test_sys"].errors.size() == 8, "Should only keep last 8 errors")
	
	# 4. Test Panel generation
	var panel := diag.build_panel()
	t.add_child(panel)
	t.check("F-65 panel children", panel.get_child_count() == 1, "Panel should have one label for test_sys")
	
	# Cleanup
	panel.queue_free()
	diag.queue_free()
