extends RefCounted
class_name ChomuCharacterControllerSlopeSliding

## S-66 Character Controller Slope Sliding
## Implements the logic for characters sliding down slopes when the incline 
## exceeds a specific threshold, common in first/third person controllers.
## 
## This class is headless and deterministic. It calculates the sliding 
## velocity based on the surface normal and the character's current state.

class SlopeConfig:
	## Maximum angle (in degrees) before the character starts sliding.
	var max_slope_angle: float = 45.0
	## Acceleration applied when sliding.
	var slide_acceleration: float = 15.0
	## Friction applied to sliding movement to prevent infinite acceleration.
	var slide_friction: float = 2.0
	## Minimum velocity required to maintain a slide.
	var min_slide_velocity: float = 0.1

class SlopeState:
	## Current sliding velocity vector.
	var slide_velocity: Vector3 = Vector3.ZERO
	## Whether the character is currently in a sliding state.
	var is_sliding: bool = false

## Configuration for the slope sliding system.
var config := SlopeConfig.new()
## Current state of the sliding system.
var state := SlopeState.new()

## Calculates the sliding velocity for the current frame.
## [br]
## @param delta: Frame delta time.
## @param current_velocity: The character's current movement velocity.
## @param surface_normal: The normal of the surface the character is standing on.
## @param is_grounded: Whether the character is touching the ground.
## @return: The updated velocity including sliding forces.
func calculate_velocity(delta: float, current_velocity: Vector3, surface_normal: Vector3, is_grounded: bool) -> Vector3:
	if not is_grounded:
		state.is_sliding = false
		state.slide_velocity = Vector3.ZERO
		return current_velocity

	# Calculate slope angle
	# surface_normal.y is cos(theta) where theta is angle from vertical (0,1,0)
	var slope_angle_rad := acos(clampf(surface_normal.dot(Vector3.UP), -1.0, 1.0))
	var slope_angle_deg := rad_to_deg(slope_angle_rad)

	if slope_angle_deg > config.max_slope_angle:
		state.is_sliding = true
		
		# Calculate slide direction: project gravity (0, -1, 0) onto the plane
		# Slide Dir = Gravity - (Gravity dot Normal) * Normal
		var gravity_dir := Vector3.DOWN
		var slide_dir := gravity_dir - surface_normal * gravity_dir.dot(surface_normal)
		
		if slide_dir.length_squared() > 0.001:
			slide_dir = slide_dir.normalized()
		else:
			slide_dir = Vector3.ZERO
		
		# Apply acceleration
		state.slide_velocity += slide_dir * config.slide_acceleration * delta
		
		# Apply friction/damping
		state.slide_velocity -= state.slide_velocity * config.slide_friction * delta
		
		# Clamp to minimum velocity to avoid jitter
		if state.slide_velocity.length() < config.min_slide_velocity:
			state.slide_velocity = Vector3.ZERO
			state.is_sliding = false
	else:
		# On a walkable slope, bleed off sliding velocity
		state.is_sliding = false
		state.slide_velocity = state.slide_velocity.lerp(Vector3.ZERO, delta * config.slide_friction * 5.0)

	return current_velocity + state.slide_velocity

## Serializes the current state to a Dictionary.
func save_state() -> Dictionary:
	return {
		"slide_velocity": state.slide_velocity,
		"is_sliding": state.is_sliding
	}

## Restores the state from a Dictionary.
func load_state(data: Dictionary) -> void:
	state.slide_velocity = data.get("slide_velocity", Vector3.ZERO)
	state.is_sliding = data.get("is_sliding", false)
