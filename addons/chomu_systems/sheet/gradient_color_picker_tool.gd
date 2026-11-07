extends RefCounted
class_name ChomuGradientColorPickerTool

## S-96 Gradient Color Picker Tool
## A data-driven multi-stop color ramp editor core.
## Designed for particle systems, lighting gradients, and UI.
## This class handles the logic of stop management and color interpolation,
## remaining decoupled from the actual UI rendering.

class GradientStop:
	## Position of the stop in the ramp (0.0 to 1.0)
	var offset: float
	## The color of the stop
	var color: Color
	## Unique ID for the stop to allow stable referencing in UI
	var id: int

	func _init(p_offset: float, p_color: Color, p_id: int) -> void:
		offset = p_offset
		color = p_color
		id = p_id

## The core tool state
var _stops: Array[GradientStop] = []
var _next_id: int = 0

func _init(_p_seed: int = 12345) -> void:
	# Seed is accepted for API compatibility with other CHoMU tools, 
	# though current linear interpolation is deterministic.
	pass

## Adds a new color stop at the given offset.
## Returns the ID of the created stop.
func add_stop(offset: float, color: Color) -> int:
	var id := _next_id
	_next_id += 1
	var stop := GradientStop.new(clampf(offset, 0.0, 1.0), color, id)
	_stops.append(stop)
	_sort_stops()
	return id

## Removes a stop by its ID. Returns true if found and removed.
func remove_stop(id: int) -> bool:
	for i in range(_stops.size()):
		if _stops[i].id == id:
			_stops.remove_at(i)
			return true
	return false

## Updates the offset and/or color of an existing stop.
## Use -1.0 for offset or null-equivalent logic to skip updates.
func update_stop(id: int, offset: float = -1.0, color: Color = Color(-1, -1, -1, -1)) -> bool:
	for stop in _stops:
		if stop.id == id:
			if offset >= 0.0:
				stop.offset = clampf(offset, 0.0, 1.0)
			if color.r < 0.0:
				# Skip color update if sentinel value is passed
				pass
			else:
				stop.color = color
			_sort_stops()
			return true
	return false

## Samples the gradient at a specific position (0.0 to 1.0).
## Performs linear interpolation between the two nearest stops.
func sample(offset: float) -> Color:
	if _stops.is_empty():
		return Color.BLACK
	
	var t := clampf(offset, 0.0, 1.0)
	
	# Find the two stops surrounding t
	var left_idx := -1
	for i in range(_stops.size()):
		if _stops[i].offset <= t:
			left_idx = i
		else:
			break
			
	if left_idx == -1:
		return _stops[0].color
	if left_idx == _stops.size() - 1:
		return _stops[-1].color
		
	var left := _stops[left_idx]
	var right := _stops[left_idx + 1]
	
	var local_t := (t - left.offset) / (right.offset - left.offset)
	return left.color.lerp(right.color, local_t)

## Returns a copy of the current stops sorted by offset.
func get_stops() -> Array[GradientStop]:
	return _stops.duplicate()

## Serializes the current state to a Dictionary.
func save_state() -> Dictionary:
	var stops_data: Array[Dictionary] = []
	for s in _stops:
		stops_data.append({
			"id": s.id,
			"offset": s.offset,
			"color": {
				"r": s.color.r,
				"g": s.color.g,
				"b": s.color.b,
				"a": s.color.a
			}
		})
	return {
		"stops": stops_data,
		"next_id": _next_id
	}

## Restores state from a Dictionary.
func load_state(data: Dictionary) -> void:
	_stops.clear()
	_next_id = data.get("next_id", 0)
	var stops_data = data.get("stops", [])
	for s_dict in stops_data:
		var c_dict = s_dict.get("color", {})
		var col := Color(
			c_dict.get("r", 0.0),
			c_dict.get("g", 0.0),
			c_dict.get("b", 0.0),
			c_dict.get("a", 1.0)
		)
		_stops.append(GradientStop.new(s_dict.get("offset", 0.0), col, s_dict.get("id", 0)))
	_sort_stops()

func _sort_stops() -> void:
	_stops.sort_custom(func(a, b): return a.offset < b.offset)
