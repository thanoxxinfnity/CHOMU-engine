extends RefCounted
class_name ChomuResidencyBudget

## Budgeted residency planner for texture mip-level management.
## Note: This is a planning system; it does not interface with GPU drivers.

class TextureEntry:
	var id: String
	var base_bytes: int
	var mip_count: int
	var importance: float
	var screen_size: float = 1.0
	var distance: float = 1.0
	var current_mip: int = 0 # 0 = full res, mip_count-1 = lowest res

	func _init(p_id: String, p_base: int, p_mips: int, p_imp: float):
		id = p_id
		base_bytes = p_base
		mip_count = p_mips
		importance = p_imp

	func get_priority() -> float:
		return (screen_size * importance) / max(distance, 0.01)

	func get_bytes_for_mip(level: int) -> int:
		# Mip size decreases by 4^n (2D texture)
		return int(float(base_bytes) / pow(4.0, float(level)))

	func get_total_bytes_resident(top_mip: int) -> int:
		# Resident mips are from top_mip up to mip_count-1
		var total: int = 0
		for i in range(top_mip, mip_count):
			total += get_bytes_for_mip(i)
		return total

var _budget_bytes: int
var _textures: Dictionary = {} # String -> TextureEntry

func _init(p_budget_bytes: int):
	_budget_bytes = p_budget_bytes

func add(p_id: String, p_base_bytes: int, p_mip_count: int, p_importance: float) -> void:
	_textures[p_id] = TextureEntry.new(p_id, p_base_bytes, p_mip_count, p_importance)

func update_view(p_id: String, p_screen_size: float, p_distance: float) -> void:
	var tex = _textures.get(p_id)
	if tex:
		tex.screen_size = p_screen_size
		tex.distance = p_distance

func plan() -> Dictionary:
	# Start every texture at its finest mip (0)
	var plan_results: Dictionary = {}
	var active_textures: Array[TextureEntry] = []
	
	for id in _textures:
		var tex = _textures[id]
		tex.current_mip = 0
		plan_results[id] = 0
		active_textures.append(tex)
	
	# While total bytes > budget, drop one mip level from the lowest-priority texture
	while _calculate_total_bytes(plan_results) > _budget_bytes:
		var worst_tex: TextureEntry = null
		var min_priority: float = INF
		
		for tex in active_textures:
			# Only consider textures that can still be dropped
			if plan_results[tex.id] < tex.mip_count - 1:
				var prio = tex.get_priority()
				if prio < min_priority:
					min_priority = prio
					worst_tex = tex
		
		if worst_tex == null:
			# All textures are at their lowest mip, cannot drop further
			break
		
		plan_results[worst_tex.id] += 1
		
	return plan_results

func _calculate_total_bytes(plan: Dictionary) -> int:
	var total: int = 0
	for id in plan:
		var tex = _textures.get(id)
		if tex:
			total += tex.get_total_bytes_resident(plan[id])
	return total

func total_bytes(plan: Dictionary) -> int:
	return _calculate_total_bytes(plan)
