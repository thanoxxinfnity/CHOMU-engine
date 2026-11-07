extends Node3D
class_name ChomuLightExposure

## F-41 Light-as-gameplay.
## Samples luminance at multiple points (e.g. bones/markers) and smooths them
## using a round-robin update pattern to simulate async GPU readback lag.
## This prevents spikes and spreads CPU cost across frames.

@export var sample_points: Array[Node3D] = []
@export var ambient_level: float = 0.02
@export var weight_max: bool = true

# Internal state for round-robin sampling
var _current_index: int = 0
var _point_values: Array[float] = []
var _cached_exposure: float = 0.0

# Tracking for test verification
var _samples_this_frame: int = 0

const LightProbe := preload("res://addons/chomu_systems/core/light_probe.gd")

func _ready() -> void:
	_initialize_values()

func _physics_process(_delta: float) -> void:
	_samples_this_frame = 0
	if sample_points.is_empty():
		_cached_exposure = ambient_level
		return
	
	_update_single_sample()
	_calculate_exposure()

func _initialize_values() -> void:
	_point_values.clear()
	for i in range(sample_points.size()):
		_point_values.append(ambient_level)

func _update_single_sample() -> void:
	if _point_values.size() != sample_points.size():
		_initialize_values()
		_current_index = 0
	
	var target := sample_points[_current_index]
	if is_instance_valid(target):
		var space := get_world_3d().direct_space_state
		var val := LightProbe.estimate(get_tree(), target.global_position, space, ambient_level)
		_point_values[_current_index] = val
		_samples_this_frame += 1
	
	_current_index = (_current_index + 1) % sample_points.size()

func _calculate_exposure() -> void:
	if weight_max:
		var max_val := 0.0
		for v in _point_values:
			if v > max_val:
				max_val = v
		_cached_exposure = max_val
	else:
		var sum := 0.0
		for v in _point_values:
			sum += v
		_cached_exposure = sum / float(_point_values.size()) if _point_values.size() > 0 else ambient_level

## Returns the current aggregated luminance exposure.
func exposure() -> float:
	return _cached_exposure

## Returns a visibility score based on exposure and distance to an observer.
func visibility_for(observer_dist: float) -> float:
	# Simple linear falloff for distance perception
	var dist_factor := 1.0 / (1.0 + (observer_dist * 0.1))
	return exposure() * dist_factor
