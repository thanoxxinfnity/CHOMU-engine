class_name ChomuPerception
extends Node3D
## F-52 Perception: sight cone + line of sight + light check (a target standing
## in darkness is only seen up close), hearing by distance (with an occlusion
## penalty), and a memory whose confidence decays over time.
## Attach to an agent's head. Targets join group "chomu_perceivable".
## Make noise from anywhere: ChomuPerception.emit_noise(get_tree(), pos, loudness)

signal target_spotted(target: Node3D)
signal target_lost(target: Node3D)
signal noise_heard(position: Vector3, loudness: float)

const GROUP_LISTENERS := &"chomu_listeners"

@export var target_group := &"chomu_perceivable"
@export var sight_range := 18.0
@export var fov_deg := 110.0
@export var close_range := 2.5          ## always seen within this, even in the dark
@export var min_luminance := 0.12       ## below this a target is hidden beyond close_range
@export var use_light_check := true
@export var hearing_range := 14.0       ## a loudness-1 sound is heard up to this
@export var occlusion_hearing_mult := 0.5
@export var memory_decay := 0.2         ## confidence lost per second when unseen
@export var forget_below := 0.05
@export var update_hz := 10.0
@export var exclude_bodies: Array[CollisionObject3D] = []

## target(Node3D) -> {pos: Vector3, confidence: float, seen: bool, time: float}
var memory := {}
var last_noise := {}
var _acc := 0.0
var _clock := 0.0

func _ready() -> void:
	add_to_group(GROUP_LISTENERS)

static func emit_noise(tree: SceneTree, pos: Vector3, loudness := 1.0, source: Node = null) -> void:
	for l in tree.get_nodes_in_group(GROUP_LISTENERS):
		(l as ChomuPerception).hear(pos, loudness, source)

func _physics_process(delta: float) -> void:
	_clock += delta
	_acc += delta
	if _acc >= 1.0 / update_hz:
		var dt := _acc
		_acc = 0.0
		sense(dt)

## Sight pass + memory decay. Callable directly from tests.
func sense(dt: float) -> void:
	var space := get_world_3d().direct_space_state
	var seen_now := {}
	for t in get_tree().get_nodes_in_group(target_group):
		var tn := t as Node3D
		if tn == null or not is_instance_valid(tn):
			continue
		if can_see(tn, space):
			seen_now[tn] = true
			var was_seen: bool = memory.has(tn) and memory[tn]["seen"]
			memory[tn] = {"pos": tn.global_position, "confidence": 1.0, "seen": true, "time": _clock}
			if not was_seen:
				target_spotted.emit(tn)
	for t in memory.keys():
		if seen_now.has(t):
			continue
		var m: Dictionary = memory[t]
		if m["seen"]:
			m["seen"] = false
			target_lost.emit(t)
		m["confidence"] = float(m["confidence"]) - memory_decay * dt
		if float(m["confidence"]) < forget_below or not is_instance_valid(t):
			memory.erase(t)

func can_see(t: Node3D, space: PhysicsDirectSpaceState3D) -> bool:
	var eye := global_position
	var aim := t.global_position + Vector3.UP * 1.0
	var to := aim - eye
	var d := to.length()
	if d > sight_range:
		return false
	var fwd := -global_transform.basis.z
	if d > 0.5 and rad_to_deg(fwd.angle_to(to)) > fov_deg * 0.5:
		return false
	if space:
		var q := PhysicsRayQueryParameters3D.create(eye, aim)
		var ex: Array[RID] = []
		for b in exclude_bodies:
			if is_instance_valid(b):
				ex.append(b.get_rid())
		if t is CollisionObject3D:
			ex.append((t as CollisionObject3D).get_rid())
		q.exclude = ex
		if not space.intersect_ray(q).is_empty():
			return false
	if use_light_check and d > close_range:
		var lum := ChomuLightProbe.estimate(get_tree(), aim, null)
		# darker targets must be closer: required luminance grows with distance
		var need := min_luminance * clampf(d / sight_range * 2.0, 0.3, 2.0)
		if lum < need:
			return false
	return true

func hear(pos: Vector3, loudness: float, _source: Node = null) -> bool:
	var d := global_position.distance_to(pos)
	var reach := hearing_range * loudness
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(global_position, pos)
		var ex: Array[RID] = []
		for b in exclude_bodies:
			if is_instance_valid(b):
				ex.append(b.get_rid())
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(pos) > 0.5:
			reach *= occlusion_hearing_mult
	if d > reach:
		return false
	last_noise = {"pos": pos, "loudness": loudness, "time": _clock}
	noise_heard.emit(pos, loudness)
	return true

## Best remembered target or null.
func best_target() -> Node3D:
	var best: Node3D = null
	var bc := 0.0
	for t in memory:
		if is_instance_valid(t) and float(memory[t]["confidence"]) > bc:
			bc = memory[t]["confidence"]
			best = t
	return best

func confidence_of(t: Node3D) -> float:
	return float(memory[t]["confidence"]) if memory.has(t) else 0.0

func sees(t: Node3D) -> bool:
	return memory.has(t) and bool(memory[t]["seen"])
