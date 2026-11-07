extends RefCounted
class_name ChomuGoldenImage

## Perceptual image difference using YCxCz-lite color space
## Returns Dictionary: {mean: float, max: float, diff_image: Image}
static func perceptual_diff(a: Image, b: Image) -> Dictionary:
	if a.get_size() != b.get_size():
		var empty_img := Image.create(1, 1, false, Image.FORMAT_RF)
		return { "mean": 1.0, "max": 1.0, "diff_image": empty_img }
	
	var width := a.get_width()
	var height := a.get_height()
	
	# Convert to YCxCz-lite (luminance + color opponent channels)
	var a_y := _image_to_luminance(a)
	var b_y := _image_to_luminance(b)
	
	# Blur with 3x3 box filter
	a_y = _box_blur(a_y)
	b_y = _box_blur(b_y)
	
	# Compute per-pixel error
	var diff_image := Image.create(width, height, false, Image.FORMAT_RF)
	var total_error := 0.0
	var max_error := 0.0
	var pixel_count := width * height
	
	for y in height:
		for x in width:
			var a_val := a_y.get_pixel(x, y).r
			var b_val := b_y.get_pixel(x, y).r
			
			# Edge detection using Sobel approximation
			var a_edge := _sobel_edge(a_y, x, y, width, height)
			var b_edge := _sobel_edge(b_y, x, y, width, height)
			
			# Combined error: color distance + edge difference
			var color_diff := abs(a_val - b_val)
			var edge_diff := abs(a_edge - b_edge)
			var error = (color_diff + edge_diff) * 0.5
			
			diff_image.set_pixel(x, y, Color(error, error, error, 1.0))
			total_error += error
			if error > max_error:
				max_error = error
	
	diff_image.generate_mipmaps()
	
	return {
		"mean": total_error / pixel_count,
		"max": max_error,
		"diff_image": diff_image
	}

static func _image_to_luminance(img: Image) -> Image:
	var width := img.get_width()
	var height := img.get_height()
	var lum := Image.create(width, height, false, Image.FORMAT_RF)
	
	for y in height:
		for x in width:
			var col := img.get_pixel(x, y)
			# Convert to linear-ish luminance (approximate Rec. 709)
			var r := col.r
			var g := col.g
			var b := col.b
			var luminance := 0.2126 * r + 0.7152 * g + 0.0722 * b
			lum.set_pixel(x, y, Color(luminance, 0, 0, 1))
	
	return lum

static func _box_blur(img: Image) -> Image:
	var width := img.get_width()
	var height := img.get_height()
	var result := Image.create(width, height, false, Image.FORMAT_RF)
	
	for y in height:
		for x in width:
			var sum := 0.0
			var count := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and nx < width and ny >= 0 and ny < height:
						sum += img.get_pixel(nx, ny).r
						count += 1
			result.set_pixel(x, y, Color(sum / count, 0, 0, 1))
	
	return result

static func _sobel_edge(img: Image, x: int, y: int, width: int, height: int) -> float:
	# Sobel kernels for edge detection
	var gx := 0.0
	var gy := 0.0
	
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				var val := img.get_pixel(nx, ny).r
				var kernel_x := dx
				var kernel_y := dy
				gx += val * kernel_x
				gy += val * kernel_y
	
	return sqrt(gx * gx + gy * gy)

## Compare image to golden image for given tier/name
## Creates golden if missing. Returns {pass: bool, mean: float, created: bool}
static func compare_to_golden(img: Image, tier: String, name: String, dir: String = "user://golden", threshold: float = 0.02) -> Dictionary:
	var filename := "%s/%s_%s.png" % [dir, tier, name]
	
	if not FileAccess.file_exists(filename):
		# Create golden image
		var dir_access := DirAccess.open(dir)
		if dir_access == null:
			DirAccess.make_dir_absolute(dir)
		img.save_png(filename)
		return { "pass": true, "mean": 0.0, "created": true }
	
	var golden := Image.load_from_file(filename)
	var diff := perceptual_diff(img, golden)
	
	return {
		"pass": diff.mean <= threshold,
		"mean": diff.mean,
		"created": false
	}

## Capture image from viewport (returns null if texture unavailable)
static func capture(viewport: Viewport) -> Image:
	if viewport == null:
		return null
	
	var texture := viewport.get_texture()
	if texture == null:
		return null
	
	if not texture.has_method("get_image"):
		return null
	
	return texture.get_image()
