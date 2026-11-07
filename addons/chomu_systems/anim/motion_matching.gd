extends RefCounted
class_name ChomuMotionMatching

## Internal clip storage
var _clips: Dictionary = {}  # name -> Array[Dictionary] (each frame: {features: PackedFloat32Array})
var _clip_names: Array[String] = []
var _frame_counts: Array[int] = []

## Normalization stats
var _feature_mean: PackedFloat32Array = PackedFloat32Array()
var _feature_std: PackedFloat32Array = PackedFloat32Array()
var _normalized: bool = false

## Transition bias
var _transition_cost: float = 0.1
var _current_clip_idx: int = -1
var _current_frame_idx: int = -1

func _init() -> void:
	_clips = {}
	_clip_names = []
	_frame_counts = []
	_feature_mean = PackedFloat32Array()
	_feature_std = PackedFloat32Array()
	_normalized = false
	_transition_cost = 0.1
	_current_clip_idx = -1
	_current_frame_idx = -1

## Add a clip with frames containing feature vectors.
## Each frame dict must have a "features" key with PackedFloat32Array.
func add_clip(name: String, frames: Array[Dictionary]) -> void:
	if name in _clips:
		push_error("Clip '%s' already exists" % name)
		return
	if frames.is_empty():
		push_error("Clip '%s' has no frames" % name)
		return
	
	var feature_size: int = -1
	for frame in frames:
		if not frame.has("features"):
			push_error("Frame missing 'features' key in clip '%s'" % name)
			return
		var feats: PackedFloat32Array = frame.features
		if feature_size == -1:
			feature_size = feats.size()
		elif feats.size() != feature_size:
			push_error("Inconsistent feature size in clip '%s'" % name)
			return
	
	_clips[name] = frames.duplicate(true)
	_clip_names.append(name)
	_frame_counts.append(frames.size())
	_normalized = false

## Compute per-dimension mean and std across all frames in all clips.
func normalize() -> void:
	var total_frames: int = 0
	for count in _frame_counts:
		total_frames += count
	
	if total_frames == 0:
		return
	
	var feature_size: int = -1
	for name in _clip_names:
		var frames: Array = _clips[name]
		if frames.size() > 0:
			feature_size = frames[0].features.size()
			break
	
	if feature_size <= 0:
		return
	
	var sum: PackedFloat32Array = PackedFloat32Array()
	sum.resize(feature_size)
	sum.fill(0.0)
	
	# First pass: mean
	for name in _clip_names:
		var frames: Array = _clips[name]
		for frame in frames:
			var feats: PackedFloat32Array = frame.features
			for i in range(feature_size):
				sum[i] += feats[i]
	
	_feature_mean.resize(feature_size)
	for i in range(feature_size):
		_feature_mean[i] = sum[i] / total_frames
	
	# Second pass: variance
	var var_sum: PackedFloat32Array = PackedFloat32Array()
	var_sum.resize(feature_size)
	var_sum.fill(0.0)
	
	for name in _clip_names:
		var frames: Array = _clips[name]
		for frame in frames:
			var feats: PackedFloat32Array = frame.features
			for i in range(feature_size):
				var diff: float = feats[i] - _feature_mean[i]
				var_sum[i] += diff * diff
	
	_feature_std.resize(feature_size)
	for i in range(feature_size):
		var variance: float = var_sum[i] / total_frames
		_feature_std[i] = sqrt(max(variance, 1e-8))  # avoid div by zero
	
	_normalized = true

## Query nearest frame by weighted squared distance on normalized features.
## If weights is empty, uniform weight (1.0) is used.
## Returns {clip: String, frame: int, cost: float}.
## Continuing the current clip gets a bias (transition_cost subtracted from cost).
func query(features: PackedFloat32Array, weights: PackedFloat32Array = PackedFloat32Array()) -> Dictionary:
	if not _normalized:
		push_error("Must call normalize() before query()")
		return {"clip": "", "frame": -1, "cost": INF}
	
	if _clip_names.is_empty():
		return {"clip": "", "frame": -1, "cost": INF}
	
	var feature_size: int = _feature_mean.size()
	if features.size() != feature_size:
		push_error("Query feature size %d != normalized size %d" % [features.size(), feature_size])
		return {"clip": "", "frame": -1, "cost": INF}
	
	# Prepare weights
	var w: PackedFloat32Array = weights
	if w.is_empty():
		w.resize(feature_size)
		w.fill(1.0)
	elif w.size() != feature_size:
		push_error("Weights size %d != feature size %d" % [w.size(), feature_size])
		return {"clip": "", "frame": -1, "cost": INF}
	
	# Normalize query features
	var norm_query: PackedFloat32Array = PackedFloat32Array()
	norm_query.resize(feature_size)
	for i in range(feature_size):
		norm_query[i] = (features[i] - _feature_mean[i]) / _feature_std[i]
	
	var best_cost: float = INF
	var best_clip_idx: int = -1
	var best_frame_idx: int = -1
	
	for clip_idx in range(_clip_names.size()):
		var name: String = _clip_names[clip_idx]
		var frames: Array = _clips[name]
		
		for frame_idx in range(frames.size()):
			var frame_feats: PackedFloat32Array = frames[frame_idx].features
			
			# Compute weighted squared distance on normalized features
			var cost: float = 0.0
			for i in range(feature_size):
				var diff: float = (frame_feats[i] - _feature_mean[i]) / _feature_std[i] - norm_query[i]
				cost += w[i] * diff * diff
			
			# Apply transition bias if continuing current clip
			if clip_idx == _current_clip_idx:
				cost -= _transition_cost
			
			if cost < best_cost:
				best_cost = cost
				best_clip_idx = clip_idx
				best_frame_idx = frame_idx
	
	if best_clip_idx >= 0:
		_current_clip_idx = best_clip_idx
		_current_frame_idx = best_frame_idx
		return {"clip": _clip_names[best_clip_idx], "frame": best_frame_idx, "cost": best_cost}
	
	return {"clip": "", "frame": -1, "cost": INF}

## Set transition cost bias for continuing the same clip.
func set_transition_cost(cost: float) -> void:
	_transition_cost = max(0.0, cost)

## Get current clip index (for testing/debugging).
func get_current_clip_idx() -> int:
	return _current_clip_idx

## Get current frame index (for testing/debugging).
func get_current_frame_idx() -> int:
	return _current_frame_idx

## Analytic two-bone IK solver.
## root, mid, end: current joint positions (world space)
## target: desired end effector position
## pole: pole vector position (defines bend plane)
## Returns [new_mid, new_end] preserving bone lengths.
## If target unreachable, fully extends toward target.
static func two_bone_ik(root: Vector3, mid: Vector3, end: Vector3, target: Vector3, pole: Vector3) -> Array[Vector3]:
	var bone1_len: float = root.distance_to(mid)
	var bone2_len: float = mid.distance_to(end)
	var total_len: float = bone1_len + bone2_len
	
	var to_target: Vector3 = target - root
	var dist_to_target: float = to_target.length()
	
	# Target unreachable: fully extend toward target
	if dist_to_target >= total_len - 1e-6:
		var dir: Vector3 = to_target.normalized() if dist_to_target > 1e-6 else Vector3(0, 1, 0)
		var new_mid: Vector3 = root + dir * bone1_len
		var new_end: Vector3 = new_mid + dir * bone2_len
		return [new_mid, new_end]
	
	# Target at root: arbitrary orientation using pole
	if dist_to_target < 1e-6:
		var dir: Vector3 = (pole - root).normalized()
		if dir.length() < 1e-6:
			dir = Vector3(0, 1, 0)
		var new_mid: Vector3 = root + dir * bone1_len
		var new_end: Vector3 = new_mid + dir * bone2_len
		return [new_mid, new_end]
	
	# Clamp distance to valid range for law of cosines
	var d: float = clamp(dist_to_target, abs(bone1_len - bone2_len), total_len)
	
	# Law of cosines: angle at root (theta1)
	# cos(theta1) = (L1^2 + d^2 - L2^2) / (2 * L1 * d)
	var cos_theta1: float = (bone1_len * bone1_len + d * d - bone2_len * bone2_len) / (2.0 * bone1_len * d)
	cos_theta1 = clamp(cos_theta1, -1.0, 1.0)
	var sin_theta1: float = sqrt(max(0.0, 1.0 - cos_theta1 * cos_theta1))
	
	# Build orthonormal basis in the pole plane
	var forward: Vector3 = to_target.normalized()
	var pole_dir: Vector3 = (pole - root).normalized()
	
	# Up vector = pole_dir projected perpendicular to forward
	var up: Vector3 = (pole_dir - forward * forward.dot(pole_dir)).normalized()
	if up.length() < 1e-6:
		# Fallback: use cross product with a non-parallel axis
		var fallback_axis: Vector3 = Vector3(0, 1, 0) if abs(forward.dot(Vector3(0, 1, 0))) < 0.9 else Vector3(1, 0, 0)
		up = forward.cross(fallback_axis).normalized()
	
	# Compute new mid position in the pole plane
	# M' = R + forward * (L1 * cos_theta1) + up * (L1 * sin_theta1)
	var new_mid: Vector3 = root + forward * (bone1_len * cos_theta1) + up * (bone1_len * sin_theta1)
	
	# For reachable target, end should be exactly at target (bone2 length preserved by construction)
	# But ensure exact bone2 length due to floating point
	var to_target_from_mid: Vector3 = target - new_mid
	var actual_bone2_len: float = to_target_from_mid.length()
	var new_end: Vector3
	if actual_bone2_len > 1e-6:
		new_end = new_mid + to_target_from_mid * (bone2_len / actual_bone2_len)
	else:
		# Degenerate case: mid == target, extend along bone1 direction
		var bone1_dir: Vector3 = (new_mid - root).normalized()
		new_end = new_mid + bone1_dir * bone2_len
	
	return [new_mid, new_end]
