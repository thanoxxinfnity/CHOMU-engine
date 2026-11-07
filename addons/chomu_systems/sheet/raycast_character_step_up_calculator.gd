extends RefCounted
class_name ChomuRaycastCharacterStepUpCalculator

## Core implementation of a Raycast Character Step-Up Calculator.
## This system calculates the necessary vertical offset and forward movement 
## to allow a character to smoothly step over small obstacles (stairs, curbs) 
## without getting stuck on their collision capsule.

class StepResult:
	## Whether a valid step-up was found.
	var success: bool = false
	## The vertical offset to apply to the character.
	var vertical_offset: float = 0.0
	## The horizontal distance the character can move forward.
	var horizontal_offset: float = 0.0
	## The normal of the surface being stepped onto.
	var surface_normal: Vector3 = Vector3.UP

## Configuration for the step-up logic.
class StepConfig:
	## Maximum height the character can step up.
	var max_step_height: float = 0.3
	## Distance in front of the character to check for obstacles.
	var step_check_distance: float = 0.5
	## The height offset for the "landing" raycast.
	var landing_ray_offset: float = 0.35
	## Minimum distance to move forward when a step is detected.
	var min_step_forward: float = 0.05

var _config: StepConfig

func _init() -> void:
	_config = StepConfig.new()

## Returns the current configuration.
func get_config() -> StepConfig:
	return _config

## Sets the configuration.
func set_config(config: StepConfig) -> void:
	_config = config

## Calculates the step-up offset based on the character's current state and physics world.
func calculate_step(current_pos: Vector3, velocity: Vector3, space_state: PhysicsDirectSpaceState3D) -> StepResult:
	var result := StepResult.new()
	
	if velocity.length_squared() < 0.001:
		return result
	
	var move_dir := velocity.normalized()
	var horizontal_dir := Vector3(move_dir.x, 0, move_dir.z).normalized()
	if horizontal_dir.length_squared() < 0.001:
		return result

	# 1. Forward Raycast: Detect if there is an obstacle in front of the feet
	# Cast from slightly above ground to avoid floor collision
	var ray_start := current_pos + Vector3.UP * 0.05
	var ray_end := ray_start + horizontal_dir * _config.step_check_distance
	
	var query := PhysicsRayQueryParameters3D.new()
	query.from = ray_start
	query.to = ray_end
	
	var hit := space_state.intersect_ray(query)
	
	if hit.is_empty():
		return result
	
	# 2. Downward Raycast: Find the top of the obstacle
	# We move the ray start forward past the hit point. 
	# Use a small offset to ensure we are over the ledge.
	var hit_pos_forward := hit.get("position", ray_start)
	var step_forward_pos = hit_pos_forward + horizontal_dir * 0.1
	
	# The landing ray starts above the max step height and casts down
	var landing_start = step_forward_pos + Vector3.UP * _config.landing_ray_offset
	var landing_end = landing_start + Vector3.DOWN * (_config.landing_ray_offset + 0.2)
	
	var landing_query := PhysicsRayQueryParameters3D.new()
	landing_query.from = landing_start
	landing_query.to = landing_end
	
	var landing_hit := space_state.intersect_ray(landing_query)
	
	if landing_hit.is_empty():
		return result
	
	var final_hit_pos := landing_hit.get("position", landing_start)
	var step_height = final_hit_pos.y - current_pos.y
	
	# Verify the step is within the allowed height range
	if step_height > 0.01 and step_height <= _config.max_step_height:
		result.success = true
		result.vertical_offset = step_height
		result.horizontal_offset = (final_hit_pos - current_pos).length()
		result.surface_normal = landing_hit.get("normal", Vector3.UP)
		
	return result

## Saves the current configuration to a Dictionary.
func save_state() -> Dictionary:
	return {
		"max_step_height": _config.max_step_height,
		"step_check_distance": _config.step_check_distance,
		"landing_ray_offset": _config.landing_ray_offset,
		"min_step_forward": _config.min_step_forward,
	}

## Loads the configuration from a Dictionary.
func load_state(data: Dictionary) -> void:
	if data.has("max_step_height"): _config.max_step_height = data["max_step_height"]
	if data.has("step_check_distance"): _config.step_check_distance = data["step_check_distance"]
	if data.has("landing_ray_offset"): _config.landing_ray_offset = data["landing_ray_offset"]
	if data.has("min_step_forward"): _config.min_step_forward = data["min_step_forward"]
