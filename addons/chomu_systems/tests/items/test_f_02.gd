extends RefCounted
const Impl := preload("res://addons/chomu_systems/core/fallback_graph.gd")

func run(t: Node) -> void:
	var graph = Impl.default_graph()
	
	# Test 1: With all caps, each feature resolves to itself
	var full_caps = {
		"forward_plus": true,
		"compute": true,
		"rt": false,
		"bindless": false,
		"mesh_shader": false,
		"fp16": true,
		"volumetric_fog": true
	}
	
	t.check("F-02 gi resolves to itself with forward_plus", graph.resolve("gi", full_caps) == "gi", "gi should resolve to itself when forward_plus is available")
	t.check("F-02 voxel_gi resolves to itself with compute", graph.resolve("voxel_gi", full_caps) == "voxel_gi", "voxel_gi should resolve to itself when compute is available")
	t.check("F-02 ssr resolves to itself with compute", graph.resolve("ssr", full_caps) == "ssr", "ssr should resolve to itself when compute is available")
	t.check("F-02 fsr resolves to itself with compute", graph.resolve("fsr", full_caps) == "fsr", "fsr should resolve to itself when compute is available")
	t.check("F-02 volumetric_fog resolves to itself with forward_plus and compute", graph.resolve("volumetric_fog", full_caps) == "volumetric_fog", "volumetric_fog should resolve to itself when both caps are available")
	
	# Test 2: Without forward_plus, gi falls down the chain
	var no_forward_plus = full_caps.duplicate()
	no_forward_plus["forward_plus"] = false
	no_forward_plus["volumetric_fog"] = false
	
	t.check("F-02 gi falls back to voxel_gi without forward_plus", graph.resolve("gi", no_forward_plus) == "voxel_gi", "gi should fallback to voxel_gi when forward_plus is missing")
	
	var no_compute = full_caps.duplicate()
	no_compute["compute"] = false
	
	t.check("F-02 voxel_gi falls back to lightmap_gi without compute", graph.resolve("voxel_gi", no_compute) == "lightmap_gi", "voxel_gi should fallback to lightmap_gi when compute is missing")
	t.check("F-02 ssr falls back to cubemap without compute", graph.resolve("ssr", no_compute) == "cubemap", "ssr should fallback to cubemap when compute is missing")
	t.check("F-02 fsr falls back to bilinear without compute", graph.resolve("fsr", no_compute) == "bilinear", "fsr should fallback to bilinear when compute is missing")
	t.check("F-02 volumetric_fog falls back to height_fog without forward_plus", graph.resolve("volumetric_fog", no_forward_plus) == "height_fog", "volumetric_fog should fallback to height_fog when forward_plus is missing")
	
	# Test 3: Without forward_plus AND compute, gi falls to lightmap_gi
	var no_forward_no_compute = full_caps.duplicate()
	no_forward_no_compute["forward_plus"] = false
	no_forward_no_compute["compute"] = false
	no_forward_no_compute["volumetric_fog"] = false
	t.check("F-02 gi falls back to lightmap_gi without forward_plus and compute", graph.resolve("gi", no_forward_no_compute) == "lightmap_gi", "gi should fallback to lightmap_gi when both forward_plus and compute are missing")
	
	# Test 4: Cycle detection returns empty string when fallback chain cycles and feature not satisfied
	var cycle_graph = Impl.new()
	cycle_graph.register_feature("a", {"rt": true}, ["b"])  # requires rt (false in full_caps)
	cycle_graph.register_feature("b", {"rt": true}, ["a"])  # requires rt (false)
	t.check("F-02 cycle returns empty string", cycle_graph.resolve("a", full_caps) == "", "Cycle between a and b with unmet requirements should return empty string")
	
	# Test 5: explain lists missing caps
	var missing = graph.explain("gi", no_forward_plus)
	t.check("F-02 explain lists forward_plus as missing for gi", missing.has("forward_plus"), "explain should list forward_plus as missing for gi")
	
	var missing_ssr = graph.explain("ssr", no_compute)
	t.check("F-02 explain lists compute as missing for ssr", missing_ssr.has("compute"), "explain should list compute as missing for ssr")
	
	var missing_vol = graph.explain("volumetric_fog", no_forward_plus)
	t.check("F-02 explain lists forward_plus as missing for volumetric_fog", missing_vol.has("forward_plus"), "explain should list forward_plus as missing for volumetric_fog")
	
	# Test 6: detect_caps in headless Compatibility project gives forward_plus false
	var detected = Impl.detect_caps()
	t.check("F-02 detect_caps returns forward_plus false in Compatibility", detected["forward_plus"] == false, "detect_caps should return forward_plus=false in Compatibility renderer")
	t.check("F-02 detect_caps returns compute true in Compatibility", detected["compute"] == true, "detect_caps should return compute=true in Compatibility renderer (not gl_compatibility)")
	t.check("F-02 detect_caps returns rt/bindless/mesh_shader false", not detected["rt"] and not detected["bindless"] and not detected["mesh_shader"], "detect_caps should return rt/bindless/mesh_shader as false")
	
	# Test 7: resolve_all returns dict for all features (10 features in default graph)
	var all_resolved = graph.resolve_all(full_caps)
	t.check("F-02 resolve_all returns dict with all features", all_resolved.size() == 10, "resolve_all should return entries for all 10 registered features")
	t.check("F-02 resolve_all gi is gi", all_resolved["gi"] == "gi", "resolve_all should resolve gi to itself with full caps")
	t.check("F-02 resolve_all ambient_only is ambient_only", all_resolved["ambient_only"] == "ambient_only", "resolve_all should resolve ambient_only to itself")
	
	# Test 8: Unknown feature returns empty string
	t.check("F-02 unknown feature returns empty", graph.resolve("unknown_feature", full_caps) == "", "Unknown feature should return empty string")
	
	# Test 9: Feature with no fallbacks and unmet requirements returns empty
	var minimal_graph = Impl.new()
	minimal_graph.register_feature("strict", {"rt": true}, [])
	t.check("F-02 strict feature with unmet req returns empty", minimal_graph.resolve("strict", full_caps) == "", "Feature with unmet requirements and no fallbacks should return empty string")
