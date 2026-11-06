@tool
extends RefCounted
## Animation: AnimationPlayer access, AnimationTree locomotion starter, library retarget, pose keys.

const SU := preload("res://addons/chomu_character_studio/core/scene_util.gd")
const HM := preload("res://addons/chomu_character_studio/core/humanoid_map.gd")
const OUT_DIR := "res://chomu_studio/anims"

static func ensure_player(ur: EditorUndoRedoManager, ch: Node) -> AnimationPlayer:
	var p = SU.find_child_of_type(ch, "AnimationPlayer") as AnimationPlayer
	if p:
		return p
	p = AnimationPlayer.new()
	p.name = "AnimationPlayer"
	SU.add_node(ur, "CHoMU: Add AnimationPlayer", ch, p)
	p.root_node = p.get_path_to(ch)
	return p

static func open_player(p: AnimationPlayer) -> void:
	EditorInterface.edit_node(p)

static func _find_anim(names: PackedStringArray, keys: Array) -> String:
	for k in keys:
		for n in names:
			var short = n.get_slice("/", n.get_slice_count("/") - 1).to_lower()
			if short == k:
				return n
	for k in keys:
		for n in names:
			var short = n.get_slice("/", n.get_slice_count("/") - 1).to_lower()
			if short.begins_with(k) or short.contains(k):
				return n
	return ""

## AnimationTree with a BlendSpace1D "Locomotion" (idle 0, walk 0.5, run 1).
## Drive it from code: $AnimationTree.set("parameters/Locomotion/blend_position", speed01)
static func make_locomotion_tree(ur: EditorUndoRedoManager, ch: Node, p: AnimationPlayer) -> String:
	var names = p.get_animation_list()
	var idle = _find_anim(names, ["idle", "idle_loop", "breathing idle", "stand"])
	var walk = _find_anim(names, ["walk", "walk_loop", "walking"])
	var run = _find_anim(names, ["run", "jog", "sprint", "running", "jog_fwd_loop", "sprint_loop"])
	var bs = AnimationNodeBlendSpace1D.new()
	bs.min_space = 0.0
	bs.max_space = 1.0
	bs.value_label = "speed"
	var used = []
	for pair in [[idle, 0.0, "idle"], [walk, 0.5, "walk"], [run, 1.0, "run"]]:
		var a = AnimationNodeAnimation.new()
		a.animation = StringName(pair[0])
		bs.add_blend_point(a, pair[1], -1, StringName(pair[2]))
		used.append(pair[0] if pair[0] != "" else "(empty)")
	var bt = AnimationNodeBlendTree.new()
	bt.add_node("Locomotion", bs, Vector2(0, 100))
	bt.connect_node("output", 0, "Locomotion")
	var tree = AnimationTree.new()
	tree.name = SU.unique_name(ch, "AnimationTree")
	tree.tree_root = bt
	SU.add_node(ur, "CHoMU: AnimationTree locomotion", ch, tree)
	tree.anim_player = tree.get_path_to(p)
	tree.active = true
	tree.set("parameters/Locomotion/blend_position", 0.0)
	return "AnimationTree + BlendSpace1D: idle=%s, walk=%s, run=%s. Set parameters/Locomotion/blend_position 0..1." % used

static func _loop_hint(n: String) -> bool:
	var l = n.to_lower()
	return l.contains("loop") or l.contains("idle") or l.contains("walk") or l.contains("run") or l.contains("jog") or l.contains("sprint")

## Copies every animation from a model/scene with an AnimationPlayer onto the character's player,
## remapping bone tracks through the humanoid map so differently named rigs line up.
## Rotations are rest-corrected (target_rest * src_rest^-1 * key); only the hips keep position keys.
static func retarget_library(ur: EditorUndoRedoManager, ch: Node, src_path: String, max_anims := 0) -> String:
	var ps = load(src_path)
	if not (ps is PackedScene):
		return "Not a scene: " + src_path
	var src: Node = (ps as PackedScene).instantiate()
	var sp = SU.find_child_of_type(src, "AnimationPlayer") as AnimationPlayer
	var ss = SU.find_child_of_type(src, "Skeleton3D") as Skeleton3D
	var ts = SU.find_child_of_type(ch, "Skeleton3D") as Skeleton3D
	if sp == null or ss == null or ts == null:
		src.free()
		return "Need an AnimationPlayer + Skeleton3D in the library and a Skeleton3D on the character."
	var p = ensure_player(ur, ch)
	var smap = HM.map_skeleton(ss)
	var tmap = HM.map_skeleton(ts)
	var s2p = {}
	for k in smap:
		s2p[smap[k]] = k
	var proot = p.get_node_or_null(p.root_node)
	if proot == null:
		proot = ch
	var skel_path = String(proot.get_path_to(ts))
	var src_hips = ss.find_bone(smap.get("Hips", ""))
	var tgt_hips = ts.find_bone(tmap.get("Hips", ""))
	var hscale = 1.0
	if src_hips >= 0 and tgt_hips >= 0:
		var sh = ss.get_bone_global_rest(src_hips).origin.y
		var th = ts.get_bone_global_rest(tgt_hips).origin.y
		if absf(sh) > 0.001:
			hscale = th / sh
	var lib = AnimationLibrary.new()
	var count = 0
	var skipped_tracks = 0
	for an in sp.get_animation_list():
		if max_anims > 0 and count >= max_anims:
			break
		var a = sp.get_animation(an)
		var na = Animation.new()
		na.length = a.length
		na.loop_mode = a.loop_mode
		if na.loop_mode == Animation.LOOP_NONE and _loop_hint(an):
			na.loop_mode = Animation.LOOP_LINEAR
		for t in a.get_track_count():
			var tt = a.track_get_type(t)
			if tt != Animation.TYPE_ROTATION_3D and tt != Animation.TYPE_POSITION_3D:
				continue
			var path = a.track_get_path(t)
			var sbone = String(path.get_concatenated_subnames())
			if sbone == "":
				continue
			var tbone = ""
			if ts.find_bone(sbone) >= 0 and (not s2p.has(sbone) or tmap.get(s2p[sbone], sbone) == sbone):
				tbone = sbone
			elif s2p.has(sbone) and tmap.has(s2p[sbone]):
				tbone = tmap[s2p[sbone]]
			if tbone == "":
				skipped_tracks += 1
				continue
			var si = ss.find_bone(sbone)
			var ti = ts.find_bone(tbone)
			if tt == Animation.TYPE_POSITION_3D and ti != tgt_hips:
				continue
			var nt = na.add_track(tt)
			na.track_set_path(nt, NodePath(skel_path + ":" + tbone))
			na.track_set_interpolation_type(nt, a.track_get_interpolation_type(t))
			var srest = ss.get_bone_rest(si).basis.get_rotation_quaternion() if si >= 0 else Quaternion.IDENTITY
			var trest = ts.get_bone_rest(ti).basis.get_rotation_quaternion()
			var corr = trest * srest.inverse()
			for k in a.track_get_key_count(t):
				var time = a.track_get_key_time(t, k)
				var v: Variant = a.track_get_key_value(t, k)
				if tt == Animation.TYPE_ROTATION_3D:
					na.rotation_track_insert_key(nt, time, (corr * (v as Quaternion)).normalized())
				else:
					na.position_track_insert_key(nt, time, (v as Vector3) * hscale)
		lib.add_animation(StringName(an.get_slice("/", an.get_slice_count("/") - 1)), na)
		count += 1
	src.free()
	SU.ensure_dir(OUT_DIR)
	var lib_name = src_path.get_file().get_basename().validate_filename().replace(".", "_")
	var lib_path = "%s/%s_retargeted.res" % [OUT_DIR, lib_name]
	ResourceSaver.save(lib, lib_path)
	lib = load(lib_path)
	var key = StringName(lib_name)
	ur.create_action("CHoMU: Retarget %s" % src_path.get_file(), UndoRedo.MERGE_DISABLE, p)
	if p.has_animation_library(key):
		var old = p.get_animation_library(key)
		ur.add_do_method(p, "remove_animation_library", key)
		ur.add_undo_method(p, "add_animation_library", key, old)
		ur.add_undo_method(p, "remove_animation_library", key)
	ur.add_do_method(p, "add_animation_library", key, lib)
	ur.add_undo_method(p, "remove_animation_library", key)
	ur.commit_action()
	return "Retargeted %d animations into library '%s' (%s). Skipped %d unmapped tracks." % [count, key, lib_path, skipped_tracks]

## Inserts rotation (and hips position) keys for the given bones at `time` into animation `anim_name`.
static func key_pose(ur: EditorUndoRedoManager, p: AnimationPlayer, skel: Skeleton3D, bones: Array, anim_name: String, time: float) -> String:
	if anim_name == "":
		anim_name = "pose_take"
	var lib_key = StringName("")
	var short = anim_name
	if anim_name.contains("/"):
		lib_key = StringName(anim_name.get_slice("/", 0))
		short = anim_name.get_slice("/", 1)
	if not p.has_animation_library(lib_key):
		var nl = AnimationLibrary.new()
		ur.create_action("CHoMU: Add animation library", UndoRedo.MERGE_DISABLE, p)
		ur.add_do_method(p, "add_animation_library", lib_key, nl)
		ur.add_undo_method(p, "remove_animation_library", lib_key)
		ur.commit_action()
	var lib = p.get_animation_library(lib_key)
	var anim: Animation
	if lib.has_animation(StringName(short)):
		anim = lib.get_animation(StringName(short))
	else:
		anim = Animation.new()
		anim.length = maxf(1.0, time)
		ur.create_action("CHoMU: New animation " + short, UndoRedo.MERGE_DISABLE, p)
		ur.add_do_method(lib, "add_animation", StringName(short), anim)
		ur.add_undo_method(lib, "remove_animation", StringName(short))
		ur.commit_action()
	var proot = p.get_node_or_null(p.root_node)
	if proot == null:
		proot = SU.character_of(skel)
	var spath = String(proot.get_path_to(skel))
	var original = anim
	anim = anim.duplicate(true)
	if time > anim.length:
		anim.length = time
	var n = 0
	for b in bones:
		var idx: int = skel.find_bone(b) if b is String or b is StringName else int(b)
		if idx < 0:
			continue
		var bn = skel.get_bone_name(idx)
		var path = NodePath(spath + ":" + bn)
		var tr = anim.find_track(path, Animation.TYPE_ROTATION_3D)
		if tr < 0:
			tr = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(tr, path)
		anim.rotation_track_insert_key(tr, time, skel.get_bone_pose_rotation(idx))
		if skel.get_bone_parent(idx) < 0 or bn.to_lower().contains("hip") or bn.to_lower().contains("pelvis"):
			var tp = anim.find_track(path, Animation.TYPE_POSITION_3D)
			if tp < 0:
				tp = anim.add_track(Animation.TYPE_POSITION_3D)
				anim.track_set_path(tp, path)
			anim.position_track_insert_key(tp, time, skel.get_bone_pose_position(idx))
		n += 1
	ur.create_action("CHoMU: Key pose", UndoRedo.MERGE_DISABLE, p)
	ur.add_do_method(lib, "add_animation", StringName(short), anim)
	ur.add_undo_method(lib, "add_animation", StringName(short), original)
	ur.commit_action()
	return "Keyed %d bone(s) at %.2fs in '%s'." % [n, time, anim_name]
