extends RefCounted

const Impl := preload("res://addons/chomu_systems/tools/variant_tracer.gd")

func run(t: Node) -> void:
	var tracer := Impl.new()
	t.add_child(tracer)
	
	# Setup: Create 3 materials as files in user://
	var mat_paths: Array[String] = []
	for i in range(3):
		var m := ShaderMaterial.new()
		var s := Shader.new()
		s.code = "shader_type spatial; void fragment() { ALBEDO = vec3(1.0); }"
		m.shader = s
		var p := "user://test_mat_%d.tres" % i
		ResourceSaver.save(m, p)
		mat_paths.append(p)
	
	# Create scene: 3 MeshInstances, but only use 2 of the materials
	var root := Node3D.new()
	t.add_child(root)
	
	var mi1 := MeshInstance3D.new()
	mi1.mesh = BoxMesh.new()
	mi1.material_override = load(mat_paths[0])
	root.add_child(mi1)
	
	var mi2 := MeshInstance3D.new()
	mi2.mesh = BoxMesh.new()
	mi2.material_override = load(mat_paths[1])
	root.add_child(mi2)
	
	var mi3 := MeshInstance3D.new()
	mi3.mesh = BoxMesh.new()
	mi3.material_override = load(mat_paths[1])
	root.add_child(mi3)
	
	# Test 1: Basic tracing
	tracer.trace(root)
	var unused := tracer.unused(mat_paths)
	t.check("F-30 trace finds used materials", unused.size() == 1, "Should have 1 unused material")
	t.check("F-30 identifies correct unused material", unused[0] == mat_paths[2], "Material 2 should be unused")
	
	# Test 2: Save and Load merge
	var trace_file := "user://trace_f30.json"
	tracer.save_trace(trace_file)
	
	var tracer2 := Impl.new()
	t.add_child(tracer2)
	tracer2.load_trace([trace_file])
	var unused2 := tracer2.unused(mat_paths)
	t.check("F-30 load_trace restores state", unused2.size() == 1, "Loaded tracer should also see 1 unused")
	
	# Test 3: Merging multiple traces
	var tracer3 := Impl.new()
	t.add_child(tracer3)
	var root2 := Node3D.new()
	t.add_child(root2)
	var mi4 := MeshInstance3D.new()
	mi4.mesh = BoxMesh.new()
	mi4.material_override = load(mat_paths[2])
	root2.add_child(mi4)
	
	tracer3.trace(root2)
	var trace_file2 := "user://trace_f30_2.json"
	tracer3.save_trace(trace_file2)
	
	# Merge both into tracer2
	tracer2.load_trace([trace_file, trace_file2])
	var unused_merged := tracer2.unused(mat_paths)
	t.check("F-30 merged traces union correctly", unused_merged.size() == 0, "All materials should now be used")
	
	# Cleanup
	root.queue_free()
	root2.queue_free()
	tracer.queue_free()
	tracer2.queue_free()
	tracer3.queue_free()
	for p in mat_paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if FileAccess.file_exists(trace_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(trace_file))
	if FileAccess.file_exists(trace_file2):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(trace_file2))
