extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/non_volatile_local_storage_manager.gd")

func run(t: Node) -> void:
	var storage := Impl.new()
	var test_file := "test_save_s40.dat"
	var test_path := "user://" + test_file
	
	# Test 1: Basic Set/Get
	storage.set_value("player_name", "Chomu")
	storage.set_value("level", 42)
	t.check("S-40 Basic Set/Get", storage.get_value("player_name") == "Chomu", "Should retrieve correct string")
	t.check("S-40 Basic Set/Get Int", storage.get_value("level") == 42, "Should retrieve correct int")
	t.check("S-40 Default Value", storage.get_value("non_existent", 100) == 100, "Should return default for missing key")

	# Test 2: Persistence and Loading (Plain)
	storage.set_value("score", 1500)
	var err_save := storage.persist_to_disk(test_file, false)
	t.check("S-40 Persist Plain", err_save == OK, "Save to disk should succeed")
	
	var storage2 := Impl.new()
	var err_load := storage2.load_from_disk(test_file, false)
	t.check("S-40 Load Plain", err_load == OK, "Load from disk should succeed")
	t.check("S-40 Load Value", storage2.get_value("score") == 1500, "Loaded value should match saved value")

	# Test 3: Obfuscation
	storage.set_value("secret", "hidden_treasure")
	storage.persist_to_disk(test_file, true)
	
	var storage3 := Impl.new()
	storage3.obfuscation_key = storage.obfuscation_key
	var err_load_enc := storage3.load_from_disk(test_file, true)
	t.check("S-40 Load Obfuscated", err_load_enc == OK, "Load obfuscated file should succeed")
	t.check("S-40 Obfuscated Value", storage3.get_value("secret") == "hidden_treasure", "Obfuscated value should be recovered")
	
	# Test 4: Wrong Key Obfuscation
	var storage4 := Impl.new()
	storage4.obfuscation_key = 0x12345678 # Different key
	var err_load_wrong := storage4.load_from_disk(test_file, true)
	# The implementation now uses _is_valid_utf8 to catch this before get_string_from_utf8()
	t.check("S-40 Wrong Key Failure", err_load_wrong != OK, "Loading with wrong key should return error without engine warnings")

	# Test 5: Complex Data (Nested Dictionaries)
	var complex_data := {
		"inventory": ["sword", "shield", "potion"],
		"stats": {"str": 10, "dex": 12}
	}
	storage.set_value("game_state", complex_data)
	storage.persist_to_disk(test_file, false)
	
	var storage5 := Impl.new()
	storage5.load_from_disk(test_file, false)
	var loaded_complex := storage5.get_value("game_state")
	t.check("S-40 Complex Data", loaded_complex["inventory"][0] == "sword", "Nested array should be preserved")
	t.check("S-40 Complex Data Dict", loaded_complex["stats"]["str"] == 10, "Nested dict should be preserved")

	# Cleanup
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if FileAccess.file_exists(test_path + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + ".tmp"))
