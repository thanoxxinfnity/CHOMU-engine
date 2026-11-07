extends RefCounted
class_name ChomuTextureBudget

# SSIM constants for 8x8 window comparison
const K1: float = 0.01
const K2: float = 0.03
const L: float = 255.0

static func ssim(a: Image, b: Image) -> float:
	"""Compute SSIM between two images using 8x8 windows, grayscale comparison."""
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return 0.0
	
	var width: int = a.get_width()
	var height: int = a.get_height()
	var total_ssim: float = 0.0
	var window_count: int = 0
	
	for y in range(0, height - 7, 8):
		for x in range(0, width - 7, 8):
			var ssim_val: float = _compute_window_ssim(a, b, x, y)
			total_ssim += ssim_val
			window_count += 1
	
	if window_count == 0:
		return 1.0
	
	return total_ssim / window_count

static func _compute_window_ssim(a: Image, b: Image, x: int, y: int) -> float:
	"""Compute SSIM for an 8x8 window at position (x, y)."""
	var sum_a: float = 0.0
	var sum_b: float = 0.0
	var sum_a2: float = 0.0
	var sum_b2: float = 0.0
	var sum_ab: float = 0.0
	
	for dy in range(8):
		for dx in range(8):
			var pixel_a: Color = a.get_pixel(x + dx, y + dy)
			var pixel_b: Color = b.get_pixel(x + dx, y + dy)
			
			# Convert to grayscale luminance
			var lum_a: float = pixel_a.r * 0.299 + pixel_a.g * 0.587 + pixel_a.b * 0.114
			var lum_b: float = pixel_b.r * 0.299 + pixel_b.g * 0.587 + pixel_b.b * 0.114
			
			sum_a += lum_a
			sum_b += lum_b
			sum_a2 += lum_a * lum_a
			sum_b2 += lum_b * lum_b
			sum_ab += lum_a * lum_b
	
	var n: int = 64
	var mean_a: float = sum_a / n
	var mean_b: float = sum_b / n
	var var_a: float = (sum_a2 / n) - (mean_a * mean_a)
	var var_b: float = (sum_b2 / n) - (mean_b * mean_b)
	var cov_ab: float = (sum_ab / n) - (mean_a * mean_b)
	
	var c1: float = (K1 * L) * (K1 * L)
	var c2: float = (K2 * L) * (K2 * L)
	
	var numerator: float = (2.0 * mean_a * mean_b + c1) * (2.0 * cov_ab + c2)
	var denominator: float = (mean_a * mean_a + mean_b * mean_b + c1) * (var_a + var_b + c2)
	
	if denominator == 0.0:
		return 1.0
	
	return numerator / denominator

static func degrade(img: Image, level: int) -> Image:
	"""Downscale by 2^level then upscale back to original size."""
	if level <= 0:
		return img.duplicate()
	
	var width: int = img.get_width()
	var height: int = img.get_height()
	
	# Calculate downscaled dimensions
	var ds_width: int = max(1, width >> level)
	var ds_height: int = max(1, height >> level)
	
	# Downscale using resize (simulates downscale)
	var downscaled: Image = Image.create(ds_width, ds_height, false, img.get_format())
	downscaled.resize(ds_width, ds_height)
	
	# Copy pixels manually from original to downscaled
	for y in range(ds_height):
		for x in range(ds_width):
			var src_x: int = (x * width) / ds_width
			var src_y: int = (y * height) / ds_height
			downscaled.set_pixel(x, y, img.get_pixel(src_x, src_y))
	
	# Upscale back to original size using resize
	var result: Image = Image.create(width, height, false, img.get_format())
	result.resize(width, height)
	
	# Copy pixels from downscaled to result (upscaling)
	for y in range(height):
		for x in range(width):
			var src_x: int = (x * ds_width) / width
			var src_y: int = (y * ds_height) / height
			result.set_pixel(x, y, downscaled.get_pixel(src_x, src_y))
	
	return result

static func optimize(textures: Array, budget_bytes: int) -> Dictionary:
	"""
	Greedily increase degradation level until RGBA8 total bytes fit budget.
	Returns Dictionary mapping id -> level.
	"""
	if textures.is_empty():
		return {}
	
	# Initialize: all textures at level 0
	var result: Dictionary = {}
	var current_bytes: int = 0
	
	# Calculate initial bytes and prepare for optimization
	var texture_data: Array = []
	for tex in textures:
		var id: String = tex.id
		var img: Image = tex.image
		var importance: float = tex.importance
		
		var w: int = img.get_width()
		var h: int = img.get_height()
		var base_bytes: int = w * h * 4  # RGBA8
		
		result[id] = 0
		current_bytes += base_bytes
		
		texture_data.append({
			"id": id,
			"image": img,
			"importance": importance,
			"level": 0,
			"base_bytes": base_bytes
		})
	
	# If already under budget, return
	if current_bytes <= budget_bytes:
		return result
	
	# Greedily increase level of texture with smallest importance-weighted SSIM loss per byte saved
	while current_bytes > budget_bytes:
		var best_candidate: Dictionary = {}
		var best_ratio: float = INF
		
		for tex in texture_data:
			var current_level: int = tex.level
			var next_level: int = current_level + 1
			
			# Calculate bytes saved by increasing level
			var bytes_at_current: int = tex.base_bytes >> (current_level * 2)
			var bytes_at_next: int = tex.base_bytes >> (next_level * 2)
			var bytes_saved: int = bytes_at_current - bytes_at_next
			
			if bytes_saved <= 0:
				continue
			
			# Calculate SSIM loss
			var degraded: Image = degrade(tex.image, next_level)
			var ssim_val: float = ssim(tex.image, degraded)
			var ssim_loss: float = 1.0 - ssim_val
			
			# Importance-weighted SSIM loss per byte saved
			var weighted_loss: float = ssim_loss * tex.importance
			var ratio: float = weighted_loss / float(bytes_saved)
			
			if ratio < best_ratio:
				best_ratio = ratio
				best_candidate = tex
	
		# Apply best candidate
		if best_candidate.is_empty():
			break
		
		var tex_id: String = best_candidate.id
		var old_level: int = best_candidate.level
		var new_level: int = old_level + 1
		
		var old_bytes: int = best_candidate.base_bytes >> (old_level * 2)
		var new_bytes: int = best_candidate.base_bytes >> (new_level * 2)
		
		result[tex_id] = new_level
		best_candidate.level = new_level
		current_bytes -= (old_bytes - new_bytes)
	
	return result
