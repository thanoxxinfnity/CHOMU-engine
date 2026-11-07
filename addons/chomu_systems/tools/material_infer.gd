extends RefCounted
class_name ChomuMaterialInfer

## Converts an albedo image to a height map (luminance, normalized to full range).
## @param img Source albedo image (any format, will be converted to RGBA8 internally)
## @return Image in FORMAT_L8 with height data (0..255)
static func height_from_albedo(img: Image) -> Image:
	var src = img.duplicate()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	
	var w = src.get_width()
	var h = src.get_height()
	var dst = Image.create(w, h, false, Image.FORMAT_L8)
	
	# First pass: find min/max luminance
	var min_lum = 1.0
	var max_lum = 0.0
	for y in range(h):
		for x in range(w):
			var c = src.get_pixel(x, y)
			var lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			if lum < min_lum:
				min_lum = lum
			if lum > max_lum:
				max_lum = lum
	
	# Second pass: normalize and write
	var range = max_lum - min_lum
	if range < 0.0001:
		# Flat image: fill with mid-gray
		dst.fill(Color(0.5, 0.5, 0.5, 1.0))
	else:
		for y in range(h):
			for x in range(w):
				var c = src.get_pixel(x, y)
				var lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				var norm = (lum - min_lum) / range
				dst.set_pixel(x, y, Color(norm, norm, norm, 1.0))
	
	return dst

## Generates a tangent-space normal map from a height map using Sobel operator.
## @param h Height map image (FORMAT_L8 or any, will be converted)
## @param strength Normal strength multiplier (default 2.0)
## @return Image in FORMAT_RGB8 with normals encoded as 0.5 + 0.5 * normal
static func normal_from_height(h: Image, strength: float = 2.0) -> Image:
	var src = h.duplicate()
	if src.get_format() != Image.FORMAT_L8:
		src.convert(Image.FORMAT_L8)
	
	var w = src.get_width()
	var hgt = src.get_height()
	var dst = Image.create(w, hgt, false, Image.FORMAT_RGB8)
	
	# Correct Sobel kernels
	# Gx = [-1 0 1; -2 0 2; -1 0 1]
	# Gy = [-1 -2 -1; 0 0 0; 1 2 1]
	var gx_kernel = [
		[-1, 0, 1],
		[-2, 0, 2],
		[-1, 0, 1]
	]
	var gy_kernel = [
		[-1, -2, -1],
		[0, 0, 0],
		[1, 2, 1]
	]
	
	for y in range(hgt):
		for x in range(w):
			var gx = 0.0
			var gy = 0.0
			
			# Sample 3x3 neighborhood with clamping
			for ky in range(-1, 2):
				for kx in range(-1, 2):
					var sx = clamp(x + kx, 0, w - 1)
					var sy = clamp(y + ky, 0, hgt - 1)
					var h_val = src.get_pixel(sx, sy).r
					
					gx += h_val * gx_kernel[ky + 1][kx + 1]
					gy += h_val * gy_kernel[ky + 1][kx + 1]
			
			# Scale by strength and normalize
			gx *= strength
			gy *= strength
			
			# Tangent space normal: (-gx, -gy, 1) normalized
			var nz = 1.0
			var len = sqrt(gx * gx + gy * gy + nz * nz)
			var nx = -gx / len
			var ny = -gy / len
			nz = nz / len
			
			# Encode to 0..1 range: 0.5 + 0.5 * normal
			var r = 0.5 + 0.5 * nx
			var g = 0.5 + 0.5 * ny
			var b = 0.5 + 0.5 * nz
			
			dst.set_pixel(x, y, Color(r, g, b, 1.0))
	
	return dst

## Estimates roughness from albedo based on local contrast.
## High local contrast -> lower roughness (more detail), base range 0.6..1.0.
## @param img Source albedo image
## @param radius Sampling radius for local contrast (default 1)
## @return Image in FORMAT_L8 with roughness data (0..255)
static func roughness_from_albedo(img: Image, radius: int = 1) -> Image:
	var src = img.duplicate()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	
	var w = src.get_width()
	var h = src.get_height()
	var dst = Image.create(w, h, false, Image.FORMAT_L8)
	
	# Precompute luminance buffer
	var lum_buf = []
	lum_buf.resize(w * h)
	for y in range(h):
		for x in range(w):
			var c = src.get_pixel(x, y)
			var lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			lum_buf[y * w + x] = lum
	
	for y in range(h):
		for x in range(w):
			var center = lum_buf[y * w + x]
			var min_lum = center
			var max_lum = center
			
			# Sample neighborhood
			for ky in range(-radius, radius + 1):
				for kx in range(-radius, radius + 1):
					if kx == 0 and ky == 0:
						continue
					var sx = clamp(x + kx, 0, w - 1)
					var sy = clamp(y + ky, 0, h - 1)
					var val = lum_buf[sy * w + sx]
					if val < min_lum:
						min_lum = val
					if val > max_lum:
						max_lum = val
			
			var contrast = max_lum - min_lum
			# High contrast -> low roughness. Map contrast [0,1] to roughness [1.0, 0.6]
			var roughness = 1.0 - contrast * 0.4
			roughness = clamp(roughness, 0.6, 1.0)
			
			dst.set_pixel(x, y, Color(roughness, roughness, roughness, 1.0))
	
	return dst

## Runs full inference pipeline: height, normal, roughness from albedo.
## @param img Source albedo image
## @return Dictionary with keys "height", "normal", "roughness" (all Images)
static func infer(img: Image) -> Dictionary:
	var height = height_from_albedo(img)
	var normal = normal_from_height(height)
	var roughness = roughness_from_albedo(img)
	return {
		"height": height,
		"normal": normal,
		"roughness": roughness
	}

## Creates a StandardMaterial3D with inferred textures.
## @param img Source albedo image
## @return StandardMaterial3D with albedo, normal, roughness textures set and normal_enabled=true
static func make_material(img: Image) -> StandardMaterial3D:
	var inferred = infer(img)
	
	var mat = StandardMaterial3D.new()
	
	# Albedo texture
	var albedo_tex = ImageTexture.create_from_image(img)
	mat.albedo_texture = albedo_tex
	
	# Normal texture
	var normal_tex = ImageTexture.create_from_image(inferred["normal"])
	mat.normal_texture = normal_tex
	mat.normal_enabled = true
	
	# Roughness texture (use ORM texture slot with roughness in green channel)
	# StandardMaterial3D uses orm_texture: R=AO, G=Roughness, B=Metallic
	var roughness_tex = ImageTexture.create_from_image(inferred["roughness"])
	mat.orm_texture = roughness_tex
	
	return mat
