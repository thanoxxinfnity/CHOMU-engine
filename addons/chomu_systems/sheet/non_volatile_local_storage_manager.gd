extends RefCounted
class_name ChomuNonVolatileLocalStorageManager

## Non-Volatile Local Storage Manager (S-40)
## Provides a secure, cross-platform interface for persisting game state, 
## player settings, and progress to the local filesystem.
## 
## Designed for mobile-first performance: uses atomic writes (via temporary files)
## to prevent corruption during crashes and minimizes disk I/O.

## The current in-memory state of the manager.
var _data: Dictionary = {}
## The base directory for storage (defaults to user://).
var _base_path: String = "user://"
## A simple XOR key for basic obfuscation to discourage casual editing of save files.
@export var obfuscation_key: int = 0xDEADBEEF

## Initializes the manager.
## [param base_path]: The root directory for save files.
func _init(p_base_path: String = "user://"):
	_base_path = p_base_path if p_base_path.ends_with("/") else p_base_path + "/"

## Sets or updates a value in the local state.
## [param key]: The unique identifier for the data piece.
## [param value]: The value to store (must be JSON-serializable).
func set_value(p_key: String, p_value: Variant) -> void:
	_data[p_key] = p_value

## Retrieves a value from the local state.
## [param key]: The unique identifier.
## [param default]: Value to return if the key does not exist.
func get_value(p_key: String, p_default: Variant = null) -> Variant:
	return _data.get(p_key, p_default)

## Removes a specific key from the state.
func remove_value(p_key: String) -> void:
	_data.erase(p_key)

## Clears all in-memory state.
func clear() -> void:
	_data.clear()

## Serializes the current state to a Dictionary for external backup or replication.
func save_state() -> Dictionary:
	return _data.duplicate(true)

## Loads the state from a provided Dictionary.
func load_state(p_state: Dictionary) -> void:
	_data = p_state.duplicate(true)

## Persists the current in-memory state to a file on disk.
## Uses an atomic write pattern: Write to .tmp -> Rename to .dat.
## [param filename]: The name of the file (e.g., "save_01.dat").
## [param encrypt]: Whether to apply basic XOR obfuscation.
func persist_to_disk(p_filename: String, p_encrypt: bool = true) -> Error:
	var full_path := _base_path + p_filename
	var tmp_path := full_path + ".tmp"
	
	var json_string := JSON.stringify(_data)
	var bytes := json_string.to_utf8_buffer()
	
	if p_encrypt:
		bytes = _apply_obfuscation(bytes)
	
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	
	file.store_buffer(bytes)
	file.close()
	
	# Atomic swap
	if FileAccess.file_exists(full_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(full_path))
	
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(full_path))
	
	return err

## Loads state from a file on disk into memory.
## [param filename]: The name of the file to load.
## [param encrypt]: Whether the file was obfuscated.
func load_from_disk(p_filename: String, p_encrypt: bool = true) -> Error:
	var full_path := _base_path + p_filename
	if not FileAccess.file_exists(full_path):
		return ERR_FILE_NOT_FOUND
	
	var file := FileAccess.open(full_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	
	var bytes := file.get_buffer(file.get_length())
	file.close()
	
	if p_encrypt:
		bytes = _apply_obfuscation(bytes)
	
	# To avoid the engine's internal UTF-8 parsing warnings/errors when 
	# bytes are not valid UTF-8 (e.g. wrong XOR key), we check if the 
	# buffer is valid UTF-8 before converting to string.
	if not _is_valid_utf8(bytes):
		return ERR_FILE_CORRUPT
		
	var json_string := bytes.get_string_from_utf8()
	var parsed = JSON.parse_string(json_string)
	
	if parsed == null:
		return ERR_FILE_CORRUPT
	
	if parsed is Dictionary:
		_data = parsed
		return OK
	else:
		return ERR_INVALID_DATA

## Internal helper to XOR bytes for basic obfuscation.
func _apply_obfuscation(p_data: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(p_data.size())
	var key_bytes := StreamPeerBuffer.new()
	key_bytes.put_u32(obfuscation_key)
	var key_arr := key_bytes.data_array
	
	for i in range(p_data.size()):
		result[i] = p_data[i] ^ key_arr[i % 4]
	
	return result

## Validates if a PackedByteArray is valid UTF-8 to prevent engine-level 
## Unicode parsing errors during get_string_from_utf8().
func _is_valid_utf8(p_bytes: PackedByteArray) -> bool:
	var i := 0
	while i < p_bytes.size():
		var b := p_bytes[i]
		if b <= 0x7F:
			i += 1
		elif b >= 0xC2 and b <= 0xDF:
			if i + 1 >= p_bytes.size() or (p_bytes[i+1] & 0xC0) != 0x80: return false
			i += 2
		elif b >= 0xE0 and b <= 0xEF:
			if i + 2 >= p_bytes.size() or (p_bytes[i+1] & 0xC0) != 0x80 or (p_bytes[i+2] & 0xC0) != 0x80: return false
			i += 3
		elif b >= 0xF0 and b <= 0xF4:
			if i + 3 >= p_bytes.size() or (p_bytes[i+1] & 0xC0) != 0x80 or (p_bytes[i+2] & 0xC0) != 0x80 or (p_bytes[i+3] & 0xC0) != 0x80: return false
			i += 4
		else:
			return false
	return true
