extends RefCounted
class_name ChomuComponentSchemaMigrationVersioning

## Component Schema Migration Versioning
## Handles the evolution of saved data structures over time.
## It allows developers to define a sequence of migration functions 
## that transform data from version N to N+1, ensuring old save files 
## remain compatible with new game versions.

var _migrations: Dictionary = {} # { "component_id": { version_int: Callable } }
var _current_versions: Dictionary = {} # { "component_id": current_version_int }

## Registers the current version of a component.
## Any data loaded with a version lower than this will be migrated.
func register_component(component_id: String, current_version: int) -> void:
	_current_versions[component_id] = current_version
	if not _migrations.has(component_id):
		_migrations[component_id] = {}

## Registers a migration function to move data from 'from_version' to 'from_version + 1'.
## The function must take a Dictionary and return a Dictionary.
func add_migration(component_id: String, from_version: int, migration_fn: Callable) -> void:
	if not _migrations.has(component_id):
		_migrations[component_id] = {}
	_migrations[component_id][from_version] = migration_fn

## Migrates the provided data to the latest registered version for the given component.
## data_wrapper should be a Dictionary containing:
## { "version": int, "data": Dictionary }
## Returns a new wrapper: { "version": latest_version, "data": migrated_data }
func migrate(component_id: String, data_wrapper: Dictionary) -> Dictionary:
	if not data_wrapper.has("version") or not data_wrapper.has("data"):
		push_error("ChomuComponentSchemaMigrationVersioning: Invalid data wrapper format.")
		return data_wrapper

	var version: int = data_wrapper["version"]
	var data: Dictionary = data_wrapper["data"].duplicate(true)
	
	if not _current_versions.has(component_id):
		return data_wrapper

	var target_version: int = _current_versions[component_id]
	var component_migrations = _migrations.get(component_id, {})

	while version < target_version:
		var migration_fn = component_migrations.get(version)
		if migration_fn == null:
			# We stop migration if a gap is found. 
			# No warning is pushed here to keep logs clean during intentional partial migrations.
			break
		
		data = migration_fn.call(data)
		version += 1

	return {
		"version": version,
		"data": data
	}

## Returns the current version of a component.
func get_current_version(component_id: String) -> int:
	return _current_versions.get(component_id, -1)

## Serializes the internal state of the migration manager.
func save_state() -> Dictionary:
	return {
		"current_versions": _current_versions.duplicate()
	}

## Loads the internal state of the migration manager.
func load_state(state: Dictionary) -> void:
	if state.has("current_versions"):
		_current_versions = state["current_versions"].duplicate()
