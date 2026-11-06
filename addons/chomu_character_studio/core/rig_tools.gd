@tool
extends RefCounted
## Rigging: import, humanoid BoneMap / retarget, IK and look-at in one click.

const SU := preload("res://addons/chomu_character_studio/core/scene_util.gd")
const HM := preload("res://addons/chomu_character_studio/core/humanoid_map.gd")
const OUT_DIR := "res://chomu_studio"

## Instantiates a model file (glb/gltf/fbx/blend/tscn) into the edited scene.
static func import_model(ur: EditorUndoRedoManager, path: String) -> Node:
	var r = SU.root()
	if r == null:
		return null
	var ps = load(path)
	if not (ps is PackedScene):
		push_warning("CHoMU Studio: %s is not a scene/model" % path)
		return null
	var inst: Node = (ps as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	inst.name = SU.unique_name(r, path.get_file().get_basename().validate_node_name())
	# only the instance root gets an owner; its children belong to the model file
	ur.create_action("CHoMU: Import %s" % path.get_file(), UndoRedo.MERGE_DISABLE, r)
	ur.add_do_method(r, "add_child", inst, true)
	ur.add_do_method(inst, "set_owner", r)
	ur.add_do_reference(inst)
	ur.add_undo_method(r, "remove_child", inst)
	ur.commit_action()
	return inst

## Builds a humanoid BoneMap, saves it next to the model and writes it into the model's
## import settings (retarget/bone_map), then reimports - the engine's own retarget pipeline
## renames the bones to the humanoid profile and fixes rests on import.
static func setup_humanoid_import(model_path: String) -> Dictionary:
	var res = {"ok": false, "msg": "", "mapped": 0}
	var ps = load(model_path)
	if not (ps is PackedScene):
		res.msg = "Not a model scene: " + model_path
		return res
	var inst: Node = (ps as PackedScene).instantiate()
	var skel = SU.find_child_of_type(inst, "Skeleton3D") as Skeleton3D
	if skel == null:
		inst.free()
		res.msg = "No Skeleton3D in " + model_path
		return res
	var bm = HM.make_bone_map(skel)
	var mapped = HM.map_skeleton(skel).size()
	var skel_path = String(inst.get_path_to(skel))
	inst.free()
	SU.ensure_dir(OUT_DIR)
	var bm_path = "%s/%s_bonemap.tres" % [OUT_DIR, model_path.get_file().get_basename()]
	var err = ResourceSaver.save(bm, bm_path)
	if err != OK:
		res.msg = "Could not save BoneMap (%d)" % err
		return res
	bm = load(bm_path)
	var imp_path = model_path + ".import"
	var cf = ConfigFile.new()
	if cf.load(imp_path) != OK:
		res.msg = "BoneMap saved to %s, but %s was not found (is the file imported?)" % [bm_path, imp_path]
		res.ok = true
		res.mapped = mapped
		return res
	var subs: Dictionary = cf.get_value("params", "_subresources", {})
	var nodes: Dictionary = subs.get("nodes", {})
	var key = "PATH:" + skel_path
	var entry: Dictionary = nodes.get(key, {})
	entry["retarget/bone_map"] = bm
	entry["retarget/bone_renamer/rename_bones"] = true
	entry["retarget/bone_renamer/unique_node/make_unique"] = true
	entry["retarget/rest_fixer/apply_node_transforms"] = true
	entry["retarget/rest_fixer/normalize_position_tracks"] = true
	entry["retarget/rest_fixer/overwrite_axis"] = true
	nodes[key] = entry
	subs["nodes"] = nodes
	cf.set_value("params", "_subresources", subs)
	cf.save(imp_path)
	EditorInterface.get_resource_filesystem().reimport_files(PackedStringArray([model_path]))
	res.ok = true
	res.mapped = mapped
	res.msg = "Humanoid retarget set on %s (%d/56 profile bones mapped). BoneMap: %s" % [model_path.get_file(), mapped, bm_path]
	return res

## Saves only the BoneMap for a skeleton already in the scene.
static func save_bone_map(skel: Skeleton3D) -> String:
	SU.ensure_dir(OUT_DIR)
	var bm = HM.make_bone_map(skel)
	var p = "%s/%s_bonemap.tres" % [OUT_DIR, String(SU.character_of(skel).name).validate_filename()]
	ResourceSaver.save(bm, p)
	return p

## Renames the scene skeleton's bones to SkeletonProfileHumanoid names (undoable).
static func rename_to_humanoid(ur: EditorUndoRedoManager, skel: Skeleton3D) -> int:
	var m = HM.map_skeleton(skel)
	ur.create_action("CHoMU: Rename bones to Humanoid", UndoRedo.MERGE_DISABLE, skel)
	var n = 0
	for prof in m:
		var idx = skel.find_bone(m[prof])
		if idx < 0 or m[prof] == prof:
			continue
		ur.add_do_method(skel, "set_bone_name", idx, prof)
		ur.add_undo_method(skel, "set_bone_name", idx, m[prof])
		n += 1
	ur.commit_action()
	return n

static func _bone_global(skel: Skeleton3D, idx: int) -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(idx).origin

static func _marker(name: String, pos: Vector3, size := 0.08) -> Marker3D:
	var m = Marker3D.new()
	m.name = name
	m.gizmo_extents = size
	m.position = pos
	return m

## One-click IK: TwoBoneIK3D for both arms and legs with targets + poles, plus LookAtModifier3D for the head.
static func setup_ik(ur: EditorUndoRedoManager, skel: Skeleton3D) -> String:
	var map = HM.map_skeleton(skel)
	var ch = SU.character_of(skel)
	var limbs = [
		["LeftArm", "LeftUpperArm", "LeftLowerArm", "LeftHand", Vector3(0, 0, -0.35)],
		["RightArm", "RightUpperArm", "RightLowerArm", "RightHand", Vector3(0, 0, -0.35)],
		["LeftLeg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", Vector3(0, 0, 0.45)],
		["RightLeg", "RightUpperLeg", "RightLowerLeg", "RightFoot", Vector3(0, 0, 0.45)],
	]
	var ok = []
	for l in limbs:
		if map.has(l[1]) and map.has(l[2]) and map.has(l[3]):
			ok.append(l)
	if ok.is_empty():
		return "No arm/leg chains found (mapped %d humanoid bones)." % map.size()
	var inv = ch.global_transform.affine_inverse() if ch is Node3D else Transform3D.IDENTITY
	var forward = Vector3(0, 0, 1)
	if ch is Node3D:
		forward = ((ch as Node3D).global_transform.basis * Vector3(0, 0, 1)).normalized()
	# Containers
	var targets = Node3D.new()
	targets.name = SU.unique_name(ch, "IK_Targets")
	var ik = TwoBoneIK3D.new()
	ik.name = SU.unique_name(skel, "CHoMU_TwoBoneIK")
	ik.set_setting_count(ok.size())
	var i = 0
	for l in ok:
		var end_idx = skel.find_bone(map[l[3]])
		var mid_idx = skel.find_bone(map[l[2]])
		var tgt = _marker(l[0] + "_Target", inv * _bone_global(skel, end_idx), 0.1)
		var pole_off: Vector3 = l[4]
		if forward.dot(Vector3(0, 0, 1)) < 0.0:
			pole_off = -pole_off
		var pole = _marker(l[0] + "_Pole", inv * (_bone_global(skel, mid_idx) + pole_off), 0.06)
		targets.add_child(tgt)
		targets.add_child(pole)
		ik.set_root_bone_name(i, map[l[1]])
		ik.set_middle_bone_name(i, map[l[2]])
		ik.set_end_bone_name(i, map[l[3]])
		i += 1
	SU.add_node(ur, "CHoMU: IK targets", ch, targets)
	SU.add_node(ur, "CHoMU: TwoBoneIK3D", skel, ik)
	# Wire target/pole node paths now that both are in the tree
	i = 0
	for l in ok:
		ik.set_target_node(i, ik.get_path_to(targets.get_node(l[0] + "_Target")))
		ik.set_pole_node(i, ik.get_path_to(targets.get_node(l[0] + "_Pole")))
		i += 1
	var msg = "TwoBoneIK3D: %d chains (%s). Move the markers in IK_Targets to pose." % [ok.size(), ", ".join(ok.map(func(x): return x[0]))]
	var look = setup_look_at(ur, skel, targets)
	if look != "":
		msg += " " + look
	return msg

static func setup_look_at(ur: EditorUndoRedoManager, skel: Skeleton3D, targets_parent: Node = null) -> String:
	var map = HM.map_skeleton(skel)
	if not map.has("Head"):
		return "No head bone for LookAt."
	var ch = SU.character_of(skel)
	var head_idx = skel.find_bone(map["Head"])
	var head_pos = _bone_global(skel, head_idx)
	var forward = Vector3(0, 0, 1)
	if ch is Node3D:
		forward = ((ch as Node3D).global_transform.basis * Vector3(0, 0, 1)).normalized()
	var inv = (ch as Node3D).global_transform.affine_inverse() if ch is Node3D else Transform3D.IDENTITY
	var parent: Node = targets_parent if targets_parent else ch
	var tgt = _marker(SU.unique_name(parent, "LookTarget"), inv * (head_pos + forward * 1.2), 0.12)
	SU.add_node(ur, "CHoMU: Look target", parent, tgt)
	var la = LookAtModifier3D.new()
	la.name = SU.unique_name(skel, "CHoMU_LookAt")
	la.bone_name = map["Head"]
	# pick the head bone axis that points most toward the character's front
	var b = (skel.global_transform * skel.get_bone_global_pose(head_idx)).basis.orthonormalized()
	var axes = [b.x, -b.x, b.y, -b.y, b.z, -b.z]
	var best = 4
	var best_d = -2.0
	for k in 6:
		var d: float = (axes[k] as Vector3).dot(forward)
		if d > best_d:
			best_d = d
			best = k
	la.forward_axis = best
	la.primary_rotation_axis = Vector3.AXIS_Y
	la.use_angle_limitation = true
	la.symmetry_limitation = true
	la.primary_limit_angle = deg_to_rad(70.0)
	la.secondary_limit_angle = deg_to_rad(40.0)
	la.duration = 0.25
	SU.add_node(ur, "CHoMU: LookAtModifier3D", skel, la)
	la.target_node = la.get_path_to(tgt)
	return "LookAtModifier3D on %s (move LookTarget)." % map["Head"]
