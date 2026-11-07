extends Node
class_name ChomuVariantTracer

## F-30 Shader Variant Pruner
## Traces which materials and shader variants are actually used during playtests.
## Since Godot doesn't expose the internal GPU variant cache, this tracks 
## the high-level resource usage and parameter signatures.

var _traced_variants: Dictionary = {} # path -> Set of signatures

func _init() -> void:
	pass

## Walks the provided node tree and records all active materials and their configurations.
func trace(root: Node) -> void:
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		
		if node is GeometryInstance3D:
			_trace_geometry_instance(node as GeometryInstance3D)
		elif node is CanvasItem:
			_trace_canvas_item(node as CanvasItem)
		
		for child in node.get_children():
			stack.append(child)

func _trace_geometry_instance(gi: GeometryInstance3D) -> void:
	# 1. Material Override
	_record_material(gi.material_override)
	
	# 2. Mesh surface materials
	var mesh: Mesh = gi.mesh
	if mesh:
		for i in mesh.get_surface_count():
			# Surface override
			var surf_mat = gi.get_surface_override_material(i)
			if surf_mat:
				_record_material(surf_mat)
			else:
				# Mesh default
				_record_material(mesh.surface_get_material(i))

func _trace_canvas_item(ci: CanvasItem) -> void:
	_record_material(ci.material)

func _record_material(mat: Material) -> void:
	if not mat:
		return
	
	var path: String = mat.resource_path
	if path == "":
		return # Ignore unique/in-memory materials for pruning lists
	
	if not _traced_variants.has(path):
		_traced_variants[path] = {}
	
	if mat is ShaderMaterial:
		var shader: Shader = mat.shader
		if shader:
			# In Godot 4, ShaderMaterial stores the parameters. 
			# Since we cannot reliably get the parameter list from the Shader resource 
			# via a simple method in all versions, we use the material's current 
			# set of defined parameters as the signature.
			var params: Array[String] = []
			# We iterate through the material's properties to find shader parameters
			# This is a fallback since get_shader_parameter_list is not available on Shader
			# and we want to track what is actually set.
			for p in mat.get_property_list():
				if p.name.begins_with("shader_parameter/"):
					params.append(p.name)
			
			params.sort()
			var signature: String = ",".join(params)
			if signature == "":
				signature = "no_params"
			
			_traced_variants[path][signature] = true
	else:
		_traced_variants[path]["default"] = true

## Saves the current trace to a JSON file.
func save_trace(path: String) -> void:
	var data: Dictionary = {}
	for mat_path in _traced_variants:
		data[mat_path] = _traced_variants[mat_path].keys()
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

## Loads and merges traces from one or more JSON files.
func load_trace(paths: Array[String]) -> void:
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		
		var file := FileAccess.open(path, FileAccess.READ)
		var json_string: String = file.get_as_text()
		file.close()
		
		var data := JSON.parse_string(json_string)
		if typeof(data) != TYPE_DICTIONARY:
			continue
			
		for mat_path in data:
			if not _traced_variants.has(mat_path):
				_traced_variants[mat_path] = {}
			
			var variants: Array = data[mat_path]
			for v in variants:
				_traced_variants[mat_path][v] = true

## Returns a list of material paths from the provided list that were NOT traced.
func unused(all_material_paths: Array[String]) -> Array[String]:
	var unused_list: Array[String] = []
	for path in all_material_paths:
		if not _traced_variants.has(path):
			unused_list.append(path)
	return unused_list

func clear() -> void:
	_traced_variants.clear()
