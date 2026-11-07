extends Node3D
class_name ChomuSemanticVolumes

## Internal volume entry
class VolumeEntry:
	var tag: String
	var aabb: AABB
	var name: String
	var center: Vector3
	
	func _init(p_tag: String, p_aabb: AABB, p_name: String = "") -> void:
		tag = p_tag
		aabb = p_aabb
		name = p_name
		center = p_aabb.position + p_aabb.size * 0.5

var _volumes: Array[VolumeEntry] = []

## Add a semantic volume with a tag, AABB, and optional name.
func add_volume(tag: String, aabb: AABB, name: String = "") -> void:
	var entry := VolumeEntry.new(tag, aabb, name)
	_volumes.append(entry)

## Get all tags whose volumes contain the given position.
func tags_at(pos: Vector3) -> Array[String]:
	var result: Array[String] = []
	for entry in _volumes:
		if entry.aabb.has_point(pos):
			result.append(entry.tag)
	return result

## Find the nearest volume with the given tag to the position.
## Returns a Dictionary with keys: name (String), center (Vector3), distance (float).
## Returns empty Dictionary if no volume with that tag exists.
func nearest(tag: String, pos: Vector3) -> Dictionary:
	var best_entry: VolumeEntry = null
	var best_dist: float = INF
	
	for entry in _volumes:
		if entry.tag == tag:
			var d: float = entry.center.distance_to(pos)
			if d < best_dist:
				best_dist = d
				best_entry = entry
	
	if best_entry == null:
		return {}
	
	return {
		"name": best_entry.name,
		"center": best_entry.center,
		"distance": best_dist
	}

## Automatically tag hiding spots and cover from candidate points.
## A candidate is a hiding_spot if it is occluded from ALL threats.
## A candidate is cover if it is occluded from at least HALF the threats.
## Each tagged point gets a small AABB (size 0.5x0.5x0.5) centered on the point.
func auto_tag_hiding_spots(candidates: PackedVector3Array, threats: PackedVector3Array, space: PhysicsDirectSpaceState3D) -> void:
	if threats.size() == 0:
		return
	
	var half_threats: int = (threats.size() + 1) / 2  # ceil division
	var small_size := Vector3(0.5, 0.5, 0.5)
	
	for candidate in candidates:
		var occluded_count: int = 0
		
		for threat in threats:
			var query := PhysicsRayQueryParameters3D.create(threat, candidate)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var result := space.intersect_ray(query)
			
			if result:
				# Ray hit something before reaching candidate -> occluded
				occluded_count += 1
		
		if occluded_count == threats.size():
			# Hidden from all threats
			var aabb := AABB(candidate - small_size * 0.5, small_size)
			add_volume("hiding_spot", aabb, "auto_hiding_spot")
		elif occluded_count >= half_threats:
			# Hidden from at least half
			var aabb := AABB(candidate - small_size * 0.5, small_size)
			add_volume("cover", aabb, "auto_cover")
