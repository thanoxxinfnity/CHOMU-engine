@tool
extends CanvasLayer
## CHoMU Ultra post-process layer: one full-screen pass (shaders/post_grade.gdshader) that does
## LUT colour grading, lift/gamma/gain, contrast, saturation, sharpen, vignette, film grain and chromatic aberration,
## plus an optional additive lens-flare pass. Works on Forward+, Mobile and Compatibility (canvas screen texture).
## Put your game UI on a CanvasLayer with a higher `layer` than this one (default 100) so it is not graded.

const GRADE_SHADER := preload("res://addons/chomu_ultra/shaders/post_grade.gdshader")
const FLARE_SHADER := preload("res://addons/chomu_ultra/shaders/lens_flare.gdshader")
const FLARE_SCRIPT := preload("res://addons/chomu_ultra/post/lens_flare.gd")

## Last applied parameters (saved with the scene, re-applied on load).
@export var params: Dictionary = {}

var _grade: ColorRect
var _flare: ColorRect

func _init() -> void:
	layer = 100

func _ready() -> void:
	_ensure()
	if not params.is_empty():
		configure(params)

func _ensure() -> void:
	if not is_instance_valid(_flare):
		_flare = get_node_or_null("Flare") as ColorRect
		if _flare == null:
			_flare = ColorRect.new()
			_flare.name = "Flare"
			_flare.set_script(FLARE_SCRIPT)
			_setup_rect(_flare, FLARE_SHADER)
			add_child(_flare)
	if not is_instance_valid(_grade):
		_grade = get_node_or_null("Grade") as ColorRect
		if _grade == null:
			_grade = ColorRect.new()
			_grade.name = "Grade"
			_setup_rect(_grade, GRADE_SHADER)
			add_child(_grade)

func _setup_rect(r: ColorRect, sh: Shader) -> void:
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color.WHITE
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m

## d: {"enabled", "flare", "lut_path", plus any uniform of post_grade.gdshader}
func configure(d: Dictionary) -> void:
	params = d.duplicate()
	_ensure()
	var on := bool(d.get("enabled", false))
	_grade.visible = on
	_flare.visible = on and bool(d.get("flare", false))
	var m := _grade.material as ShaderMaterial
	var lut_path := str(d.get("lut_path", ""))
	if lut_path != "" and ResourceLoader.exists(lut_path):
		m.set_shader_parameter("lut_tex", load(lut_path))
		m.set_shader_parameter("use_lut", bool(d.get("use_lut", true)))
	else:
		m.set_shader_parameter("use_lut", false)
	for k in d:
		if k in ["enabled", "flare", "lut_path", "use_lut"]:
			continue
		m.set_shader_parameter(k, d[k])

func set_param(uniform_name: String, value: Variant) -> void:
	_ensure()
	params[uniform_name] = value
	(_grade.material as ShaderMaterial).set_shader_parameter(uniform_name, value)
