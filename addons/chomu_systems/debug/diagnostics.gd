extends Node
class_name ChomuDiagnostics

## Diagnostics panel for addon systems/plugins.
## Tracks CPU usage, restarts, and trap reasons per registered system.

var _systems: Dictionary = {} # name -> {avg_usec: float, max_usec: int, calls: int, restarts: int, errors: Array[String]}
var _monitors: Array[String] = []

func register_system(p_name: String, _node_or_callable: Variant = null) -> void:
	if _systems.has(p_name):
		return
	
	_systems[p_name] = {
		"avg_usec": 0.0,
		"max_usec": 0,
		"calls": 0,
		"restarts": 0,
		"errors": []
	}
	
	var monitor_name := "chomu/%s_usec" % p_name
	# In Godot 4, Performance.add_custom_monitor(name, callable)
	# We provide a lambda that returns the current avg_usec for that system.
	var getter = func() -> float:
		if _systems.has(p_name):
			return _systems[p_name].avg_usec
		return 0.0
	
	Performance.add_custom_monitor(monitor_name, getter)
	_monitors.append(monitor_name)

func measure(p_name: String, p_fn: Callable) -> Variant:
	if not _systems.has(p_name):
		return p_fn.call()
	
	var start := Time.get_ticks_usec()
	var result = p_fn.call()
	var duration := Time.get_ticks_usec() - start
	
	var stats = _systems[p_name]
	stats.calls += 1
	stats.max_usec = max(stats.max_usec, duration)
	# Rolling average: alpha = 0.1
	stats.avg_usec = (stats.avg_usec * 0.9) + (float(duration) * 0.1)
	
	return result

func report_restart(p_name: String) -> void:
	if _systems.has(p_name):
		_systems[p_name].restarts += 1

func report_error(p_name: String, p_reason: String) -> void:
	if _systems.has(p_name):
		var errs = _systems[p_name].errors
		errs.append(p_reason)
		if errs.size() > 8:
			errs.remove_at(0)

func snapshot() -> Dictionary:
	var snap := {}
	var global_mem := Performance.get_monitor(Performance.MEMORY_STATIC)
	for s_name in _systems:
		var s = _systems[s_name]
		snap[s_name] = {
			"avg_usec": s.avg_usec,
			"max_usec": s.max_usec,
			"calls": s.calls,
			"restarts": s.restarts,
			"errors": s.errors.duplicate(),
			"static_mem": global_mem
		}
	return snap

func build_panel() -> Control:
	var vbox := VBoxContainer.new()
	vbox.name = "ChomuDiagnosticsPanel"
	refresh_panel(vbox)
	return vbox

func refresh_panel(p_panel: Control) -> void:
	if not p_panel is VBoxContainer:
		return
	
	for child in p_panel.get_children():
		child.queue_free()
	
	var snap := snapshot()
	for s_name in snap:
		var data = snap[s_name]
		var label := Label.new()
		label.text = "[%s] Avg: %.2fus Max: %dus Calls: %d Restarts: %d Errs: %d" % [
			s_name, data.avg_usec, data.max_usec, data.calls, data.restarts, data.errors.size()
		]
		if data.errors.size() > 0:
			label.text += " (Last: %s)" % data.errors[-1]
		p_panel.add_child(label)

func _exit_tree() -> void:
	for m in _monitors:
		Performance.remove_custom_monitor(m)
