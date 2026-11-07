extends RefCounted
class_name ChomuFallbackGraph

## Internal feature entry
class FeatureEntry:
	var name: String
	var requires: Dictionary
	var fallbacks: Array[String]
	
	func _init(p_name: String, p_requires: Dictionary, p_fallbacks: Array[String]) -> void:
		name = p_name
		requires = p_requires
		fallbacks = p_fallbacks


var _features: Dictionary = {}


func register_feature(name: String, requires: Dictionary, fallbacks: Array[String] = []) -> void:
	_features[name] = FeatureEntry.new(name, requires, fallbacks)


func _requirements_met(requires: Dictionary, caps: Dictionary) -> bool:
	for cap_name in requires:
		var required_val = requires[cap_name]
		var actual_val = caps.get(cap_name, false)
		if required_val != actual_val:
			return false
	return true


func _resolve_recursive(name: String, caps: Dictionary, visited: Array[String]) -> String:
	if name in visited:
		return ""
	if not _features.has(name):
		return ""
	
	visited.append(name)
	var entry = _features[name]
	
	if _requirements_met(entry.requires, caps):
		return name
	
	for fallback_name in entry.fallbacks:
		var result = _resolve_recursive(fallback_name, caps, visited)
		if result != "":
			return result
	
	return ""


func resolve(name: String, caps: Dictionary) -> String:
	return _resolve_recursive(name, caps, [])


func resolve_all(caps: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for feature_name in _features:
		result[feature_name] = resolve(feature_name, caps)
	return result


func explain(name: String, caps: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	if not _features.has(name):
		return missing
	
	var entry = _features[name]
	for cap_name in entry.requires:
		var required_val = entry.requires[cap_name]
		var actual_val = caps.get(cap_name, false)
		if required_val != actual_val:
			missing.append(cap_name)
	return missing


static func detect_caps() -> Dictionary:
	var caps: Dictionary = {}
	
	var rendering_method = ProjectSettings.get_setting("rendering/rendering_method/rendering_method")
	caps["forward_plus"] = (rendering_method == "forward_plus")
	caps["compute"] = (rendering_method != "gl_compatibility")
	
	caps["rt"] = false
	caps["bindless"] = false
	caps["mesh_shader"] = false
	
	var os_name = OS.get_name()
	caps["fp16"] = (os_name == "Android" or os_name == "iOS" or rendering_method == "mobile")
	
	caps["volumetric_fog"] = caps["forward_plus"]
	
	return caps


static func default_graph() -> ChomuFallbackGraph:
	var graph = ChomuFallbackGraph.new()
	
	graph.register_feature("gi", {"forward_plus": true}, ["voxel_gi", "lightmap_gi", "ambient_only"])
	graph.register_feature("voxel_gi", {"compute": true}, ["lightmap_gi", "ambient_only"])
	graph.register_feature("lightmap_gi", {}, ["ambient_only"])
	graph.register_feature("ambient_only", {}, [])
	
	graph.register_feature("ssr", {"compute": true}, ["cubemap"])
	graph.register_feature("cubemap", {}, [])
	
	graph.register_feature("fsr", {"compute": true}, ["bilinear"])
	graph.register_feature("bilinear", {}, [])
	
	graph.register_feature("volumetric_fog", {"forward_plus": true, "compute": true}, ["height_fog"])
	graph.register_feature("height_fog", {}, [])
	
	return graph
