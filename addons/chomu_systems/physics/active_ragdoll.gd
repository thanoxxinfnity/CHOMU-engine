class_name ChomuActiveRagdoll
extends Node
## F-54 Active ragdoll helper around PhysicalBoneSimulator3D.
## Physical bones are steered toward a target pose with PD "motors"
## (velocity-based, so it works with Godot Physics and Jolt). The target pose is
## read from `target_skeleton` (e.g. a hidden animated copy) or, if none, from a
## snapshot of the pose taken when simulation starts.
## `strength` 0 = limp ragdoll, 1 = holds the pose firmly. hit() knocks it.
##
## Not Jolt motor constraints: Godot does not expose per-joint motors on
## PhysicalBone3D, so this approximates them with velocity steering.

signal went_limp
signal recovered

@export var simulator: PhysicalBoneSimulator3D
@export var target_skeleton: Skeleton3D
@export_range(0.0, 1.0) var strength := 0.6
@export var linear_gain := 12.0
@export var angular_gain := 14.0
@export var max_linear_speed := 8.0
@export var max_angular_speed := 12.0
## Bones that should NOT be driven (e.g. the root so the body can fall).
@export var unpowered_bones: PackedStringArray = PackedStringArray()

var bones: Array[PhysicalBone3D] = []
var active := false
var _snapshot := {}      ## bone_id -> Transform3D (skeleton space)
var _limp_timer := 0.0
var _saved_strength := 0.6

func _ready() -> void:
	if simulator == null:
		for c in get_parent().find_children("*", "PhysicalBoneSimulator3D", true, false):
			simulator = c
			break
	_collect()

func _collect() -> void:
	bones.clear()
	if simulator == null:
		return
	for c in simulator.find_children("*", "PhysicalBone3D", true, false):
		bones.append(c as PhysicalBone3D)

func _skeleton() -> Skeleton3D:
	return simulator.get_parent() as Skeleton3D if simulator else null

func start(snapshot_pose := true) -> void:
	if simulator == null:
		push_warning("ChomuActiveRagdoll: no PhysicalBoneSimulator3D")
		return
	_collect()
	var sk := _skeleton()
	if snapshot_pose and sk:
		_snapshot.clear()
		for i in sk.get_bone_count():
			_snapshot[i] = sk.get_bone_global_pose(i)
	simulator.active = true
	simulator.physical_bones_start_simulation()
	active = true

func stop() -> void:
	if simulator:
		simulator.physical_bones_stop_simulation()
	active = false

## Knock: impulse at the nearest bone and go limp for `limp_seconds`.
func hit(world_pos: Vector3, impulse: Vector3, limp_seconds := 1.5) -> void:
	var best: PhysicalBone3D = null
	var bd := INF
	for b in bones:
		var d := b.global_position.distance_to(world_pos)
		if d < bd:
			bd = d
			best = b
	if best:
		best.apply_impulse(impulse, world_pos - best.global_position)
	if limp_seconds > 0.0:
		if _limp_timer <= 0.0:
			_saved_strength = strength
		_limp_timer = limp_seconds
		strength = 0.0
		went_limp.emit()

func _target_global(b: PhysicalBone3D) -> Variant:
	var sk := _skeleton()
	var id := b.get_bone_id()
	if id < 0 or sk == null:
		return null
	var local: Transform3D
	if target_skeleton and id < target_skeleton.get_bone_count():
		local = target_skeleton.get_bone_global_pose(id)
	elif _snapshot.has(id):
		local = _snapshot[id]
	else:
		return null
	# PhysicalBone3D body sits at bone pose * body_offset^-1 equivalent
	return sk.global_transform * local * b.body_offset

func _physics_process(delta: float) -> void:
	if not active:
		return
	if _limp_timer > 0.0:
		_limp_timer -= delta
		if _limp_timer <= 0.0:
			strength = _saved_strength
			recovered.emit()
	if strength <= 0.001:
		return
	for b in bones:
		if unpowered_bones.has(b.bone_name):
			continue
		var tv: Variant = _target_global(b)
		if tv == null:
			continue
		var tgt: Transform3D = tv
		var cur := b.global_transform
		var dv := (tgt.origin - cur.origin) * linear_gain * strength
		b.linear_velocity = b.linear_velocity.lerp(dv.limit_length(max_linear_speed), clampf(strength, 0.0, 1.0) * 0.5)
		var dq := (tgt.basis.get_rotation_quaternion() * cur.basis.get_rotation_quaternion().inverse()).normalized()
		if dq.w < 0.0:
			dq = -dq
		var ang := 2.0 * acos(clampf(dq.w, -1.0, 1.0))
		if ang > 0.0001:
			var axis := Vector3(dq.x, dq.y, dq.z).normalized()
			var wv := axis * ang * angular_gain * strength
			b.angular_velocity = b.angular_velocity.lerp(wv.limit_length(max_angular_speed), clampf(strength, 0.0, 1.0) * 0.5)

## Average distance (m) of powered bones from their target pose.
func pose_error() -> float:
	var s := 0.0
	var n := 0
	for b in bones:
		var tv: Variant = _target_global(b)
		if tv == null:
			continue
		s += b.global_position.distance_to((tv as Transform3D).origin)
		n += 1
	return s / maxf(1.0, float(n))
