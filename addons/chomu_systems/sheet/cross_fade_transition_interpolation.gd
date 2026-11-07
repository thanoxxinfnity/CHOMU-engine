extends RefCounted
class_name ChomuCrossFadeTransitionInterpolation

## S-42 Cross-Fade Transition Interpolation
## Provides a seamless shift between two animation states (poses, weights, or values)
## to avoid snapping. Supports linear and smooth-step interpolation.

class TransitionState:
	## Current weight of the target state (0.0 to 1.0)
	var weight: float = 0.0
	## The value/pose of the source state at the moment transition started
	var source_value: Variant
	## The target value/pose to blend towards
	var target_value: Variant
	## Duration of the transition in seconds
	var duration: float = 0.0
	## Elapsed time since transition start
	var elapsed: float = 0.0
	## Whether the transition is currently active
	var active: bool = false

## Interpolation modes for the cross-fade
enum BlendMode {
	LINEAR,
	SMOOTHSTEP,
	SINE
}

var _current_state: TransitionState = TransitionState.new()
var _blend_mode: BlendMode = BlendMode.LINEAR

## Initializes the interpolator.
func _init() -> void:
	pass

## Starts a cross-fade transition from the current value to a new target value.
## [brb]
## [param current_val]: The value to start from (can be float, Vector3, Color, etc.)
## [param target_val]: The value to blend towards.
## [param duration]: Time in seconds for the transition to complete.
## [param mode]: The BlendMode to use for the curve.
func transition_to(current_val: Variant, target_val: Variant, duration: float, mode: BlendMode = BlendMode.LINEAR) -> void:
	_blend_mode = mode
	_current_state.source_value = current_val
	_current_state.target_value = target_val
	_current_state.duration = max(0.001, duration)
	_current_state.elapsed = 0.0
	_current_state.weight = 0.0
	_current_state.active = true

## Updates the transition timer and returns the interpolated value.
## [param delta]: Time elapsed since last frame.
func update(delta: float) -> Variant:
	if not _current_state.active:
		return _current_state.target_value if _current_state.target_value != null else null
	
	_current_state.elapsed += delta
	var t: float = clampf(_current_state.elapsed / _current_state.duration, 0.0, 1.0)
	
	var blend_t: float = t
	match _blend_mode:
		BlendMode.SMOOTHSTEP:
			blend_t = t * t * (3.0 - 2.0 * t)
		BlendMode.SINE:
			blend_t = 1.0 - cos(t * PI * 0.5)
		BlendMode.LINEAR:
			blend_t = t
	
	_current_state.weight = blend_t
	
	if t >= 1.0:
		_current_state.active = false
	
	return _interpolate(_current_state.source_value, _current_state.target_value, blend_t)

## Internal helper to handle different Godot types for interpolation.
func _interpolate(a: Variant, b: Variant, t: float) -> Variant:
	if a == null or b == null:
		return b if t > 0.5 else a
	
	if a is float and b is float:
		return lerp(a, b, t)
	if a is Vector3 and b is Vector3:
		return a.lerp(b, t)
	if a is Vector2 and b is Vector2:
		return a.lerp(b, t)
	if a is Color and b is Color:
		return a.lerp(b, t)
	if a is Transform3D and b is Transform3D:
		return a.interpolate_with(b, t)
	if a is Quaternion and b is Quaternion:
		return a.slerp(b, t)
	
	# Fallback for non-interpolatable types: snap at 0.5
	return b if t >= 0.5 else a

## Returns the current blend weight (0.0 to 1.0).
func get_weight() -> float:
	return _current_state.weight

## Returns true if a transition is currently in progress.
func is_transitioning() -> bool:
	return _current_state.active

## Serializes the current state to a Dictionary.
func save_state() -> Dictionary:
	return {
		"weight": _current_state.weight,
		"source": _current_state.source_value,
		"target": _current_state.target_value,
		"duration": _current_state.duration,
		"elapsed": _current_state.elapsed,
		"active": _current_state.active,
		"mode": _blend_mode
	}

## Restores the state from a Dictionary.
func load_state(data: Dictionary) -> void:
	_current_state.weight = data.get("weight", 0.0)
	_current_state.source_value = data.get("source", null)
	_current_state.target_value = data.get("target", null)
	_current_state.duration = data.get("duration", 0.0)
	_current_state.elapsed = data.get("elapsed", 0.0)
	_current_state.active = data.get("active", false)
	_blend_mode = data.get("mode", BlendMode.LINEAR)
