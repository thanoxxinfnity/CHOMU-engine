extends RefCounted

const Impl := preload("res://addons/chomu_systems/tools/material_infer.gd")

func run(t: Node) -> void:
	# Test 1: Flat color gives flat normal map (~128,128,255) and uniform height
	var flat_img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	flat_img.fill(Color(0.5, 0.3, 0.8, 1.0))  # Solid purple
	
	var height = Impl.height_from_albedo(flat_img)
	t.check("F-22 flat height uniform", _is_uniform(height), "Flat albedo should produce uniform height")
	
	var normal = Impl.normal_from_height(height)
	t.check("F-22 flat normal size", normal.get_width() == 64 and normal.get_height() == 64, "Normal map preserves size")
	t.check("F-22 flat normal value", _is_flat_normal(normal, Color(0.5, 0.5, 1.0, 1.0), 0.02), "Flat height should produce ~(128,128,255) normal")
	
	var roughness = Impl.roughness_from_albedo(flat_img)
	t.check("F-22 flat roughness uniform", _is_uniform(roughness), "Flat albedo should produce uniform roughness")
	t.check("F-22 flat roughness value", _get_avg_luma(roughness) > 0.7, "Flat area should have high roughness (near 1.0)")
	
	# Test 2: Horizontal gradient gives normals tilted in X
	var grad_img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for x in range(64):
		for y in range(64):
			var v = float(x) / 63.0
			grad_img.set_pixel(x, y, Color(v, v, v, 1.0))
	
	var h2 = Impl.height_from_albedo(grad_img)
	var n2 = Impl.normal_from_height(h2)
	
	# Sample center pixel normal - should be tilted in X (red channel != 0.5)
	var center_n = n2.get_pixel(32, 32)
	t.check("F-22 gradient normal X tilt", abs(center_n.r - 0.5) > 0.1, "Horizontal gradient should produce X-tilted normals (red != 0.5), got r=%f" % center_n.r)
	t.check("F-22 gradient normal Y flat", abs(center_n.g - 0.5) < 0.05, "Horizontal gradient should have flat Y (green ~0.5), got g=%f" % center_n.g)
	t.check("F-22 gradient normal Z up", center_n.b > 0.5, "Normal Z should point up (blue > 0.5), got b=%f" % center_n.b)
	
	# Test 3: Image sizes preserved through pipeline
	var infer_result = Impl.infer(grad_img)
	t.check("F-22 infer height size", infer_result["height"].get_width() == 64 and infer_result["height"].get_height() == 64, "Height map preserves size")
	t.check("F-22 infer normal size", infer_result["normal"].get_width() == 64 and infer_result["normal"].get_height() == 64, "Normal map preserves size")
	t.check("F-22 infer roughness size", infer_result["roughness"].get_width() == 64 and infer_result["roughness"].get_height() == 64, "Roughness map preserves size")
	
	# Test 4: make_material produces valid material with textures
	var mat = Impl.make_material(grad_img)
	t.check("F-22 material type", mat is StandardMaterial3D, "make_material returns StandardMaterial3D")
	t.check("F-22 material albedo", mat.albedo_texture != null, "Material has albedo texture")
	t.check("F-22 material normal", mat.normal_texture != null, "Material has normal texture")
	t.check("F-22 material normal enabled", mat.normal_enabled == true, "Material has normal_enabled=true")
	t.check("F-22 material orm", mat.orm_texture != null, "Material has ORM texture for roughness")
	
	# Test 5: Different input formats handled
	var rgb8_img = Image.create(32, 32, false, Image.FORMAT_RGB8)
	rgb8_img.fill(Color(0.2, 0.7, 0.4, 1.0))
	var h3 = Impl.height_from_albedo(rgb8_img)
	t.check("F-22 RGB8 input handled", h3.get_format() == Image.FORMAT_L8, "Non-RGBA8 input converted correctly")
	
	# Test 6: Strength parameter affects normal map
	var h_flat = Impl.height_from_albedo(flat_img)
	var n_low = Impl.normal_from_height(h_flat, 0.5)
	var n_high = Impl.normal_from_height(h_flat, 4.0)
	# On flat height, both should be flat, but test with gradient
	var h_grad = Impl.height_from_albedo(grad_img)
	var n_low_g = Impl.normal_from_height(h_grad, 0.5)
	var n_high_g = Impl.normal_from_height(h_grad, 4.0)
	var diff_low = abs(n_low_g.get_pixel(32, 32).r - 0.5)
	var diff_high = abs(n_high_g.get_pixel(32, 32).r - 0.5)
	t.check("F-22 strength parameter", diff_high > diff_low, "Higher strength produces more tilted normals (diff_high=%f > diff_low=%f)" % [diff_high, diff_low])

func _is_uniform(img: Image) -> bool:
	var first = img.get_pixel(0, 0)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p = img.get_pixel(x, y)
			if abs(p.r - first.r) > 0.005 or abs(p.g - first.g) > 0.005 or abs(p.b - first.b) > 0.005:
				return false
	return true

func _is_flat_normal(img: Image, expected: Color, tol: float) -> bool:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p = img.get_pixel(x, y)
			if abs(p.r - expected.r) > tol or abs(p.g - expected.g) > tol or abs(p.b - expected.b) > tol:
				return false
	return true

func _get_avg_luma(img: Image) -> float:
	var sum = 0.0
	var count = 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p = img.get_pixel(x, y)
			sum += p.r
			count += 1
	return sum / count if count > 0 else 0.0
