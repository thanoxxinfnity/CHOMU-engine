extends RefCounted
class_name ChomuBulletPenetrationDepthTracker

## Bullet Penetration Depth Tracker
## Calculates material density loss when projectiles pass through thin covers.
## Uses a standard game-dev approach: track penetration depth per material type
## and apply density loss based on material properties and penetration depth.

## Material definition structure
class PenetrationMaterial:
	extends RefCounted
	
	## Material properties
	var density: float = 1.0		## Base material density (0.0-1.0)
	var thickness: float = 0.1	## Material thickness in meters
	var penetration_resistance: float = 0.5	## How much material resists penetration (0.0-1.0)
	
	## Creates a new material definition
	func _init(p_density: float = 1.0, p_thickness: float = 0.1, p_resistance: float = 0.5) -> void:
		density = p_density
		thickness = p_thickness
		penetration_resistance = p_resistance
	
	## Calculates remaining density after penetration
	func calculate_density_loss(penetration_depth: float) -> float:
		if penetration_depth <= 0.0:
			return density
		
		## Penetration reduces density based on depth and resistance
		var effective_depth = min(penetration_depth, thickness * 2.0)
		var loss_factor = 1.0 - pow(effective_depth / (thickness + 0.001), penetration_resistance)
		return max(0.0, density * loss_factor)


## Penetration result structure
class PenetrationResult:
	extends RefCounted
	
	var material_id: String = ""
	var original_density: float = 1.0
	var remaining_density: float = 1.0
	var penetration_depth: float = 0.0
	var fully_penetrated: bool = false
	var is_blocked: bool = false
	
	## Creates a new penetration result
	func _init(p_material_id: String = "", p_original: float = 1.0, p_remaining: float = 1.0, p_depth: float = 0.0) -> void:
		material_id = p_material_id
		original_density = p_original
		remaining_density = p_remaining
		penetration_depth = p_depth
		fully_penetrated = p_remaining <= 0.0
		is_blocked = p_depth <= 0.0


## Main tracker class
var _materials: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _state: Dictionary = {}

## Initializes the tracker with optional seed for deterministic behavior
func _init(seed: int = 12345) -> void:
	_rng.seed = seed
	_state = {
		"materials": {},
		"tracked_penetrations": [],
		"total_penetration_events": 0
	}

## Registers a material type for penetration tracking
## Returns true if material was newly registered
func register_material(material_id: String, density: float, thickness: float, resistance: float) -> bool:
	if _materials.has(material_id):
		return false
	
	var mat = PenetrationMaterial.new(density, thickness, resistance)
	_materials[material_id] = mat
	_state["materials"][material_id] = {
		"density": density,
		"thickness": thickness,
		"resistance": resistance
	}
	return true

## Gets a material by ID
func get_material(material_id: String) -> PenetrationMaterial:
	return _materials.get(material_id, null) as PenetrationMaterial

## Removes a material from tracking
func unregister_material(material_id: String) -> bool:
	if !_materials.has(material_id):
		return false
	_materials.erase(material_id)
	_state["materials"].erase(material_id)
	return true

## Processes a bullet passing through a material
## penetration_depth: how far the bullet penetrated into the material (meters)
## Returns PenetrationResult with density loss information
func process_penetration(material_id: String, penetration_depth: float) -> PenetrationResult:
	var mat = _materials.get(material_id, null) as PenetrationMaterial
	if mat == null:
		return PenetrationResult.new(material_id, 1.0, 1.0, penetration_depth)
	
	var original = mat.density
	var remaining = mat.calculate_density_loss(penetration_depth)
	var result = PenetrationResult.new(material_id, original, remaining, penetration_depth)
	
	## Track this penetration event
	_state["tracked_penetrations"].append({
		"material_id": material_id,
		"depth": penetration_depth,
		"original": original,
		"remaining": remaining,
		"timestamp": Time.get_ticks_msec()
	})
	_state["total_penetration_events"] += 1
	
	return result

## Simulates a bullet passing through multiple materials
## materials: Array of dictionaries with material_id and thickness
## Returns array of PenetrationResults
func simulate_trajectory(materials: Array) -> Array[PenetrationResult]:
	var results: Array[PenetrationResult] = []
	var accumulated_depth: float = 0.0
	
	for mat_data in materials:
		var mat_id = mat_data.get("material_id", "")
		var mat_thickness = mat_data.get("thickness", 0.1)
		
		## Add some randomness to penetration depth for realism
		var variance = _rng.randf_range(-0.1, 0.1) * mat_thickness
		var penetration = min(mat_thickness + variance, mat_thickness * 1.5)
		accumulated_depth += penetration
		
		var result = process_penetration(mat_id, accumulated_depth)
		results.append(result)
		
		## If bullet is blocked, stop processing
		if result.is_blocked:
			break
	
	return results

## Gets the total number of penetration events tracked
func get_event_count() -> int:
	return _state["total_penetration_events"]

## Gets all tracked penetration events
func get_tracked_events() -> Array[Dictionary]:
	return _state["tracked_penetrations"].duplicate(true)

## Clears all tracked penetration events
func clear_tracking() -> void:
	_state["tracked_penetrations"] = []
	_state["total_penetration_events"] = 0

## Calculates density loss for a single material hit
## This is the core calculation used by weapons and destructibles
func calculate_density_loss_for_hit(material_id: String, impact_depth: float) -> float:
	var mat = _materials.get(material_id, null) as PenetrationMaterial
	if mat == null:
		return 1.0
	
	return mat.calculate_density_loss(impact_depth)

## Checks if a bullet should be blocked by a material
## Returns true if the bullet cannot penetrate
func should_block_bullet(material_id: String, bullet_energy: float) -> bool:
	var mat = _materials.get(material_id, null) as PenetrationMaterial
	if mat == null:
		return false
	
	## Higher resistance and density require more energy to penetrate
	var required_energy = mat.density * mat.penetration_resistance * 100.0
	return bullet_energy < required_energy

## Saves the current state to a Dictionary for serialization
func save_state() -> Dictionary:
	return {
		"materials": _state["materials"].duplicate(true),
		"tracked_penetrations": _state["tracked_penetrations"].duplicate(true),
		"total_penetration_events": _state["total_penetration_events"],
		"rng_seed": _rng.seed
	}

## Loads state from a Dictionary
func load_state(state: Dictionary) -> void:
	_state = {
		"materials": state.get("materials", {}).duplicate(true),
		"tracked_penetrations": state.get("tracked_penetrations", []).duplicate(true),
		"total_penetration_events": state.get("total_penetration_events", 0),
		"rng_seed": state.get("rng_seed", 12345)
	}
	
	## Rebuild materials from saved state
	_materials.clear()
	for mat_id in _state["materials"]:
		var mat_data = _state["materials"][mat_id]
		_materials[mat_id] = PenetrationMaterial.new(
			mat_data.get("density", 1.0),
			mat_data.get("thickness", 0.1),
			mat_data.get("resistance", 0.5)
		)
	
	_rng.seed = _state["rng_seed"]

## Gets list of all registered material IDs
func get_registered_materials() -> Array[String]:
	return _materials.keys()
