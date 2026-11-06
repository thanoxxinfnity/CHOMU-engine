class_name ChomuWind
extends Node
## F-57 (part 1) Wind. A CPU wind field: base direction * strength, plus gusts
## and spatial turbulence from FastNoiseLite. Pushes every RigidBody3D in group
## "chomu_wind" with a drag-style force, and publishes a global shader
## parameter `chomu_wind` (vec4 xyz = direction*speed, w = gust 0..1) for
## foliage shaders if the project declares it.
## Not the blueprint's 64^3 GPU wind field; sampled per body on the CPU.

static var instance: ChomuWind

@export var direction := Vector3(1, 0, 0.3)
@export var strength := 4.0          ## m/s base wind speed
@export var gust_strength := 3.0
@export var gust_frequency := 0.15
@export var turbulence := 0.3
@export var drag_coefficient := 0.4
@export var body_group := &"chomu_wind"
@export var noise_seed := 7

var gust := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0

func _ready() -> void:
	instance = self
	_noise.seed = noise_seed
	_noise.frequency = 0.05

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Wind velocity (m/s) at a world point at the current time.
func sample(pos: Vector3) -> Vector3:
	var dir := direction.normalized() if direction.length() > 0.0 else Vector3.RIGHT
	var g := (_noise.get_noise_1d(_t * gust_frequency * 60.0) * 0.5 + 0.5)
	var tx := _noise.get_noise_3d(pos.x, pos.y, pos.z + _t * 4.0)
	var tz := _noise.get_noise_3d(pos.z + 100.0, pos.y, pos.x + _t * 4.0)
	var v := dir * (strength + g * gust_strength)
	v += Vector3(tx, 0.0, tz) * turbulence * strength
	return v

func _physics_process(delta: float) -> void:
	_t += delta
	gust = _noise.get_noise_1d(_t * gust_frequency * 60.0) * 0.5 + 0.5
	var w := sample(Vector3.ZERO)
	if _has_global():
		RenderingServer.global_shader_parameter_set("chomu_wind", Vector4(w.x, w.y, w.z, gust))
	for n in get_tree().get_nodes_in_group(body_group):
		var rb := n as RigidBody3D
		if rb == null or rb.freeze:
			continue
		var rel := sample(rb.global_position) - rb.linear_velocity
		var area: float = rb.get_meta("wind_area", 1.0)
		rb.apply_central_force(rel * rel.length() * drag_coefficient * area * 0.6)

var _global_checked := false
var _global_ok := false
func _has_global() -> bool:
	if not _global_checked:
		_global_checked = true
		_global_ok = RenderingServer.global_shader_parameter_get_list().has(&"chomu_wind")
	return _global_ok
