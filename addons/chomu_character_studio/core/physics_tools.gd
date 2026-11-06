@tool
extends RefCounted
## Cloth (SoftBody3D with pinned top vertices) and hair/tail (SpringBoneSimulator3D chains + capsules).

const SU := preload("res://addons/chomu_character_studio/core/scene_util.gd")
const HM := preload("res://addons/chomu_character_studio/core/humanoid_map.gd")

const CLOTH_PRESETS := {
	"Silk": {"linear_stiffness": 0.25, "total_mass": 0.35, "damping_coefficient": 0.02, "drag_coefficient": 0.01, "simulation_precision": 7},
	"Cotton": {"linear_stiffness": 0.55, "total_mass": 0.8, "damping_coefficient": 0.05, "drag_coefficient": 0.02, "simulation_precision": 5},
	"Leather": {"linear_stiffness": 0.9, "total_mass": 1.6, "damping_coefficient": 0.15, "drag_coefficient": 0.0, "simulation_precision": 5},
}

const HAIR_PRESETS := {
	"Soft hair": {"stiffness": 0.6, "drag": 0.35, "gravity": 0.25, "radius": 0.02},
	"Stiff hair": {"stiffness": 2.0, "drag": 0.6, "gravity": 0.05, "radius": 0.02},
	"Long flowing": {"stiffness": 0.3, "drag": 0.2, "gravity": 0.45, "radius": 0.025},
	"Tail": {"stiffness": 1.0, "drag": 0.4, "gravity": 0.5, "radius": 0.04},
}

const HAIR_WORDS := ["hair", "tail", "ponytail", "braid", "bang", "pigtail", "twintail", "ahoge", "ear_tip", "scarf"]

static func _all_vertices(mesh: Mesh) -> PackedVector3Array:
	var out = PackedVector3Array()
	for s in mesh.get_surface_count():
		var arr = mesh.surface_get_arrays(s)
		out.append_array(arr[Mesh.ARRAY_VERTEX])
	return out

## Turns a MeshInstance3D (cape / skirt) into a SoftBody3D, pins the top band of vertices and
## attaches the pins to the nearest chest/hips bone so the cloth follows the character.
static func add_cloth(ur: EditorUndoRedoManager, mi: MeshInstance3D, preset: String, pin_band := 0.08) -> String:
	if mi == null or mi.mesh == null:
		return "Select a cape/skirt MeshInstance3D first."
	if mi is SoftBody3D:
		apply_cloth_preset(ur, mi as SoftBody3D, preset)
		return "Updated cloth preset to %s." % preset
	var parent = mi.get_parent()
	var sb = SoftBody3D.new()
	sb.name = SU.unique_name(parent, String(mi.name) + "_Cloth")
	sb.mesh = mi.mesh
	sb.transform = mi.transform
	for s in mi.mesh.get_surface_count():
		var m = mi.get_surface_override_material(s)
		if m:
			sb.set_surface_override_material(s, m)
	if mi.material_override:
		sb.material_override = mi.material_override
	var p: Dictionary = CLOTH_PRESETS.get(preset, CLOTH_PRESETS["Cotton"])
	for k in p:
		sb.set(k, p[k])
	# pin vertices of the first surface (SoftBody3D point indices follow surface 0's vertex array)
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var miny = INF
	var maxy = -INF
	for v in verts:
		miny = minf(miny, v.y)
		maxy = maxf(maxy, v.y)
	var thr = maxy - (maxy - miny) * pin_band
	var pins = []
	for i in verts.size():
		if verts[i].y >= thr:
			pins.append(i)
	SU.add_node(ur, "CHoMU: Cloth (%s)" % preset, parent, sb, true)
	# attach pins to a bone so the cloth rides on the body
	var skel = SU.find_skeleton(parent)
	var attach_msg = "pinned in place"
	var attach_path = NodePath("")
	if skel:
		var map = HM.map_skeleton(skel)
		var bone = ""
		var top_global = mi.global_transform * Vector3(0, maxy, 0)
		var best = INF
		for cand in ["UpperChest", "Chest", "Spine", "Hips", "Neck"]:
			if map.has(cand):
				var bp = skel.global_transform * skel.get_bone_global_pose(skel.find_bone(map[cand])).origin
				var d = bp.distance_to(top_global)
				if d < best:
					best = d
					bone = map[cand]
		if bone != "":
			var ba = BoneAttachment3D.new()
			ba.name = SU.unique_name(skel, "ClothPin_" + bone)
			ba.bone_name = bone
			SU.add_node(ur, "CHoMU: Cloth pin attachment", skel, ba)
			attach_path = sb.get_path_to(ba)
			attach_msg = "pinned to bone " + bone
	for i in pins:
		sb.set_point_pinned(i, true, attach_path)
	SU.set_prop(ur, "CHoMU: hide source mesh", mi, "visible", false)
	return "SoftBody3D '%s' (%s): %d vertices %s. Original mesh hidden. Press Play to simulate." % [sb.name, preset, pins.size(), attach_msg]

static func apply_cloth_preset(ur: EditorUndoRedoManager, sb: SoftBody3D, preset: String) -> void:
	var p: Dictionary = CLOTH_PRESETS.get(preset, CLOTH_PRESETS["Cotton"])
	ur.create_action("CHoMU: Cloth preset " + preset, UndoRedo.MERGE_DISABLE, sb)
	for k in p:
		ur.add_do_property(sb, k, p[k])
		ur.add_undo_property(sb, k, sb.get(k))
	ur.commit_action()

static func _is_hair(name: String) -> bool:
	var l = name.to_lower()
	for w in HAIR_WORDS:
		if l.contains(w):
			return true
	return false

## Finds hair/tail chains: [root_bone, end_bone] pairs.
static func find_chains(skel: Skeleton3D) -> Array:
	var chains = []
	for i in skel.get_bone_count():
		if not _is_hair(skel.get_bone_name(i)):
			continue
		var par = skel.get_bone_parent(i)
		if par >= 0 and _is_hair(skel.get_bone_name(par)):
			continue
		var end = i
		while true:
			var kids = skel.get_bone_children(end)
			var nxt = -1
			for k in kids:
				if _is_hair(skel.get_bone_name(k)):
					nxt = k
					break
			if nxt < 0:
				break
			end = nxt
		if end != i or skel.get_bone_children(i).is_empty():
			chains.append([skel.get_bone_name(i), skel.get_bone_name(end)])
	return chains

## Adds a bone chain (ponytail/tail) to the skeleton under `parent_bone`. Returns the root name.
## Note: on an imported (instanced) skeleton, new bones only persist if the scene is made local.
static func create_chain(skel: Skeleton3D, parent_bone: String, base_name: String, count := 5, seg := 0.07, dir := Vector3(0, -0.6, -0.8)) -> String:
	var par = skel.find_bone(parent_bone)
	if par < 0:
		return ""
	var gpar = skel.get_bone_global_rest(par)
	var d_global = dir.normalized() * seg
	var prev = par
	var prev_global = gpar
	var root_name = ""
	for i in count:
		var nm = "%s_%02d" % [base_name, i + 1]
		var idx = skel.add_bone(nm)
		skel.set_bone_parent(idx, prev)
		var g = Transform3D(Basis.IDENTITY, prev_global.origin + (d_global if i > 0 else Vector3(0, 0.06, -0.09)))
		var local = prev_global.affine_inverse() * g
		skel.set_bone_rest(idx, local)
		skel.set_bone_pose(idx, local)
		prev = idx
		prev_global = g
		if i == 0:
			root_name = nm
	return root_name

static func add_spring_bones(ur: EditorUndoRedoManager, skel: Skeleton3D, preset: String, chains: Array, with_colliders := true) -> String:
	if chains.is_empty():
		return "No hair/tail bones found (names containing hair, tail, ponytail, braid...). Use 'Create ponytail chain' first."
	var p: Dictionary = HAIR_PRESETS.get(preset, HAIR_PRESETS["Soft hair"])
	var sim = SpringBoneSimulator3D.new()
	sim.name = SU.unique_name(skel, "CHoMU_SpringBones")
	sim.set_setting_count(chains.size())
	for i in chains.size():
		sim.set_root_bone_name(i, chains[i][0])
		sim.set_end_bone_name(i, chains[i][1])
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_length(i, 0.05)
		sim.set_stiffness(i, p.stiffness)
		sim.set_drag(i, p.drag)
		sim.set_gravity(i, p.gravity)
		sim.set_radius(i, p.radius)
		sim.set_enable_all_child_collisions(i, with_colliders)
	var ncol = 0
	if with_colliders:
		var map = HM.map_skeleton(skel)
		var caps = [["Head", 0.1, 0.24, Vector3(0, 0.06, 0)], ["Neck", 0.06, 0.16, Vector3.ZERO], ["UpperChest", 0.13, 0.42, Vector3(0, 0.05, 0)],
			["LeftUpperArm", 0.05, 0.26, Vector3(0, 0.12, 0)], ["RightUpperArm", 0.05, 0.26, Vector3(0, 0.12, 0)]]
		if not map.has("UpperChest") and map.has("Chest"):
			caps[2][0] = "Chest"
		for c in caps:
			if not map.has(c[0]):
				continue
			var cc = SpringBoneCollisionCapsule3D.new()
			cc.name = "Col_" + c[0]
			cc.bone_name = map[c[0]]
			cc.radius = c[1]
			cc.height = c[2]
			cc.position_offset = c[3]
			if c[0].ends_with("Chest"):
				cc.rotation_offset = Quaternion(Vector3(0, 0, 1), PI * 0.5)
			sim.add_child(cc)
			ncol += 1
	SU.add_node(ur, "CHoMU: Spring bones (%s)" % preset, skel, sim, true)
	return "SpringBoneSimulator3D: %d chain(s) [%s], preset %s, %d collision capsules." % [chains.size(), ", ".join(chains.map(func(c): return c[0])), preset, ncol]

static func apply_hair_preset(ur: EditorUndoRedoManager, sim: SpringBoneSimulator3D, preset: String) -> void:
	var p: Dictionary = HAIR_PRESETS.get(preset, HAIR_PRESETS["Soft hair"])
	ur.create_action("CHoMU: Hair preset " + preset, UndoRedo.MERGE_DISABLE, sim)
	for i in sim.get_setting_count():
		ur.add_do_method(sim, "set_stiffness", i, p.stiffness)
		ur.add_undo_method(sim, "set_stiffness", i, sim.get_stiffness(i))
		ur.add_do_method(sim, "set_drag", i, p.drag)
		ur.add_undo_method(sim, "set_drag", i, sim.get_drag(i))
		ur.add_do_method(sim, "set_gravity", i, p.gravity)
		ur.add_undo_method(sim, "set_gravity", i, sim.get_gravity(i))
	ur.commit_action()
