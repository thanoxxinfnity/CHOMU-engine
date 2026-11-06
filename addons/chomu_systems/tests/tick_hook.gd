extends Node
## Calls `cb(delta)` every physics tick at this node's process_physics_priority.
var cb: Callable

func _physics_process(delta: float) -> void:
	if cb.is_valid():
		cb.call(delta)
