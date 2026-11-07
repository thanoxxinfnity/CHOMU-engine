extends RefCounted
class_name ChomuDebugDrawGizmoPipeline

## Debug Draw Gizmo Pipeline
##
## A data-driven debug visualization system for drawing invisible colliders,
## lines, and light icons on screen. Designed mobile-first (NEON path, low RAM)
## with deterministic seeded RNG and Dictionary save/load state.
##
## Usage:
##   var pipeline := ChomuDebugDrawGizmoPipeline.new()
##   pipeline.register_gizmo("player_collider", {type: "sphere", color: Color(1,0,0,0.5), radius: 1.0})
##   pipeline.update_gizmo_transform("player_collider", player.global_transform)
##   pipeline.draw(canvas_item, delta)

## Gizmo type identifiers.
const GIZMO_NONE: int = 0
const GIZMO_LINE: int = 1
const GIZMO_SPHERE: int = 2
const GIZMO_BOX: int = 3
const GIZMO_LIGHT: int = 4

## Configuration for a single registered gizmo.
class GizmoConfig:
	var id: String = ""
	var type: int = GIZMO_NONE
	var color: Color = Color(1, 1, 1, 1)
	var thickness: float = 2.0
	var radius: float = 0.5
	var size: Vector3 = Vector3.ONE
	var from: Vector3 = Vector3.ZERO
	var to: Vector3 = Vector3.ZERO
	var light_type: String = "point" # "point", "directional", "spot"
	var enabled: bool = true
	var depth_test: bool = false
	var persistent: bool = false # survives clear_frame()

## Runtime instance of a gizmo, tracking its current world transform.
class GizmoInstance:
	var config: GizmoConfig
	var transform: Transform3D = Transform3D.IDENTITY
	var visible: bool = true
	var last_draw_tick: int = 0

## Result of a draw call, describing what was emitted.
class DrawResult:
	var gizmo_id: String = ""
	var type: int = GIZMO_NONE
	var color: Color = Color(1, 1, 1, 1)
	var points: PackedVector3Array = PackedVector3Array()
	var transform: Transform3D = Transform3D.IDENTITY
	var last_draw_tick: int = 0

## Signal emitted when a gizmo is registered.
signal gizmo_registered(id: String, config: GizmoConfig)
## Signal emitted when a gizmo is removed.
signal gizmo_removed(id: String)
## Signal emitted at the end of each frame's draw pass.
signal frame_drawn(results: Array[DrawResult])

var _gizmos: Dictionary = {} # String -> GizmoConfig
var _instances: Dictionary = {} # String -> GizmoInstance
var _draw_order: Array[String] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tick: int = 0
var _max_results_per_frame: int = 1024
var _default_color: Color = Color(1, 1, 1, 1)
var _default_thickness: float = 2.0
var _seed: int = 12345

## Seeds the internal RNG for deterministic gizmo jitter / sampling.
func set_seed(seed: int) -> void:
	_seed = seed
	_rng.seed = seed

## Returns the current seed.
func get_seed() -> int:
	return _seed

## Sets the maximum number of DrawResult entries emitted per frame (RAM guard).
func set_max_results_per_frame(limit: int) -> void:
	_max_results_per_frame = max(1, limit)

## Returns the current per-frame result cap.
func get_max_results_per_frame() -> int:
	return _max_results_per_frame

## Registers a new gizmo configuration. Returns its id.
func register_gizmo(id: String, config: Dictionary) -> String:
	if id in _gizmos:
		push_warning("ChomuDebugDrawGizmoPipeline: gizmo id already exists: %s" % id)
		return id
	var gc = GizmoConfig.new()
	gc.id = id
	gc.type = int(config.get("type", GIZMO_NONE))
	gc.color = config.get("color", _default_color)
	gc.thickness = float(config.get("thickness", _default_thickness))
	gc.radius = float(config.get("radius", 0.5))
	gc.size = config.get("size", Vector3.ONE)
	gc.from = config.get("from", Vector3.ZERO)
	gc.to = config.get("to", Vector3.ZERO)
	gc.light_type = config.get("light_type", "point")
	gc.enabled = bool(config.get("enabled", true))
	gc.depth_test = bool(config.get("depth_test", false))
	gc.persistent = bool(config.get("persistent", false))
	_gizmos[id] = gc
	var inst := GizmoInstance.new()
	inst.config = gc
	inst.transform = Transform3D.IDENTITY
	_instances[id] = inst
	_draw_order.append(id)
	gizmo_registered.emit(id, gc)
	return id

## Removes a registered gizmo by id. Returns true if removed.
func unregister_gizmo(id: String) -> bool:
	if not id in _gizmos:
		return false
	_gizmos.erase(id)
	_instances.erase(id)
	_draw_order.erase(id)
	gizmo_removed.emit(id)
	return true

## Returns true if a gizmo id is registered.
func has_gizmo(id: String) -> bool:
	return id in _gizmos

## Returns the GizmoConfig for an id, or null.
func get_gizmo_config(id: String) -> GizmoConfig:
	return _gizmos.get(id, null)

## Updates a gizmo's configuration fields from a dictionary.
func update_gizmo_config(id: String, config: Dictionary) -> bool:
	if not id in _gizmos:
		return false
	var gc = _gizmos[id]
	if config.has("type"): gc.type = int(config["type"])
	if config.has("color"): gc.color = config["color"]
	if config.has("thickness"): gc.thickness = float(config["thickness"])
	if config.has("radius"): gc.radius = float(config["radius"])
	if config.has("size"): gc.size = config["size"]
	if config.has("from"): gc.from = config["from"]
	if config.has("to"): gc.to = config["to"]
	if config.has("light_type"): gc.light_type = config["light_type"]
	if config.has("enabled"): gc.enabled = bool(config["enabled"])
	if config.has("depth_test"): gc.depth_test = bool(config["depth_test"])
	if config.has("persistent"): gc.persistent = bool(config["persistent"])
	return true

## Sets the world transform for a gizmo instance. Returns true if updated.
func update_gizmo_transform(id: String, transform: Transform3D) -> bool:
	if not id in _instances:
		return false
	_instances[id].transform = transform
	return true

## Sets visibility for a gizmo instance. Returns true if updated.
func set_gizmo_visible(id: String, visible: bool) -> bool:
	if not id in _instances:
		return false
	_instances[id].visible = visible
	return true

## Enables or disables a gizmo by id. Returns true if updated.
func set_gizmo_enabled(id: String, enabled: bool) -> bool:
	if not id in _gizmos:
		return false
	_gizmos[id].enabled = enabled
	return true

## Clears all non-persistent gizmo instances/transforms for the next frame.
func clear_frame() -> void:
	for id in _draw_order:
		var inst := _instances.get(id, null)
		if inst == null:
			continue
		var cfg := _gizmos.get(id, null)
		if cfg == null:
			continue
		if not cfg.persistent:
			inst.visible = false

## Advances the internal tick counter.
func tick() -> void:
	_tick += 1

## Returns the current tick.
func get_tick() -> int:
	return _tick

## Builds DrawResult entries for all enabled, visible gizmos.
## Pass a CanvasItem (or any Object) as target for API compatibility.
func draw(target: Object = null, delta: float = 0.0) -> Array[DrawResult]:
	var results: Array[DrawResult] = []
	var count: int = 0
	for id in _draw_order:
		if count >= _max_results_per_frame:
			break
		var inst := _instances.get(id, null)
		var cfg := _gizmos.get(id, null)
		if inst == null or cfg == null:
			continue
		if not cfg.enabled or not inst.visible:
			continue
		var dr := _build_result(id, cfg, inst)
		if dr != null:
			results.append(dr)
			count += 1
	frame_drawn.emit(results)
	return results

## Internal builder: creates a DrawResult from config + instance.
func _build_result(id: String, cfg: GizmoConfig, inst: GizmoInstance) -> DrawResult:
	var dr := DrawResult.new()
	dr.gizmo_id = id
	dr.type = cfg.type
	dr.color = cfg.color
	dr.transform = inst.transform
	dr.last_draw_tick = _tick
	match cfg.type:
		GIZMO_LINE:
			dr.points = PackedVector3Array([cfg.from, cfg.to])
		GIZMO_SPHERE:
			dr.points = _generate_sphere_points(cfg.radius, 12)
		GIZMO_BOX:
			dr.points = _generate_box_points(cfg.size)
		GIZMO_LIGHT:
			dr.points = _generate_light_icon_points(cfg.light_type, cfg.radius)
		_:
			dr.points = PackedVector3Array([Vector3.ZERO])
	return dr

## Generates a circle of points on the XY sphere for wireframe drawing.
func _generate_sphere_points(radius: float, segments: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	var step: float = TAU / segments
	for i in range(segments + 1):
		var ang: float = i * step
		var x: float = cos(ang) * radius
		var y: float = sin(ang) * radius
		points.append(Vector3(x, y, 0.0))
	for i in range(segments + 1):
		var ang: float = i * step
		var x: float = cos(ang) * radius
		var z: float = sin(ang) * radius
		points.append(Vector3(x, 0.0, z))
	return points

## Generates the 8 corners of an axis-aligned box centered at origin.
func _generate_box_points(size: Vector3) -> PackedVector3Array:
	var h: Vector3 = size * 0.5
	var points := PackedVector3Array()
	points.append(Vector3(-h.x, -h.y, -h.z))
	points.append(Vector3(h.x, -h.y, -h.z))
	points.append(Vector3(h.x, h.y, -h.z))
	points.append(Vector3(-h.x, h.y, -h.z))
	points.append(Vector3(-h.x, -h.y, h.z))
	points.append(Vector3(h.x, -h.y, h.z))
	points.append(Vector3(h.x, h.y, h.z))
	points.append(Vector3(-h.x, h.y, h.z))
	return points

## Generates a simple light icon (cross for point, cone for spot, arrow for directional).
func _generate_light_icon_points(light_type: String, radius: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	match light_type:
		"point":
			points.append(Vector3(-radius, 0, 0))
			points.append(Vector3(radius, 0, 0))
			points.append(Vector3(0, -radius, 0))
			points.append(Vector3(0, radius, 0))
			points.append(Vector3(0, 0, -radius))
			points.append(Vector3(0, 0, radius))
		"spot":
			points.append(Vector3(0, 0, 0))
			points.append(Vector3(0, 0, radius))
			points.append(Vector3(-radius * 0.5, 0, radius * 0.5))
			points.append(Vector3(0, 0, radius))
			points.append(Vector3(radius * 0.5, 0, radius * 0.5))
		"directional":
			points.append(Vector3(0, 0, radius))
			points.append(Vector3(0, 0, -radius))
			points.append(Vector3(-radius * 0.3, radius * 0.3, 0))
			points.append(Vector3(0, 0, -radius))
			points.append(Vector3(radius * 0.3, radius * 0.3, 0))
		_:
			points.append(Vector3.ZERO)
	return points

## Serializes all gizmo configs and instance transforms to a Dictionary.
func save_state() -> Dictionary:
	var data: Dictionary = {}
	data["seed"] = _seed
	data["tick"] = _tick
	data["max_results_per_frame"] = _max_results_per_frame
	data["default_color"] = _default_color
	data["default_thickness"] = _default_thickness
	var cfgs: Array[Dictionary] = []
	for id in _draw_order:
		var cfg := _gizmos.get(id, null)
		if cfg == null:
			continue
		var d: Dictionary = {}
		d["id"] = cfg.id
		d["type"] = cfg.type
		d["color"] = cfg.color
		d["thickness"] = cfg.thickness
		d["radius"] = cfg.radius
		d["size"] = cfg.size
		d["from"] = cfg.from
		d["to"] = cfg.to
		d["light_type"] = cfg.light_type
		d["enabled"] = cfg.enabled
		d["depth_test"] = cfg.depth_test
		d["persistent"] = cfg.persistent
		cfgs.append(d)
	data["gizmos"] = cfgs
	var insts: Array[Dictionary] = []
	for id in _draw_order:
		var inst := _instances.get(id, null)
		if inst == null:
			continue
		var d: Dictionary = {}
		d["id"] = id
		d["transform"] = inst.transform
		d["visible"] = inst.visible
		insts.append(d)
	data["instances"] = insts
	return data

## Loads gizmo configs and instance transforms from a Dictionary.
func load_state(data: Dictionary) -> void:
	clear_all()
	if data.has("seed"):
		set_seed(int(data["seed"]))
	if data.has("tick"):
		_tick = int(data["tick"])
	if data.has("max_results_per_frame"):
		_max_results_per_frame = int(data["max_results_per_frame"])
	if data.has("default_color"):
		_default_color = data["default_color"]
	if data.has("default_thickness"):
		_default_thickness = float(data["default_thickness"])
	if data.has("gizmos"):
		for d in data["gizmos"]:
			var id := String(d.get("id", ""))
			var cfg: Dictionary = {
				"type": d.get("type", GIZMO_NONE),
				"color": d.get("color", _default_color),
				"thickness": d.get("thickness", _default_thickness),
				"radius": d.get("radius", 0.5),
				"size": d.get("size", Vector3.ONE),
				"from": d.get("from", Vector3.ZERO),
				"to": d.get("to", Vector3.ZERO),
				"light_type": d.get("light_type", "point"),
				"enabled": d.get("enabled", true),
				"depth_test": d.get("depth_test", false),
				"persistent": d.get("persistent", false),
			}
			register_gizmo(id, cfg)
	if data.has("instances"):
		for d in data["instances"]:
			var id := String(d.get("id", ""))
			if id in _instances:
				_instances[id].transform = d.get("transform", Transform3D.IDENTITY)
				_instances[id].visible = bool(d.get("visible", true))

## Removes all gizmos and resets counters.
func clear_all() -> void:
	for id in _draw_order.duplicate():
		unregister_gizmo(id)
	_tick = 0
	_draw_order.clear()
	_gizmos.clear()
	_instances.clear()
