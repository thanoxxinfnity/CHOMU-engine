extends RefCounted
const Impl := preload("res://addons/chomu_systems/tools/texture_budget.gd")

func run(t: Node) -> void:
	# Test 1: SSIM of identical images is 1.0
	var img1: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img1.fill(Color(0.5, 0.5, 0.5, 1.0))
	var ssim_identical: float = Impl.ssim(img1, img1)
	t.check("F-29 SSIM identical images = 1.0", ssim_identical == 1.0, "SSIM of identical images should be 1.0, got %s" % ssim_identical)
	
	# Test 2: Noise image loses more SSIM from degrade than smooth gradient
	var noise_img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var gradient_img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	for y in range(64):
		for x in range(64):
			noise_img.set_pixel(x, y, Color(randf(), randf(), randf(), 1.0))
			gradient_img.set_pixel(x, y, Color(float(x) / 64.0, float(y) / 64.0, 0.5, 1.0))
	
	var noise_degraded: Image = Impl.degrade(noise_img, 1)
	var gradient_degraded: Image = Impl.degrade(gradient_img, 1)
	
	var ssim_noise: float = Impl.ssim(noise_img, noise_degraded)
	var ssim_gradient: float = Impl.ssim(gradient_img, gradient_degraded)
	
	t.check("F-29 Noise loses more SSIM than gradient", ssim_noise < ssim_gradient, 
		"Noise SSIM: %s, Gradient SSIM: %s" % [ssim_noise, ssim_gradient])
	
	# Test 3: Optimize fits the budget
	var textures: Array = [
		{id = "tex1", image = gradient_img, importance = 1.0},
		{id = "tex2", image = noise_img, importance = 1.0}
	]
	
	# Calculate total bytes at level 0
	var total_bytes: int = 64 * 64 * 4 + 64 * 64 * 4  # 32768 bytes
	var budget: int = 16384  # Half the total
	
	var result: Dictionary = Impl.optimize(textures, budget)
	
	# Verify budget is met
	var final_bytes: int = 0
	for tex in textures:
		var id: String = tex.id
		var level: int = result.get(id, 0)
		var w: int = tex.image.get_width()
		var h: int = tex.image.get_height()
		var bytes: int = (w * h * 4) >> (level * 2)
		final_bytes += bytes
	
	t.check("F-29 Optimize fits budget", final_bytes <= budget, 
		"Final bytes: %s, Budget: %s" % [final_bytes, budget])
	
	# Test 4: Smooth/low-importance texture degraded first
	# Create textures with different importances
	var smooth_tex: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var complex_tex: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	
	for y in range(64):
		for x in range(64):
			smooth_tex.set_pixel(x, y, Color(0.5, 0.5, 0.5, 1.0))
			complex_tex.set_pixel(x, y, Color(randf(), randf(), randf(), 1.0))
	
	var textures2: Array = [
		{id = "smooth", image = smooth_tex, importance = 0.5},
		{id = "complex", image = complex_tex, importance = 1.0}
	]
	
	# Set budget to force one texture to degrade
	var budget2: int = 64 * 64 * 4  # Only enough for one full texture
	var result2: Dictionary = Impl.optimize(textures2, budget2)
	
	# The smooth texture should have higher level (more degraded)
	t.check("F-29 Smooth texture degraded first", result2.get("smooth", 0) > result2.get("complex", 0),
		"Smooth level: %s, Complex level: %s" % [result2.get("smooth", 0), result2.get("complex", 0)])
	
	# Test 5: Degrade with level 0 returns copy
	var degraded_copy: Image = Impl.degrade(img1, 0)
	t.check("F-29 Degrade level 0 returns copy", degraded_copy.get_width() == img1.get_width() and degraded_copy.get_height() == img1.get_height(),
		"Degrade level 0 should return same size image")
	
	# Test 6: Empty textures array returns empty dictionary
	var empty_result: Dictionary = Impl.optimize([], 1000)
	t.check("F-29 Empty textures returns empty dict", empty_result.is_empty(), "Empty textures should return empty result")
	
	# Test 7: SSIM with different sized images returns 0
	var small_img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var ssim_diff_size: float = Impl.ssim(img1, small_img)
	t.check("F-29 SSIM different sizes returns 0", ssim_diff_size == 0.0, "SSIM of different sized images should be 0")
