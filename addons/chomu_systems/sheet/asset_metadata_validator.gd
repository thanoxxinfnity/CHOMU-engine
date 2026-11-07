extends RefCounted
class_name ChomuAssetMetadataValidator

## Asset Metadata Validator (S-57)
## Core implementation for checking asset integrity, missing dependencies, 
## and corrupted files. Designed for pipeline validation and startup checks.
## Mobile-first: minimizes allocations and avoids rendering dependencies.

## Result of a single asset validation check.
class ValidationResult:
	var path: String
	var is_valid: bool
	var error_code: String = ""
	var message: String = ""
	var severity: int = 0 # 0: Info, 1: Warning, 2: Error

	func _init(p: String, valid: bool, code: String = "", msg: String = "", sev: int = 0):
		path = p
		is_valid = valid
		error_code = code
		message = msg
		severity = sev

## Configuration for the validator.
class ValidatorConfig:
	## If true, checks if files actually exist on disk.
	@export var check_existence: bool = true
	## If true, attempts to load the resource to check for corruption.
	@export var check_corruption: bool = false
	## List of extensions that must be validated for specific metadata.
	@export var target_extensions: Array[String] = ["res://", ".tscn", ".tres", ".png", ".jpg", ".wav", ".ogg"]
	## If true, recursively scans directories.
	@export var recursive: bool = true

var _config: ValidatorConfig = ValidatorConfig.new()
var _last_results: Array[ValidationResult] = []

func _init():
	pass

## Sets the validator configuration.
func set_config(config: ValidatorConfig) -> void:
	_config = config

## Validates a list of asset paths.
## Returns an array of ValidationResult objects.
func validate_assets(paths: Array[String]) -> Array[ValidationResult]:
	_last_results.clear()
	var results: Array[ValidationResult] = []
	
	for path in paths:
		var res = _validate_single_asset(path)
		results.append(res)
		_last_results.append(res)
	
	return results

## Validates a single asset path.
func _validate_single_asset(path: String) -> ValidationResult:
	# 1. Existence Check
	if _config.check_existence:
		if not FileAccess.file_exists(path):
			return ValidationResult.new(path, false, "ERR_MISSING", "File does not exist on disk", 2)

	# 2. Basic Corruption/Load Check
	if _config.check_corruption:
		# Only attempt ResourceLoader.load if it looks like a Godot resource
		var is_resource = false
		for ext in [".tscn", ".tres", ".res", ".remap", ".import"]:
			if path.ends_with(ext):
				is_resource = true
				break
		
		if is_resource:
			var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
			if res == null:
				return ValidationResult.new(path, false, "ERR_CORRUPT", "Resource failed to load", 2)
			
			# Check for internal broken dependencies
			var deps = ResourceLoader.get_dependencies(path)
			for dep in deps:
				if not FileAccess.file_exists(dep):
					return ValidationResult.new(path, false, "ERR_BROKEN_LINK", "Dependency missing: " + dep, 2)
		else:
			# For non-resources, just check if the file is readable
			var file = FileAccess.open(path, FileAccess.READ)
			if file == null:
				return ValidationResult.new(path, false, "ERR_CORRUPT", "File cannot be opened", 2)
			file.close()

	# 3. Metadata/Extension Validation
	var ext_valid = false
	for ext in _config.target_extensions:
		if path.begins_with(ext) or path.ends_with(ext):
			ext_valid = true
			break
	
	if not ext_valid:
		return ValidationResult.new(path, true, "WARN_UNKNOWN_TYPE", "Asset type not in target list", 0)

	return ValidationResult.new(path, true)

## Scans a directory for assets and validates them.
func validate_directory(dir_path: String) -> Array[ValidationResult]:
	var paths_to_validate: Array[String] = []
	var dir = DirAccess.open(dir_path)
	
	if dir == null:
		return [ValidationResult.new(dir_path, false, "ERR_DIR_ACCESS", "Could not open directory", 2)]
	
	if _config.recursive:
		_recursive_collect_paths(dir, dir_path, paths_to_validate)
	else:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				paths_to_validate.append(dir_path.path_join(file_name))
			file_name = dir.get_next()
	
	return validate_assets(paths_to_validate)

func _recursive_collect_paths(dir: DirAccess, current_path: String, list: Array[String]) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
			
		var full_path = current_path.path_join(file_name)
		if dir.current_is_dir():
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				_recursive_collect_paths(sub_dir, full_path, list)
		else:
			list.append(full_path)
		file_name = dir.get_next()

## Saves the current validator state as a Dictionary.
func save_state() -> Dictionary:
	return {
		"config": {
			"check_existence": _config.check_existence,
			"check_corruption": _config.check_corruption,
			"target_extensions": _config.target_extensions,
			"recursive": _config.recursive
		}
	}

## Loads the validator state from a Dictionary.
func load_state(data: Dictionary) -> void:
	if not data.has("config"): return
	var c = data["config"]
	_config.check_existence = c.get("check_existence", true)
	_config.check_corruption = c.get("check_corruption", false)
	_config.target_extensions = c.get("target_extensions", ["res://", ".tscn", ".tres", ".png", ".jpg", ".wav", ".ogg"])
	_config.recursive = c.get("recursive", true)
