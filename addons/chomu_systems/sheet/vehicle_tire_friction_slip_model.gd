extends RefCounted
class_name ChomuVehicleTireFrictionSlipModel

## ChomuVehicleTireFrictionSlipModel
## Data-driven Pacejka "Magic Formula" tire model with combined slip (friction ellipse).
## Mobile-first: minimal allocations, deterministic math, no rendering deps.
##
## Public API:
##   - set_pacejka_lateral(b: float, c: float, d: float, e: float) -> void
##   - set_pacejka_longitudinal(b: float, c: float, d: float, e: float) -> void
##   - set_pacejka_aligning(b: float, c: float, d: float, e: float) -> void
##   - set_friction_ellipse(use_ellipse: bool, ellipse_ratio: float) -> void
##   - set_load_sensitivity(sensitivity: float) -> void
##   - set_camber_stiffness(stiffness: float) -> void
##   - set_limits(max_slip_angle: float, max_slip_ratio: float) -> void
##   - compute_forces(slip_angle: float, slip_ratio: float, normal_load: float, camber: float = 0.0, delta: float = 0.0) -> Dictionary
##   - get_last_result() -> Dictionary
##   - save_state() -> Dictionary
##   - load_state(state: Dictionary) -> void
##   - reset() -> void
##
## Signals: none (stateless computation, state only for persistence/debug)

## Pacejka coefficients for lateral force (pure slip)
## Fy = D * sin(C * arctan(B * alpha - E * (B * alpha - arctan(B * alpha))))
@export var pacejka_lateral_b: float = 10.0
@export var pacejka_lateral_c: float = 1.9
@export var pacejka_lateral_d: float = 1.0
@export var pacejka_lateral_e: float = 0.97

## Pacejka coefficients for longitudinal force (pure slip)
## Fx = D * sin(C * arctan(B * kappa - E * (B * kappa - arctan(B * kappa))))
@export var pacejka_long_b: float = 12.0
@export var pacejka_long_c: float = 2.3
@export var pacejka_long_d: float = 1.0
@export var pacejka_long_e: float = 0.97

## Pacejka coefficients for aligning torque (pure slip)
## Mz = D * sin(C * arctan(B * alpha - E * (B * alpha - arctan(B * alpha))))
@export var pacejka_align_b: float = 8.0
@export var pacejka_align_c: float = 1.5
@export var pacejka_align_d: float = 0.1
@export var pacejka_align_e: float = 0.97

## Friction ellipse: if true, combine Fx/Fy via ellipse (Fx/Fx_max)^2 + (Fy/Fy_max)^2 <= 1
## If false, use friction circle (simple normalization).
@export var use_friction_ellipse: bool = true
## Ellipse ratio: Fy_max / Fx_max (typically > 1 for tires, lateral grip > longitudinal)
@export var friction_ellipse_ratio: float = 1.1

## Load sensitivity exponent: F_max ~ load^sensitivity (1.0 = linear, <1 = sublinear)
@export var load_sensitivity: float = 0.9

## Camber stiffness factor (aligning torque per radian of camber at peak load)
@export var camber_stiffness: float = 0.1

## Input clamping limits
@export var max_slip_angle: float = deg_to_rad(45.0)
@export var max_slip_ratio: float = 1.5

## Internal cached last result for inspection
var _last_result: Dictionary = {
	"lateral_force": 0.0,
	"longitudinal_force": 0.0,
	"aligning_torque": 0.0,
	"slip_angle": 0.0,
	"slip_ratio": 0.0,
	"normal_load": 0.0,
	"camber": 0.0,
	"combined_slip_factor": 1.0,
	"pure_lateral": 0.0,
	"pure_longitudinal": 0.0,
	"pure_aligning": 0.0,
}

func _init() -> void:
	reset()

## Set Pacejka lateral coefficients (B, C, D, E).
func set_pacejka_lateral(b: float, c: float, d: float, e: float) -> void:
	pacejka_lateral_b = b
	pacejka_lateral_c = c
	pacejka_lateral_d = d
	pacejka_lateral_e = e

## Set Pacejka longitudinal coefficients (B, C, D, E).
func set_pacejka_longitudinal(b: float, c: float, d: float, e: float) -> void:
	pacejka_long_b = b
	pacejka_long_c = c
	pacejka_long_d = d
	pacejka_long_e = e

## Set Pacejka aligning torque coefficients (B, C, D, E).
func set_pacejka_aligning(b: float, c: float, d: float, e: float) -> void:
	pacejka_align_b = b
	pacejka_align_c = c
	pacejka_align_d = d
	pacejka_align_e = e

## Configure friction combination: ellipse (true) or circle (false), and ellipse ratio.
func set_friction_ellipse(use_ellipse: bool, ellipse_ratio: float) -> void:
	use_friction_ellipse = use_ellipse
	friction_ellipse_ratio = max(0.1, ellipse_ratio)

## Set load sensitivity exponent (0.5..1.2 typical).
func set_load_sensitivity(sensitivity: float) -> void:
	load_sensitivity = clamp(sensitivity, 0.1, 2.0)

## Set camber stiffness factor.
func set_camber_stiffness(stiffness: float) -> void:
	camber_stiffness = stiffness

## Set input clamping limits (radians for angle, ratio for slip).
func set_limits(max_slip_angle_rad: float, max_slip_ratio_val: float) -> void:
	max_slip_angle = max(0.001, max_slip_angle_rad)
	max_slip_ratio = max(0.001, max_slip_ratio_val)

## Core computation: given slip angle (rad), slip ratio (kappa), normal load (N), camber (rad), and optional delta time,
## returns Dictionary with forces and torque. Deterministic, no internal state mutation except _last_result.
func compute_forces(slip_angle: float, slip_ratio: float, normal_load: float, camber: float = 0.0, delta: float = 0.0) -> Dictionary:
	# Clamp inputs
	var sa = clamp(slip_angle, -max_slip_angle, max_slip_angle)
	var sr = clamp(slip_ratio, -max_slip_ratio, max_slip_ratio)
	var load = max(0.0, normal_load)
	var ca = camber

	# Load scaling factor (sublinear)
	var load_factor = pow(load, load_sensitivity) if load > 0.0 else 0.0

	# Pure slip forces (normalized to 1.0 load)
	var pure_fy = _pacejka(sa, pacejka_lateral_b, pacejka_lateral_c, pacejka_lateral_d, pacejka_lateral_e)
	var pure_fx = _pacejka(sr, pacejka_long_b, pacejka_long_c, pacejka_long_d, pacejka_long_e)
	var pure_mz = _pacejka(sa, pacejka_align_b, pacejka_align_c, pacejka_align_d, pacejka_align_e)

	# Scale by load
	pure_fy *= load_factor
	pure_fx *= load_factor
	pure_mz *= load_factor

	# Camber contribution to aligning torque (linear approximation)
	pure_mz += ca * camber_stiffness * load_factor

	# Combined slip via friction ellipse
	var combined_factor = 1.0
	if use_friction_ellipse:
		# Ellipse: (Fx/Fx_max)^2 + (Fy/(Fy_max))^2 = 1
		# Fy_max = Fx_max * ratio
		var fx_max = abs(pure_fx) if abs(pure_fx) > 0.001 else 0.001
		var fy_max = abs(pure_fy) * friction_ellipse_ratio if abs(pure_fy) > 0.001 else 0.001
		# Compute utilization
		var ux = pure_fx / fx_max
		var uy = pure_fy / fy_max
		var util = ux * ux + uy * uy
		if util > 1.0:
			combined_factor = 1.0 / sqrt(util)
	else:
		# Friction circle: simple vector normalization
		var util = pure_fx * pure_fx + pure_fy * pure_fy
		var max_f = max(abs(pure_fx), abs(pure_fy) * friction_ellipse_ratio)
		if max_f > 0.0:
			var max_f_sq = max_f * max_f
			if util > max_f_sq:
				combined_factor = max_f / sqrt(util)

	var fy = pure_fy * combined_factor
	var fx = pure_fx * combined_factor
	# Aligning torque reduces with combined slip (empirical)
	var mz = pure_mz * combined_factor

	_last_result = {
		"lateral_force": fy,
		"longitudinal_force": fx,
		"aligning_torque": mz,
		"slip_angle": sa,
		"slip_ratio": sr,
		"normal_load": load,
		"camber": ca,
		"combined_slip_factor": combined_factor,
		"pure_lateral": pure_fy,
		"pure_longitudinal": pure_fx,
		"pure_aligning": pure_mz,
	}
	return _last_result.duplicate(true)

## Returns the last computed result (read-only copy).
func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)

## Pacejka magic formula: y = D * sin(C * arctan(B * x - E * (B * x - arctan(B * x))))
func _pacejka(x: float, b: float, c: float, d: float, e: float) -> float:
	var bx = b * x
	var atan_bx = atan(bx)
	var inner = bx - e * (bx - atan_bx)
	return d * sin(c * atan(inner))

## Serialize current configuration and last result to a Dictionary.
func save_state() -> Dictionary:
	return {
		"pacejka_lateral_b": pacejka_lateral_b,
		"pacejka_lateral_c": pacejka_lateral_c,
		"pacejka_lateral_d": pacejka_lateral_d,
		"pacejka_lateral_e": pacejka_lateral_e,
		"pacejka_long_b": pacejka_long_b,
		"pacejka_long_c": pacejka_long_c,
		"pacejka_long_d": pacejka_long_d,
		"pacejka_long_e": pacejka_long_e,
		"pacejka_align_b": pacejka_align_b,
		"pacejka_align_c": pacejka_align_c,
		"pacejka_align_d": pacejka_align_d,
		"pacejka_align_e": pacejka_align_e,
		"use_friction_ellipse": use_friction_ellipse,
		"friction_ellipse_ratio": friction_ellipse_ratio,
		"load_sensitivity": load_sensitivity,
		"camber_stiffness": camber_stiffness,
		"max_slip_angle": max_slip_angle,
		"max_slip_ratio": max_slip_ratio,
		"last_result": _last_result,
	}

## Load configuration and last result from a Dictionary.
func load_state(state: Dictionary) -> void:
	pacejka_lateral_b = state.get("pacejka_lateral_b", pacejka_lateral_b)
	pacejka_lateral_c = state.get("pacejka_lateral_c", pacejka_lateral_c)
	pacejka_lateral_d = state.get("pacejka_lateral_d", pacejka_lateral_d)
	pacejka_lateral_e = state.get("pacejka_lateral_e", pacejka_lateral_e)
	pacejka_long_b = state.get("pacejka_long_b", pacejka_long_b)
	pacejka_long_c = state.get("pacejka_long_c", pacejka_long_c)
	pacejka_long_d = state.get("pacejka_long_d", pacejka_long_d)
	pacejka_long_e = state.get("pacejka_long_e", pacejka_long_e)
	pacejka_align_b = state.get("pacejka_align_b", pacejka_align_b)
	pacejka_align_c = state.get("pacejka_align_c", pacejka_align_c)
	pacejka_align_d = state.get("pacejka_align_d", pacejka_align_d)
	pacejka_align_e = state.get("pacejka_align_e", pacejka_align_e)
	use_friction_ellipse = state.get("use_friction_ellipse", use_friction_ellipse)
	friction_ellipse_ratio = state.get("friction_ellipse_ratio", friction_ellipse_ratio)
	load_sensitivity = state.get("load_sensitivity", load_sensitivity)
	camber_stiffness = state.get("camber_stiffness", camber_stiffness)
	max_slip_angle = state.get("max_slip_angle", max_slip_angle)
	max_slip_ratio = state.get("max_slip_ratio", max_slip_ratio)
	if state.has("last_result"):
		_last_result = state["last_result"]

## Reset to defaults and clear last result.
func reset() -> void:
	pacejka_lateral_b = 10.0
	pacejka_lateral_c = 1.9
	pacejka_lateral_d = 1.0
	pacejka_lateral_e = 0.97
	pacejka_long_b = 12.0
	pacejka_long_c = 2.3
	pacejka_long_d = 1.0
	pacejka_long_e = 0.97
	pacejka_align_b = 8.0
	pacejka_align_c = 1.5
	pacejka_align_d = 0.1
	pacejka_align_e = 0.97
	use_friction_ellipse = true
	friction_ellipse_ratio = 1.1
	load_sensitivity = 0.9
	camber_stiffness = 0.1
	max_slip_angle = deg_to_rad(45.0)
	max_slip_ratio = 1.5
	_last_result = {
		"lateral_force": 0.0,
		"longitudinal_force": 0.0,
		"aligning_torque": 0.0,
		"slip_angle": 0.0,
		"slip_ratio": 0.0,
		"normal_load": 0.0,
		"camber": 0.0,
		"combined_slip_factor": 1.0,
		"pure_lateral": 0.0,
		"pure_longitudinal": 0.0,
		"pure_aligning": 0.0,
	}
