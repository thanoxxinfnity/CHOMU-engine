extends RefCounted
class_name ChomuMultiSelectTransformGizmoHandler

## S-108 Multi-Select Transform Gizmo Handler
## Core logic for manipulating multiple 3D objects simultaneously.
## Supports Translation, Rotation, and Scaling relative to a calculated center.
## Designed for mobile-first (low RAM, deterministic) and headless execution.

class TransformMode:
	const TRANSLATE = 0
	const ROTATE = 1
	const SCALE = 2

class SelectionItem:
	var node: Node3D
	var initial_global_transform: Transform3D
	var local_to_gizmo: Transform3D

	func _init(n: Node3D):
		node = n
		initial_global_transform = n.global_transform
		local_to_gizmo = Transform3D.IDENTITY

## The current mode of the gizmo
var current_mode: int = TransformMode.TRANSLATE
## The center point of the multi-selection (the gizmo's origin)
var gizmo_center: Vector3 = Vector3.ZERO
## The basis of the gizmo (orientation)
var gizmo_basis: Basis = Basis.IDENTITY

var _selected_items: Array[SelectionItem] = []
var _is_dragging: bool = false

## Sets the list of nodes to be manipulated.
func set_selection(nodes: Array[Node3D]) -> void:
	_selected_items.clear()
	if nodes.is_empty():
		return
	
	var sum_pos := Vector3.ZERO
	for n in nodes:
		_selected_items.append(SelectionItem.new(n))
		sum_pos += n.global_position
	
	gizmo_center = sum_pos / float(nodes.size())
	gizmo_basis = Basis.IDENTITY

## Starts a transformation operation.
func start_transform() -> void:
	if _selected_items.is_empty():
		return
	
	_is_dragging = true
	var gizmo_start_transform := Transform3D(gizmo_basis, gizmo_center)
	var gizmo_start_inv := gizmo_start_transform.affine_inverse()
	
	for item in _selected_items:
		item.initial_global_transform = item.node.global_transform
		# Store the item's transform relative to the gizmo's starting position
		item.local_to_gizmo = gizmo_start_inv * item.initial_global_transform

## Updates the transformation based on a delta change.
## delta_transform: The change applied to the gizmo itself (e.g. translation, rotation, or scale).
func update_transform(delta_transform: Transform3D) -> void:
	if not _is_dragging or _selected_items.is_empty():
		return
	
	var gizmo_start_transform := Transform3D(gizmo_basis, gizmo_center)
	
	for item in _selected_items:
		# The new world transform is:
		# (GizmoStart * Delta) * (ItemLocalToGizmo)
		# This applies the delta relative to the gizmo's origin.
		var new_world_transform := gizmo_start_transform * delta_transform * item.local_to_gizmo
		item.node.global_transform = new_world_transform

## Finalizes the transformation.
func end_transform() -> void:
	_is_dragging = false

## Sets the active mode.
func set_mode(mode: int) -> void:
	current_mode = mode

## Serializes the current handler state.
func save_state() -> Dictionary:
	return {
		"mode": current_mode,
		"center": gizmo_center,
		"basis": gizmo_basis,
		"is_dragging": _is_dragging
	}

## Restores the handler state.
func load_state(data: Dictionary) -> void:
	current_mode = data.get("mode", TransformMode.TRANSLATE)
	gizmo_center = data.get("center", Vector3.ZERO)
	gizmo_basis = data.get("basis", Basis.IDENTITY)
	_is_dragging = data.get("is_dragging", false)

## Utility to calculate a bounding box center for a set of nodes.
static func calculate_center(nodes: Array[Node3D]) -> Vector3:
	if nodes.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for n in nodes:
		sum += n.global_position
	return sum / float(nodes.size())
