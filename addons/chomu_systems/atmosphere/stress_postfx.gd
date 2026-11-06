class_name ChomuStressPostFX
extends CanvasLayer
## F-46 Stress post-FX: vignette, chromatic aberration, grain, desaturation and
## FOV breathing, all scaled by `stress` (0..1, usually TensionDirector.tension).
## Photosensitivity-safe mode (ChomuSettings.photosensitivity_safe or
## `safe_mode`): aberration capped very low, breathing slowed to <0.5 Hz and
## shallow, grain off, and the stress value is slew-limited so nothing pulses.

const SHADER := preload("res://addons/chomu_systems/shaders/stress_postfx.gdshader")

@export var tension_director: ChomuTensionDirector
@export var camera: Camera3D
@export var safe_mode := false
@export var max_vignette := 0.9
@export var max_aberration := 0.012
@export var max_grain := 0.08
@export var max_desaturate := 0.45
@export var breathing_fov := 2.5      ## degrees at full stress
@export var breathing_hz := 0.9       ## breaths per second at full stress

var stress := 0.0
var stress_input := 0.0
var _rect: ColorRect
var _mat: ShaderMaterial
var _base_fov := -1.0
var _phase := 0.0

func _ready() -> void:
	layer = 90
	_rect = ColorRect.new()
	_rect.name = "StressFX"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)

func is_safe() -> bool:
	return safe_mode or ChomuSettings.photosensitivity_safe

func _process(delta: float) -> void:
	if tension_director:
		stress_input = tension_director.tension
	step(delta)

func step(delta: float) -> void:
	var target := clampf(stress_input, 0.0, 1.0) * ChomuSettings.effects_intensity
	var slew := 0.4 if is_safe() else 3.0
	stress = move_toward(stress, target, slew * delta)
	var s := stress
	var ab := max_aberration * s * s
	var gr := max_grain * s
	var breathe_amp := breathing_fov * s
	var breathe_hz := lerpf(0.25, breathing_hz, s)
	if is_safe():
		ab = minf(ab, 0.002)
		gr = 0.0
		breathe_amp = minf(breathe_amp, 0.8)
		breathe_hz = minf(breathe_hz, 0.4)
	if _mat:
		_mat.set_shader_parameter("vignette", 0.25 + max_vignette * s)
		_mat.set_shader_parameter("aberration", ab)
		_mat.set_shader_parameter("grain", gr)
		_mat.set_shader_parameter("desaturate", max_desaturate * s)
	if camera:
		if _base_fov < 0.0:
			_base_fov = camera.fov
		_phase = fmod(_phase + breathe_hz * delta, 1.0)
		camera.fov = _base_fov + sin(_phase * TAU) * breathe_amp - s * 3.0

func current_params() -> Dictionary:
	if _mat == null:
		return {}
	return {"vignette": _mat.get_shader_parameter("vignette"), "aberration": _mat.get_shader_parameter("aberration"), "grain": _mat.get_shader_parameter("grain")}
