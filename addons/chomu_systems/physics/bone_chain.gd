extends Node3D
class_name ChomuBoneChain

## Joint driving mode
enum JointMode {
	JOINTS_ARRAY,
	SKELETON_BONES
}

## Gravity vector applied each physics step
@export var gravity: Vector3 = Vector3(0, -9.81, 0)
## Velocity damping factor (0..1)
@export var damping: float = 0.02
## Stiffness pulling toward rest pose (0..1)
@export var stiffness: float = 0.5
## Number of distance constraint iterations per step
@export var constraint_iterations: int = 8
## Whether the root joint is anchored (fixed in world space)
@export var anchor_root: bool = true

var _mode: JointMode = JointMode.JOINTS_ARRAY
var _joints: Array[Node3D] = []
var _skeleton: Skeleton3D = null
var _bone_names: Array[String] = []
var _bone_indices: Array[int] = []

var _rest_local_positions: Array[Vector3] = []
var _prev_positions: Array[Vector3] = []
var _curr_positions: Array[Vector3] = []
var _segment_lengths: Array[float] = []

var _colliders: Array[Dictionary] = []  # {center_node: Node3D, radius: float}
var _initialized: bool = false

func _ready() -> void:
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not _initialized:
		_try_initialize()
		if not _initialized:
			return
	
	if _joints.is_empty() and _bone_indices.is_empty():
		return
	
	var count = _get_joint_count()
	if count < 2:
		return
	
	# Verlet integration
	var dt = delta
	var dt2 = dt * dt
	
	for i in range(count):
		if anchor_root and i == 0:
			_prev_positions[i] = _curr_positions[i]
			continue
		
		var velocity = _curr_positions[i] - _prev_positions[i]
		_prev_positions[i] = _curr_positions[i]
		
		_curr_positions[i] += velocity * (1.0 - damping) + gravity * dt2
		
		if stiffness > 0.0 and i > 0:
			var parent_idx = i - 1
			var parent_pos = _curr_positions[parent_idx]
			var rest_offset = _rest_local_positions[i]
			var target_pos = parent_pos + rest_offset
			_curr_positions[i] = _curr_positions[i].lerp(target_pos, stiffness)
	
	# Distance constraints
	for _iter in range(constraint_iterations):
		for i in range(1, count):
			var parent_idx = i - 1
			var delta_pos = _curr_positions[i] - _curr_positions[parent_idx]
			var dist = delta_pos.length()
			var target_len = _segment_lengths[i - 1]
			
			if dist > 0.0001:
				var diff = (dist - target_len) / dist
				var correction = delta_pos * 0.5 * diff
				
				if not (anchor_root and parent_idx == 0):
					_curr_positions[parent_idx] += correction
				_curr_positions[i] -= correction
	
	# Sphere colliders
	for collider in _colliders:
		var center_node = collider.center_node
		var radius = collider.radius
		if not center_node or not center_node.is_inside_tree():
			continue
		var center = center_node.global_position
		for i in range(count):
			if anchor_root and i == 0:
				continue
			var to_joint = _curr_positions[i] - center
			var dist = to_joint.length()
			if dist < radius and dist > 0.0001:
				_curr_positions[i] = center + to_joint.normalized() * radius
	
	_apply_positions()

func _try_initialize() -> void:
	var count = _get_joint_count()
	if count < 2:
		return
	
	if _mode == JointMode.JOINTS_ARRAY:
		for joint in _joints:
			if joint and not joint.is_inside_tree():
				return
	
	_init_arrays(count)
	_initialized = true

func _init_arrays(count: int) -> void:
	_prev_positions.resize(count)
	_curr_positions.resize(count)
	_rest_local_positions.resize(count)
	_segment_lengths.resize(max(0, count - 1))
	
	for i in range(count):
		var pos = _get_joint_global_position(i)
		_curr_positions[i] = pos
		_prev_positions[i] = pos
		if i > 0:
			var parent_pos = _get_joint_global_position(i - 1)
			_rest_local_positions[i] = pos - parent_pos
			_segment_lengths[i - 1] = _rest_local_positions[i].length()
		else:
			_rest_local_positions[i] = Vector3.ZERO

func _get_joint_count() -> int:
	return _joints.size() if _mode == JointMode.JOINTS_ARRAY else _bone_indices.size()

func _get_joint_global_position(index: int) -> Vector3:
	if _mode == JointMode.JOINTS_ARRAY:
		var joint = _joints[index]
		if not joint:
			return Vector3.ZERO
		if joint.is_inside_tree():
			return joint.global_position
		var parent = joint.get_parent()
		if parent and parent.is_inside_tree():
			return parent.global_transform * joint.transform
		return joint.transform.origin
	else:
		var idx = _bone_indices[index]
		if idx >= 0 and _skeleton and _skeleton.is_inside_tree():
			return _skeleton.get_bone_global_pose(idx).origin
		return Vector3.ZERO

func _apply_positions() -> void:
	if _mode == JointMode.JOINTS_ARRAY:
		for i in range(_joints.size()):
			var joint = _joints[i]
			if joint and joint.is_inside_tree():
				joint.global_position = _curr_positions[i]
	else:
		for i in range(_bone_indices.size()):
			var idx = _bone_indices[i]
			if idx >= 0 and _skeleton and _skeleton.is_inside_tree():
				var pose = _skeleton.get_bone_global_pose(idx)
				pose.origin = _curr_positions[i]
				_skeleton.set_bone_global_pose(idx, pose)

func set_joints(joints: Array[Node3D]) -> void:
	_joints = joints
	_mode = JointMode.JOINTS_ARRAY
	_skeleton = null
	_bone_names.clear()
	_bone_indices.clear()
	_initialized = false

func set_skeleton(skeleton: Skeleton3D, bone_names: Array[String]) -> void:
	_skeleton = skeleton
	_bone_names = bone_names
	_mode = JointMode.SKELETON_BONES
	_joints.clear()
	_bone_indices.clear()
	for name in bone_names:
		var idx = skeleton.find_bone(name) if skeleton else -1
		_bone_indices.append(idx)
	_initialized = false

func add_collider(center_node: Node3D, radius: float) -> void:
	_colliders.append({ "center_node": center_node, "radius": radius })

func remove_collider(center_node: Node3D) -> void:
	for i in range(_colliders.size() - 1, -1, -1):
		if _colliders[i].center_node == center_node:
			_colliders.remove_at(i)

func clear_colliders() -> void:
	_colliders.clear()

static func pick_mode(tier: int) -> String:
	return "bone_chain" if tier < 2 else "soft_body"

func get_joint_count() -> int:
	return _get_joint_count()

func get_joint_positions() -> Array[Vector3]:
	var count = _get_joint_count()
	var result: Array[Vector3] = []
	result.resize(count)
	for i in range(count):
		result[i] = _curr_positions[i]
	return result
