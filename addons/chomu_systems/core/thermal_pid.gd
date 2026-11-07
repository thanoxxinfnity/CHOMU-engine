extends RefCounted
class_name ChomuThermalPID

## Thermal governor PID controller for managing device heat.
## Maps thermal headroom (0.0 = throttling, 1.0 = cool) to a governor stage.

var kp: float = 2.0
var ki: float = 1.0
var kd: float = 0.1
var target_headroom: float = 0.25

var _integral: float = 0.0
var _last_error: float = 0.0
var _current_stage: int = 0

## Hysteresis prevents rapid switching between stages.
const HYSTERESIS: float = 0.25

## Updates the PID loop and returns a raw output value (typically 0..3).
## headroom: 0.0 (critical/throttling) to 1.0 (very cool).
func update(headroom: float, dt: float) -> float:
	if dt <= 0.0:
		return float(_current_stage)
	
	var error: float = headroom - target_headroom
	
	# Proportional
	var p_out: float = kp * error
	
	# Integral with anti-windup clamp
	_integral += error * dt
	_integral = clampf(_integral, -2.0, 2.0)
	var i_out: float = ki * _integral
	
	# Derivative
	var d_out: float = kd * (error - _last_error) / dt
	_last_error = error
	
	var output: float = p_out + i_out + d_out
	
	# We want: Low headroom (negative error) -> High Stage (3)
	# High headroom (positive error) -> Low Stage (0)
	# Invert the PID output so that negative error results in positive stage value.
	var stage_val: float = -output
	
	return clampf(stage_val, 0.0, 3.0)

## Determines the discrete governor stage based on the PID output.
## Implements hysteresis to prevent oscillation.
func stage(pid_output: float) -> int:
	var target_stage: int = int(roundf(pid_output))
	target_stage = clampi(target_stage, 0, 3)
	
	if _current_stage == target_stage:
		return _current_stage
	
	# Hysteresis: Only change stage if the pid_output has moved 
	# significantly away from the current stage's center.
	if abs(pid_output - float(_current_stage)) > HYSTERESIS:
		_current_stage = target_stage
		
	return _current_stage

## Converts a Celsius temperature to a 0..1 headroom value.
## 1.0 = cool or below, 0.0 = hot or above.
static func headroom_from_temp(celsius: float, cool: float = 35.0, hot: float = 48.0) -> float:
	if celsius <= cool:
		return 1.0
	if celsius >= hot:
		return 0.0
	return 1.0 - ((celsius - cool) / (hot - cool))
