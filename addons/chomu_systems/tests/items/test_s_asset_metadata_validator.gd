extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/asset_metadata_validator.gd")

func run(t: Node) -> void:
	var validator := Impl.new()
	
	# Setup: Create a dummy file for testing
	var test_file = "user://test_asset.txt"
	var f = FileAccess.open(test_file, FileAccess.WRITE)
	f.store_string("dummy content")
	f.close()
	
	# Test 1: Missing File
	var res_missing = validator.validate_assets([ "user://non_existent.png" ])
	t.check("S-57 detect missing file", res_missing.size() > 0 and res_missing[0].error_code == "ERR_MISSING", "Should flag missing files")
	
	# Test 2: Existing File (Valid)
	var res_exists = validator.validate_assets([ test_file ])
	t.check("S-57 detect existing file", res_exists[0].is_valid == true or res_exists[0].error_code == "WARN_UNKNOWN_TYPE", "Existing file should be valid or just unknown type")
	
	# Test 3: Corruption Check (Resource loading)
	var config := Impl.ValidatorConfig.new()
	config.check_corruption = true
	validator.set_config(config)
	
	# Try to validate a non-resource file with corruption check enabled.
	# It should not trigger ResourceLoader.load() and thus not spam errors.
	var res_corrupt = validator.validate_assets([ test_file ])
	t.check("S-57 corruption check logic", res_corrupt[0].is_valid == true or res_corrupt[0].error_code == "WARN_UNKNOWN_TYPE", "Plain files should pass basic corruption check if openable")
	
	# Test 4: State Save/Load
	var state = validator.save_state()
	var validator2 := Impl.new()
	validator2.load_state(state)
	var config2 = validator2._config 
	t.check("S-57 state persistence", config2.check_corruption == true, "Config should persist through save/load")
	
	# Test 5: Directory Scanning
	var dir_res = validator.validate_directory("user://")
	t.check("S-57 directory scan", dir_res.size() > 0, "Should find files in user://")
	
	# Cleanup
	if FileAccess.file_exists(test_file):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_file))
