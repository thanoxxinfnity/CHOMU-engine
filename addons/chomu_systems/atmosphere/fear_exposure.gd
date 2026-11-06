class_name ChomuFearExposure
extends Node
## F-43 Fear exposure. Simulated eye adaptation (fast to bright, slow to dark)
## with a scriptable "hold darkness" curve: while a hold is active the eye is
## kept from adapting, so a dark room stays scary-dark.
## Drives CameraAttributesPractical.exposure_multiplier (and auto_exposure_scale
## when auto exposure is on) on `camera_attributes`, or on the Camera3D /
## WorldEnvironment it finds.

signal exposure_changed(value: float)

@export var camera: Camera3D
@export var camera_attributes: CameraAttributesPractical
@export var probe_luminance := true        ## sample ChomuLightProbe at the camera
@export var target_luminance := 0.35       ## "comfortable" scene level
@export var min_exposure := 0.6
@export var max_exposure := 2.2
@export var adapt_to_bright := 2.5         ## 1/s
@export var adapt_to_dark := 0.25          ## 1/s (rods are slow)
## x = hold progress 0..1, y = how much adaptation is suppressed 0..1
@export var hold_curve: Curve
## Extra darkening from tension (0..1 from a TensionDirector)
@export var tension_director: ChomuTensionDirector
@export var tension_darken := 0.25

var exposure := 1.0
var luminance := 0.35
var luminance_override := -1.0
var _hold_left := 0.0
var _hold_total := 0.0

func _ready() -> void:
	if camera == null and get_parent() is Camera3D:
		camera = get_parent() as Camera3D
	if camera_attributes == null and camera:
		if camera.attributes is CameraAttributesPractical:
			camera_attributes = camera.attributes
		else:
			camera_attributes = CameraAttributesPractical.new()
			camera.attributes = camera_attributes
	if hold_curve == null:
		hold_curve = Curve.new()
		hold_curve.add_point(Vector2(0, 1))
		hold_curve.add_point(Vector2(0.7, 0.9))
		hold_curve.add_point(Vector2(1, 0))

## Keep the eye from adapting for `seconds` (shaped by hold_curve).
func hold_darkness(seconds: float) -> void:
	_hold_total = maxf(seconds, 0.01)
	_hold_left = _hold_total

func is_holding() -> bool:
	return _hold_left > 0.0

func _process(delta: float) -> void:
	if luminance_override >= 0.0:
		luminance = luminance_override
	elif probe_luminance and camera and camera.is_inside_tree():
		luminance = ChomuLightProbe.estimate(get_tree(), camera.global_position, null)
	step(delta)

func step(delta: float) -> float:
	var want := clampf(target_luminance / maxf(luminance, 0.01), min_exposure, max_exposure)
	var rate := adapt_to_bright if want < exposure else adapt_to_dark
	var suppress := 0.0
	if _hold_left > 0.0:
		_hold_left -= delta
		suppress = clampf(hold_curve.sample(1.0 - _hold_left / _hold_total), 0.0, 1.0)
	# exponential approach in log space feels like an eye
	var k := 1.0 - exp(-rate * (1.0 - suppress) * delta)
	exposure = exp(lerpf(log(exposure), log(want), k))
	var final := exposure
	if tension_director:
		final *= 1.0 - tension_darken * tension_director.tension * ChomuSettings.effects_intensity
	if camera_attributes:
		camera_attributes.exposure_multiplier = final
		if camera_attributes.auto_exposure_enabled:
			camera_attributes.auto_exposure_scale = 0.4 * final
	exposure_changed.emit(final)
	return final
