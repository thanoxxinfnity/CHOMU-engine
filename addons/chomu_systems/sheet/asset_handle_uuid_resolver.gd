extends RefCounted
class_name ChomuAssetHandleUuidResolver

## Asset Handle / UUID Resolver (S-56)
## Provides a stable mapping between unique identifiers (UUIDs) and volatile asset paths.
## This ensures that renaming or moving files in the project does not break references.
##
## Design:
## - Uses a bidirectional map (UUID <-> Path).
## - UUIDs are generated deterministically using a seeded RNG if not provided.
## - State can be serialized to/from a Dictionary for persistence.

## The internal registry mapping UUIDs to their current resource paths.
var _uuid_to_path: Dictionary = {}
## The internal registry mapping paths to their UUIDs for fast lookup.
var _path_to_uuid: Dictionary = {}
## Seeded RNG for deterministic UUID generation.
var _rng: RandomNumberGenerator

func _init(seed_value: int = 12345):
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

## Registers an asset path and returns its associated UUID.
## If the path is already registered, it returns the existing UUID.
## If the path is new, it generates a new UUID.
func register_asset(path: String) -> String:
	if path == "":
		return ""
	
	if _path_to_uuid.has(path):
		return _path_to_uuid[path]
	
	var uuid := _generate_uuid()
	# Collision check (extremely rare for 128-bit style strings, but safe)
	while _uuid_to_path.has(uuid):
		uuid = _generate_uuid()
		
	_uuid_to_path[uuid] = path
	_path_to_uuid[path] = uuid
	return uuid

## Resolves a UUID back to its current asset path.
## Returns an empty string if the UUID is not registered.
func resolve_uuid(uuid: String) -> String:
	return _uuid_to_path.get(uuid, "")

## Updates the path associated with a UUID. 
## Used when an asset is moved or renamed on disk.
func update_path(uuid: String, new_path: String) -> bool:
	if not _uuid_to_path.has(uuid):
		return false
	
	var old_path = _uuid_to_path[uuid]
	if old_path == new_path:
		return true
		
	_path_to_uuid.erase(old_path)
	_uuid_to_path[uuid] = new_path
	_path_to_uuid[new_path] = uuid
	return true

## Removes an asset from the resolver.
func unregister_asset(uuid: String) -> bool:
	if not _uuid_to_path.has(uuid):
		return false
	
	var path = _uuid_to_path[uuid]
	_path_to_uuid.erase(path)
	_uuid_to_path.erase(uuid)
	return true

## Returns the UUID for a given path, or an empty string if not registered.
func get_uuid_for_path(path: String) -> String:
	return _path_to_uuid.get(path, "")

## Serializes the current registry state into a Dictionary.
func save_state() -> Dictionary:
	return {
		"registry": _uuid_to_path.duplicate()
	}

## Restores the registry state from a Dictionary.
func load_state(data: Dictionary) -> void:
	if not data.has("registry"):
		return
		
	_uuid_to_path.clear()
	_path_to_uuid.clear()
	
	var registry = data["registry"]
	for uuid in registry:
		var path = registry[uuid]
		_uuid_to_path[uuid] = path
		_path_to_uuid[path] = uuid

## Generates a pseudo-UUID string.
## Format: 8-4-4-4-12 hex characters.
func _generate_uuid() -> String:
	var parts: Array[String] = []
	# 8-4-4-4-12 = 32 hex chars total
	# We generate 4 blocks of 32-bit ints
	for i in range(5):
		var len := 8
		if i == 1 or i == 2 or i == 3:
			len = 4
		if i == 4:
			len = 12
			
		var val := _rng.randi()
		var hex := "%08x" % val
		parts.append(hex.right(len))
		
	# This is a simplified deterministic UUID for GDScript
	# Real UUIDs use specific version bits; here we prioritize speed and stability.
	return "%s-%s-%s-%s-%s" % [parts[0], parts[1], parts[2], parts[3], parts[4]]
