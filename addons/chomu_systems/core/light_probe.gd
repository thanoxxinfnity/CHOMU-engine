class_name ChomuLightProbe
extends RefCounted
## CPU luminance estimate at a world point (F-41-lite, used by Perception,
## TensionDirector and FearExposure). Sums Omni/Spot lights with range
## attenuation, spot cone and an optional occlusion raycast, plus ambient.
## Result is roughly 0 (pitch black) .. 1+ (well lit).

static var _lights: Array[Light3D] = []
static var _last_scan_ms: int = -100000
const RESCAN_MS := 1000

static func _refresh(tree: SceneTree) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_scan_ms < RESCAN_MS and not _lights.is_empty():
		return
	_last_scan_ms = now
	_lights.clear()
	if tree == null or tree.root == null:
		return
	for n in tree.root.find_children("*", "Light3D", true, false):
		_lights.append(n as Light3D)

static func invalidate() -> void:
	_last_scan_ms = -100000
	_lights.clear()

## Luminance at `pos`. `space` enables occlusion rays (pass null to skip).
static func estimate(tree: SceneTree, pos: Vector3, space: PhysicsDirectSpaceState3D = null, ambient: float = 0.02, exclude: Array[RID] = []) -> float:
	_refresh(tree)
	var total := ambient
	for l in _lights:
		if not is_instance_valid(l) or not l.is_inside_tree() or not l.visible:
			continue
		var e := l.light_energy
		if e <= 0.0:
			continue
		if l is DirectionalLight3D:
			var dl := l as DirectionalLight3D
			var c := e * 0.5
			if space and dl.shadow_enabled:
				var dir := dl.global_transform.basis.z.normalized()
				if _blocked(space, pos, pos + dir * 200.0, exclude):
					c = 0.0
			total += c
			continue
		var lpos := l.global_position
		var d := pos.distance_to(lpos)
		var rng := 5.0
		if l is OmniLight3D:
			rng = (l as OmniLight3D).omni_range
		elif l is SpotLight3D:
			rng = (l as SpotLight3D).spot_range
		if d >= rng:
			continue
		var att := pow(1.0 - d / rng, 2.0)
		if l is SpotLight3D:
			var sl := l as SpotLight3D
			var fwd := -sl.global_transform.basis.z.normalized()
			var ang := rad_to_deg(fwd.angle_to((pos - lpos).normalized()))
			if ang > sl.spot_angle:
				continue
			att *= 1.0 - smoothstep(sl.spot_angle * 0.7, sl.spot_angle, ang)
		var c2 := e * att
		if c2 > 0.005 and space and _blocked(space, lpos, pos, exclude):
			c2 = 0.0
		total += c2
	return total

static func _blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	return (hit["position"] as Vector3).distance_to(to) > 0.3
