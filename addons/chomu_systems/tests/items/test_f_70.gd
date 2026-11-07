extends RefCounted
const Impl := preload("res://addons/chomu_systems/debug/golden_image.gd")

func run(t: Node) -> void:
	# Test 1: Identical images have mean 0
	var img1 := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img1.fill(Color(0.5, 0.5, 0.5))
	var result1 := Impl.perceptual_diff(img1, img1)
	t.check("F-70 identical images mean 0", result1.mean == 0.0, "Expected mean 0 for identical images, got %s" % result1.mean)
	
	# Test 2: One-pixel change gives non-zero max but small mean
	var img2 := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img2.fill(Color(0.5, 0.5, 0.5))
	img2.set_pixel(32, 32, Color(0.6, 0.5, 0.5))
	var result2 := Impl.perceptual_diff(img1, img2)
	t.check("F-70 one-pixel change non-zero max", result2.max > 0.0, "Expected max > 0 for one-pixel change, got %s" % result2.max)
	t.check("F-70 one-pixel change small mean", result2.mean < 0.01, "Expected small mean for one-pixel change, got %s" % result2.mean)
	
	# Test 3: Big shift fails threshold
	var img3 := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img3.fill(Color(1.0, 1.0, 1.0))
	var result3 := Impl.perceptual_diff(img1, img3)
	t.check("F-70 big shift fails threshold", result3.mean > 0.02, "Expected mean > 0.02 for big shift, got %s" % result3.mean)
	
	# Test 4: First compare creates golden
	var test_dir := "user://golden_test_f70"
	var test_name := "test_image"
	var test_tier := "unit"
	
	# Clean up any existing golden
	var existing := "%s/%s_%s.png" % [test_dir, test_tier, test_name]
	if FileAccess.file_exists(existing):
		DirAccess.remove_absolute(existing)
	
	var img4 := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img4.fill(Color(0.3, 0.4, 0.5))
	
	var result4 := Impl.compare_to_golden(img4, test_tier, test_name, test_dir, 0.02)
	t.check("F-70 first compare creates golden", result4.created == true, "Expected created=true on first compare")
	t.check("F-70 first compare passes", result4.pass == true, "Expected pass=true when golden created")
	
	# Test 5: Second compare passes
	var result5 := Impl.compare_to_golden(img4, test_tier, test_name, test_dir, 0.02)
	t.check("F-70 second compare passes", result5.pass == true, "Expected pass=true on second compare")
	t.check("F-70 second compare not created", result5.created == false, "Expected created=false on second compare")
	
	# Test 6: Different image fails threshold
	var img6 := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img6.fill(Color(0.9, 0.9, 0.9))
	var result6 := Impl.compare_to_golden(img6, test_tier, test_name, test_dir, 0.02)
	t.check("F-70 different image fails threshold", result6.pass == false, "Expected pass=false for different image")
	
	# Test 7: Capture returns null for null viewport
	var result7 := Impl.capture(null)
	t.check("F-70 capture null viewport returns null", result7 == null, "Expected null for null viewport")
	
	# Test 8: Size mismatch returns error
	var small := Image.create(16, 16, false, Image.FORMAT_RGB8)
	small.fill(Color(0.5, 0.5, 0.5))
	var result8 := Impl.perceptual_diff(img1, small)
	t.check("F-70 size mismatch returns error", result8.mean == 1.0, "Expected mean=1.0 for size mismatch")
	
	# Cleanup
	if FileAccess.file_exists(existing):
		DirAccess.remove_absolute(existing)
	if DirAccess.dir_exists_absolute(test_dir):
		DirAccess.remove_absolute(test_dir)
