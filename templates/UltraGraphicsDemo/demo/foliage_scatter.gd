@tool
extends MultiMeshInstance3D
## Builds the MultiMesh from a baked transform buffer (12 floats per instance, MultiMesh buffer layout).
## Kept as plain data so the scene stays small and loads identically on every renderer.

@export var mesh: Mesh
@export var transforms: PackedFloat32Array = PackedFloat32Array()
## Fraction of instances to draw (lower on Low preset to save fill-rate).
@export_range(0.05, 1.0) var density := 1.0:
	set(v):
		density = v
		if multimesh:
			multimesh.visible_instance_count = int(multimesh.instance_count * density)

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	if mesh == null or transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size() / 12
	mm.buffer = transforms
	mm.visible_instance_count = int(mm.instance_count * density)
	multimesh = mm
