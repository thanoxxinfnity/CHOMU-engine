class_name ChomuWater
extends Node3D
## F-57 (part 2) Water surface: sum of directional sine waves (cheap stand-in
## for the blueprint's FFT ocean) with a height query used by ChomuBuoyancy.
## Optionally builds a flat preview mesh (neutral blue-grey, no shader needed).

static var instance: ChomuWater

@export var base_height := 0.0
@export var waves: Array[Vector4] = [  ## (dir_x, dir_z, amplitude, wavelength)
	Vector4(1, 0.2, 0.25, 9.0), Vector4(0.3, 1, 0.12, 4.5), Vector4(-0.7, 0.6, 0.06, 2.1)]
@export var speed := 1.0
@export var density := 1000.0
@export var make_mesh := true
@export var mesh_size := 60.0

var time := 0.0

func _ready() -> void:
	instance = self
	if make_mesh:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(mesh_size, mesh_size)
		mi.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.12, 0.22, 0.30, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
		mi.material_override = m
		add_child(mi)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _physics_process(delta: float) -> void:
	time += delta
	var mi := get_child(0) as MeshInstance3D if get_child_count() > 0 else null
	if mi:
		mi.position.y = height_at(global_position.x, global_position.z) - global_position.y

func height_at(x: float, z: float) -> float:
	var h := global_position.y + base_height
	for w in waves:
		var d := Vector2(w.x, w.y).normalized()
		var k := TAU / maxf(w.w, 0.01)
		var c := sqrt(9.81 / k) * speed
		h += w.z * sin(k * (d.x * x + d.y * z) - c * k * time)
	return h
