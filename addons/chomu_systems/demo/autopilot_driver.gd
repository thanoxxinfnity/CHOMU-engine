extends Node
## Runs before ChomuReplay each physics tick so the recorder sees autopilot input.
var demo: Node

func _physics_process(delta: float) -> void:
	if demo:
		demo.drive_autopilot(delta)
