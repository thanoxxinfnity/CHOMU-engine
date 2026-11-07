extends Node3D
class_name ChomuHLOD

## Distance at which original meshes are hidden and proxy is shown.
@export var hlod_distance: float = 50.0
## Distance at which proxy is hidden and impostor is shown (if available).
@export var impostor_distance: float = 200.0
## Optional impostor texture (billboard quad uses this).
@export var impostor_texture: Texture2D

## Internal: original mesh instances found under this node.
var _originals: Array[MeshInstance3D] = []
## Internal: the merged proxy mesh instance.
var _proxy: MeshInstance3D
## Internal: the impostor billboard mesh instance.
var _impostor: MeshInstance3D
## Internal: current LOD level (0=originals, 1=proxy, 2=impostor).
var _current_level: int = 0
## Internal: last distance used for hysteresis.
var _last_distance: float = -1.0

func _ready() -> void:
	_originals = _collect_originals()
	_build_proxy()
	_build_impostor()
	_set_visibility(0)

func _collect_originals() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in get_children():
		_collect_recursive(child, result)
	return result

func _collect_recursive(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node != _proxy and node != _impostor:
		out.append(node)
	for child in node.get_children():
		_collect_recursive(child, out)

func build_proxy() -> void:
	_build_proxy()

func _build_proxy() -> void:
	_originals = _collect_originals()
	if _proxy:
		_proxy.queue_free()
		_proxy = null
	
	var st_by_mat: Dictionary = {}
	for mi in _originals:
		var mesh: Mesh = mi.mesh
		if not mesh:
			continue
		# Transform from mesh local space to HLOD local space
		var xform: Transform3D = global_transform.affine_inverse() * mi.global_transform
		for surf_idx in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surf_idx)
			if arrays.size() == 0:
				continue
			var mat: Material = mesh.surface_get_material(surf_idx)
			var key: Variant = mat if mat else "default"
			if not st_by_mat.has(key):
				st_by_mat[key] = SurfaceTool.new()
			var st: SurfaceTool = st_by_mat[key]
			st.append_from(mesh, surf_idx, xform)
	
	var proxy_mesh: ArrayMesh = ArrayMesh.new()
	for key in st_by_mat:
		var st: SurfaceTool = st_by_mat[key]
		var arrays: Array = st.commit_to_arrays()
		var mat: Material = key if key is Material else null
		var surf_idx: int = proxy_mesh.get_surface_count()
		# PRIMITIVES_TRIANGLES = 4? Actually Mesh.PRIMITIVES_TRIANGLES = 4 in Godot 4? Wait, RenderingServer.PRIMITIVES_TRIANGLES = 4.
		# But ArrayMesh.add_surface_from_arrays expects the primitive type as int. Use 4 for triangles.
		proxy_mesh.add_surface_from_arrays(4, arrays, [], {})
		if mat:
			proxy_mesh.surface_set_material(surf_idx, mat)
	
	_proxy = MeshInstance3D.new()
	_proxy.name = "HLODProxy"
	_proxy.mesh = proxy_mesh
	_proxy.visible = false
	add_child(_proxy)

func _build_impostor() -> void:
	if _impostor:
		_impostor.queue_free()
		_impostor = null
	
	if not impostor_texture:
		return
	
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(10.0, 10.0)
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = impostor_texture
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	_impostor = MeshInstance3D.new()
	_impostor.name = "HLODImpostor"
	_impostor.mesh = quad
	_impostor.material_override = mat
	_impostor.visible = false
	add_child(_impostor)

func update_lod(camera_pos: Vector3) -> void:
	var dist: float = global_position.distance_to(camera_pos)
	var hys: float = 0.05
	
	var target_level: int = _current_level
	
	if _last_distance < 0.0:
		# First frame: choose level by distance bands without hysteresis
		if dist < hlod_distance:
			target_level = 0
		elif dist < impostor_distance:
			target_level = 1
		else:
			target_level = 2 if _impostor else 1
	else:
		# Hysteresis state machine
		match _current_level:
			0:
				if dist > hlod_distance * (1.0 + hys):
					target_level = 1
			1:
				if dist < hlod_distance * (1.0 - hys):
					target_level = 0
				elif dist > impostor_distance * (1.0 + hys) and _impostor:
					target_level = 2
			2:
				if dist < impostor_distance * (1.0 - hys):
					target_level = 1
	
	if target_level != _current_level:
		_set_visibility(target_level)
		_current_level = target_level
	
	_last_distance = dist

func _set_visibility(level: int) -> void:
	for mi in _originals:
		if is_instance_valid(mi):
			mi.visible = (level == 0)
	if is_instance_valid(_proxy):
		_proxy.visible = (level == 1)
	if is_instance_valid(_impostor):
		_impostor.visible = (level == 2)

func level() -> int:
	return _current_level

func get_proxy_vertex_count() -> int:
	if not _proxy or not _proxy.mesh:
		return 0
	var total: int = 0
	var mesh: ArrayMesh = _proxy.mesh as ArrayMesh
	for i in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(i)
		if arrays.size() > Mesh.ARRAY_VERTEX:
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += verts.size()
	return total
