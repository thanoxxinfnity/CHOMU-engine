class_name ChomuBuoyancy
extends Node3D
## F-57 (part 3) Buoyancy. Child of a RigidBody3D. Each probe point (local
## offsets) samples ChomuWater.height_at; submerged probes push up with
## Archimedes force for their share of `volume`, and add linear + angular
## water drag so bodies settle instead of bouncing forever.

@export var water: ChomuWater
@export var probes: Array[Vector3] = [Vector3(0.5, -0.4, 0.5), Vector3(-0.5, -0.4, 0.5), Vector3(0.5, -0.4, -0.5), Vector3(-0.5, -0.4, -0.5)]
@export var volume := 1.0             ## m^3 displaced when fully under
@export var probe_depth := 0.8        ## depth at which a probe counts as fully submerged
@export var linear_drag := 6.0
@export var angular_drag := 3.0

var body: RigidBody3D
var submerged := 0.0                 ## 0..1 fraction of probes under water

func _ready() -> void:
	body = get_parent() as RigidBody3D
	if body == null:
		push_warning("ChomuBuoyancy must be a child of a RigidBody3D")

func _physics_process(_delta: float) -> void:
	var w := water if water else ChomuWater.instance
	if body == null or w == null:
		return
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var per := volume / maxf(1.0, float(probes.size()))
	var under := 0.0
	for p in probes:
		var wp := body.global_transform * p
		var depth := w.height_at(wp.x, wp.z) - wp.y
		if depth <= 0.0:
			continue
		var f := clampf(depth / probe_depth, 0.0, 1.0)
		under += f
		var up := Vector3.UP * w.density * g * per * f
		body.apply_force(up, wp - body.global_position)
	submerged = under / maxf(1.0, float(probes.size()))
	if submerged > 0.0:
		body.apply_central_force(-body.linear_velocity * linear_drag * body.mass * submerged)
		body.apply_torque(-body.angular_velocity * angular_drag * body.mass * submerged)
