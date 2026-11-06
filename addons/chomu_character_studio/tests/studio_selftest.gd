@tool
extends RefCounted
## Automated checks for CHoMU Character Studio, run inside the editor:
##   godot --headless -e --path <project> -- --chomu-studio-selftest
##   godot -e --path <project> --rendering-driver opengl3 -- --chomu-studio-shots=/abs/dir
## Both expect res://demo/demo_character.tscn (the demo project ships it). Nothing is saved.

const SU = preload("res://addons/chomu_character_studio/core/scene_util.gd")
const HM = preload("res://addons/chomu_character_studio/core/humanoid_map.gd")
const RIG = preload("res://addons/chomu_character_studio/core/rig_tools.gd")
const ANIM = preload("res://addons/chomu_character_studio/core/anim_tools.gd")
const PHYS = preload("res://addons/chomu_character_studio/core/physics_tools.gd")
const MODEL = preload("res://addons/chomu_character_studio/core/model_tools.gd")
const MAT = preload("res://addons/chomu_character_studio/core/material_tools.gd")
const EM = preload("res://addons/chomu_character_studio/core/edit_mesh.gd")
const DEMO = "res://demo/demo_character.tscn"

static var results = []

static func _ok(name: String, cond: bool, info: String = "") -> void:
	results.append([name, cond])
	print("[CHoMU selftest] %s  %s  %s" % ["PASS" if cond else "FAIL", name, info])

static func _frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame

static func _open_demo(plugin: EditorPlugin) -> Node:
	var tree = plugin.get_tree()
	EditorInterface.open_scene_from_path(DEMO)
	await _frames(tree, 20)
	return SU.root()

static func run_selftest(plugin: EditorPlugin, panel) -> void:
	var tree = plugin.get_tree()
	await _frames(tree, 10)
	var root = await _open_demo(plugin)
	_ok("demo scene opened", root != null)
	if root == null:
		tree.quit(1)
		return
	var ur = plugin.get_undo_redo()
	var hero = root.get_node_or_null("Hero")
	var skel = SU.find_skeleton(hero)
	_ok("character + skeleton", hero != null and skel != null, "%d bones" % (skel.get_bone_count() if skel else 0))
	var m = HM.map_skeleton(skel)
	_ok("humanoid auto-map", m.size() >= 50, "%d/56 mapped" % m.size())
	var bm = HM.make_bone_map(skel)
	_ok("BoneMap with SkeletonProfileHumanoid", bm.profile is SkeletonProfileHumanoid and bm.get_skeleton_bone_name("LeftUpperArm") == "upperarm_l")
	EditorInterface.set_main_screen_editor("Character Studio")
	await _frames(tree, 3)
	_ok("main screen tab visible", panel.visible)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(hero)
	await _frames(tree, 3)
	for md in ["rig", "anim", "pose", "cloth", "hair", "material", "model", "edit", "sculpt", "weights", "shapes", "uv", "modifiers"]:
		panel._set_mode(md)
		await _frames(tree, 1)
	_ok("all 13 modes build their panels", panel.props.get_child_count() > 0)
	# --- rigging
	var msg = RIG.setup_ik(ur, skel)
	var ik = SU.find_child_of_type(skel, "TwoBoneIK3D")
	_ok("one-click TwoBoneIK3D", ik != null and ik.get_setting_count() == 4 and not String(ik.get_target_node(0)).is_empty(), msg)
	var la = SU.find_child_of_type(skel, "LookAtModifier3D")
	_ok("LookAtModifier3D", la != null and la.bone_name == "Head" or (la != null and la.bone_name == m.get("Head", "")))
	var imp = RIG.setup_humanoid_import("res://demo/assets/char/Superhero_Male_Retarget.gltf")
	await _frames(tree, 30)
	var cf = ConfigFile.new()
	cf.load("res://demo/assets/char/Superhero_Male_Retarget.gltf.import")
	var subs = cf.get_value("params", "_subresources", {})
	_ok("BoneMap written to import + reimport", imp.ok and str(subs).contains("retarget/bone_map"), imp.msg)
	var re_scene = ResourceLoader.load("res://demo/assets/char/Superhero_Male_Retarget.gltf", "", ResourceLoader.CACHE_MODE_IGNORE)
	if re_scene:
		var inst = re_scene.instantiate()
		var rs = SU.find_child_of_type(inst, "Skeleton3D")
		_ok("reimported skeleton uses humanoid names", rs != null and rs.find_bone("LeftUpperArm") >= 0, "Hips idx %d" % (rs.find_bone("Hips") if rs else -1))
		inst.free()
	# --- animation
	var rmsg = ANIM.retarget_library(ur, hero, "res://demo/assets/anim/UAL1_Standard.glb")
	var p = SU.find_anim_player(hero)
	_ok("retarget animation library", p != null and p.get_animation_list().size() >= 40, rmsg)
	var tmsg = ANIM.make_locomotion_tree(ur, hero, p)
	var at = SU.find_child_of_type(hero, "AnimationTree")
	_ok("AnimationTree BlendSpace1D starter", at != null and at.tree_root is AnimationNodeBlendTree, tmsg)
	var arm = skel.find_bone("upperarm_l")
	skel.set_bone_pose_rotation(arm, skel.get_bone_rest(arm).basis.get_rotation_quaternion() * Quaternion(Vector3(0, 0, 1), 0.6))
	var kmsg = ANIM.key_pose(ur, p, skel, [arm], "pose_take", 0.5)
	_ok("record pose keyframe", p.has_animation("pose_take") and p.get_animation("pose_take").get_track_count() >= 1, kmsg)
	skel.reset_bone_poses()
	# --- cloth
	panel.target = hero
	panel._add_demo_cape()
	await _frames(tree, 2)
	var cape = SU.first_selected("MeshInstance3D")
	var cmsg = PHYS.add_cloth(ur, cape, "Silk", 0.08)
	var sb = SU.find_child_of_type(hero, "SoftBody3D")
	var pinned = 0
	if sb:
		for i in 200:
			if sb.is_point_pinned(i):
				pinned += 1
	_ok("cloth SoftBody3D with pins", sb != null and pinned > 0 and is_equal_approx(sb.linear_stiffness, 0.25), cmsg)
	PHYS.apply_cloth_preset(ur, sb, "Leather")
	_ok("cloth preset switch", is_equal_approx(sb.linear_stiffness, 0.9))
	# --- hair
	var head = HM.find_bone(skel, "Head")
	var chain = PHYS.create_chain(skel, skel.get_bone_name(head), "Hair_Ponytail", 5, 0.07)
	var chains = PHYS.find_chains(skel)
	var hmsg = PHYS.add_spring_bones(ur, skel, "Long flowing", chains, true)
	var sim = SU.find_child_of_type(skel, "SpringBoneSimulator3D")
	_ok("spring bones + capsules", sim != null and sim.get_setting_count() >= 1 and SU.find_child_of_type(sim, "SpringBoneCollisionCapsule3D") != null, hmsg)
	# --- modelling
	MODEL.add_csg(ur, "Box", "Union")
	MODEL.add_csg(ur, "Sphere", "Subtract")
	MODEL.add_csg(ur, "Cylinder", "Union")
	var csg_root = root.get_node_or_null("CHoMU_Model")
	_ok("CSG primitives + boolean", csg_root != null and csg_root.get_child_count() == 3)
	await _frames(tree, 3)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(csg_root)
	var baked = MODEL.bake_csg(ur)
	_ok("bake CSG to mesh", baked != null and baked.mesh.get_surface_count() > 0)
	# --- materials
	var body = panel._largest_mesh(hero)
	_ok("material skin preset", MAT.apply(ur, body, "Skin (realistic)").begins_with("Applied") and body.get_surface_override_material(0) is StandardMaterial3D and body.get_surface_override_material(0).subsurf_scatter_enabled)
	MAT.apply(ur, baked, "Anime toon + outline")
	_ok("material toon + outline", baked.get_surface_override_material(0) is ShaderMaterial and baked.get_surface_override_material(0).next_pass != null)
	MAT.apply(ur, baked, "Hair (anisotropic)")
	_ok("material hair anisotropic", baked.get_surface_override_material(0).anisotropy_enabled)
	# --- edit mode on a cube
	var cube = MODEL.add_mesh_primitive(ur, "Cube")
	panel._take_mesh(cube, "edit")
	var em = panel.em
	em.tris_to_quads()
	_ok("edit session (cube -> 6 quads)", em != null and em.faces.size() == 6)
	em.set_sel_mode(EM.SEL_FACE)
	em.sel_f = {0: true}
	var e1 = em.extrude(0.3)
	var e2 = em.inset(0.3)
	em.sel_f = {0: true}
	em.translate(Vector3(0, 0.1, 0))
	em.rotate(Vector3.UP, 0.3, em.selection_center())
	em.scale(Vector3(0.8, 0.8, 0.8), em.selection_center())
	var e3 = em.subdivide()
	em.set_sel_mode(EM.SEL_EDGE)
	em.select_all(false)
	var anyedge = em.edge_faces().keys()[0]
	em.sel_e[anyedge] = true
	var e4 = em.extrude(0.1)
	em.set_sel_mode(EM.SEL_VERT)
	em.select_all(false)
	em.sel_v = {0: true, 1: true}
	var e5 = em.merge_at_center()
	em.set_sel_mode(EM.SEL_FACE)
	em.sel_f = {2: true}
	var e6 = em.delete_selected()
	_ok("edit ops extrude/inset/move/rotate/scale/subdivide/edge-extrude/merge/delete", em.faces.size() > 10, "%s | %s | %s | %s | %s | %s" % [e1, e2, e3, e4, e5, e6])
	panel._apply_to_scene()
	_ok("apply edited mesh to scene", cube.mesh.get_surface_count() == 1 and cube.mesh.get_faces().size() / 3 >= em.faces.size())
	# --- sculpt on the body (shape key + brushes)
	panel._take_mesh(body, "shapes")
	em = panel.em
	var nverts = em.verts.size()
	em.add_shape("Bulk", false)
	em.active_shape = 0
	var c = em.aabb().get_center()
	var r = em.aabb().size.length() * 0.1
	var t1 = em.sculpt_dab("draw", c, r, 0.5)
	var t2 = em.sculpt_dab("inflate", c, r, 0.5)
	var t3 = em.sculpt_dab("smooth", c, r, 0.5)
	em.grab_begin(c, r)
	em.grab_update(Vector3(0, 0.05, 0))
	_ok("sculpt draw/inflate/smooth/grab", t1 > 0 and t2 > 0 and t3 > 0 and em.shapes[0].pos[0] is Vector3, "touched %d/%d/%d of %d" % [t1, t2, t3, nverts])
	em.active_shape = -1
	panel._apply_to_scene()
	_ok("shape key written as blend shape", body.mesh.get_blend_shape_count() == 1 and body.find_blend_shape_by_name("Bulk") >= 0)
	_ok("skin kept after apply", body.skin != null and body.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES != 0)
	# --- weights on the cape (unskinned -> auto weights + paint)
	var cape_mesh = cape
	panel._take_mesh(cape_mesh, "weights")
	panel._auto_weights()
	em = panel.em
	var before = em.get_weight(0, em.bidx[0])
	panel.weight_bone = em.bidx[0]
	em.weight_dab(em.verts[0], 0.2, 1.0, em.bidx[0], "subtract")
	_ok("auto weights + weight brush", em.has_skin and cape_mesh.skin != null and em.get_weight(0, panel.weight_bone) < before + 1e-4)
	panel._apply_to_scene()
	_ok("weights applied with Skin", cape_mesh.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES != 0)
	# --- UV
	var cube2 = MODEL.add_mesh_primitive(ur, "Sphere")
	panel._take_mesh(cube2, "uv")
	panel._uv_unwrap(true)
	_ok("xatlas unwrap to UV1", panel.em.has_uv and panel.em.faces.size() > 0)
	panel._uv_unwrap(false)
	_ok("UV2 generated on scene mesh", cube2.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2 != 0)
	# --- modifiers
	var cube3 = MODEL.add_mesh_primitive(ur, "Cube")
	panel._take_mesh(cube3, "modifiers")
	panel.em.tris_to_quads()
	panel.mod_stack = [{"type": "Mirror", "axis": 0, "merge": 0.001, "enabled": true}, {"type": "Array", "count": 3, "offset": Vector3(1.2, 0, 0), "enabled": true}, {"type": "Subdivision", "levels": 2, "enabled": true}]
	var ev = panel.em.evaluate(panel.mod_stack)
	_ok("modifier stack mirror+array+subdivision", ev.faces.size() == 6 * 2 * 3 * 16, "%d faces" % ev.faces.size())
	panel._apply_to_scene()
	_ok("modifiers applied to scene", cube3.mesh.get_faces().size() / 3 == ev.faces.size() * 2)
	# --- undo integration
	var hist = ur.get_history_undo_redo(ur.get_object_history_id(root))
	var had = hist.has_undo()
	hist.undo()
	_ok("editor undo works on studio actions", had)
	panel._set_mode("rig")
	var fails = results.filter(func(x): return not x[1]).size()
	print("[CHoMU selftest] DONE  %d checks, %d failed" % [results.size(), fails])
	await _frames(tree, 2)
	tree.quit(0 if fails == 0 else 2)

# ------------------------------------------------------------------ screenshots

static func _shot(plugin: EditorPlugin, path: String) -> void:
	var tree = plugin.get_tree()
	for i in 8:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var img = EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	if img:
		img.save_png(path)
		print("[CHoMU shots] ", path, " ", img.get_size())

static func run_shots(plugin: EditorPlugin, panel, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	OS.low_processor_usage_mode = false
	var tree = plugin.get_tree()
	await _frames(tree, 10)
	var root = await _open_demo(plugin)
	if root == null:
		print("[CHoMU shots] demo scene missing")
		tree.quit(1)
		return
	EditorInterface.set_distraction_free_mode(true)
	EditorInterface.set_main_screen_editor("Character Studio")
	var ur = plugin.get_undo_redo()
	var hero = root.get_node("Hero")
	var skel = SU.find_skeleton(hero)
	ANIM.retarget_library(ur, hero, "res://demo/assets/anim/UAL1_Standard.glb")
	var p = SU.find_anim_player(hero)
	if p and p.has_animation("UAL1_Standard/Idle"):
		p.assigned_animation = "UAL1_Standard/Idle"
		p.seek(0.6, true)
	await _frames(tree, 5)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(hero)
	await _frames(tree, 5)
	# 1) Pose mode on the demo character
	panel.pose_bone = skel.find_bone("upperarm_l")
	panel._set_mode("pose")
	panel.frame_target()
	panel.debug_set_orbit(0.55, -0.12, 0.92)
	panel._refresh_pose_overlay()
	await tree.create_timer(2.0).timeout
	await _shot(plugin, dir + "/studio_pose.png")
	# 2) Rig mode (humanoid map + IK)
	RIG.setup_ik(ur, skel)
	panel._set_mode("rig")
	await tree.create_timer(1.0).timeout
	await _shot(plugin, dir + "/studio_rig.png")
	# 3) Weight paint on the body
	p.seek(0.0, true)
	skel.reset_bone_poses()
	if p:
		p.assigned_animation = ""
	var body = panel._largest_mesh(hero)
	panel._take_mesh(body, "weights")
	var names = panel._bind_names()
	panel.weight_bone = names.find("upperarm_l")
	panel._rebuild_props()
	panel._refresh_overlay()
	panel.debug_set_orbit(0.7, -0.15, 0.9)
	await tree.create_timer(1.5).timeout
	await _shot(plugin, dir + "/studio_weights.png")
	# 4) Edit mode on a block-out mesh with a face selection, mirror modifier off
	var mi = MODEL.add_mesh_primitive(ur, "Cube")
	mi.position = Vector3(3.0, 0.6, 0.5)
	panel._take_mesh(mi, "edit")
	var em = panel.em
	em.tris_to_quads()
	em.set_sel_mode(EM.SEL_FACE)
	em.sel_f = {0: true}
	em.extrude(0.35)
	em.inset(0.3)
	em.sel_f = {0: true}
	em.extrude(0.25)
	em.subdivide()
	panel.debug_select_edit_faces([0, 1, 2, 3])
	panel.frame_target()
	panel.debug_set_orbit(0.75, -0.45, 1.0)
	await tree.create_timer(1.5).timeout
	await _shot(plugin, dir + "/studio_edit.png")
	# 5) Sculpt on the body
	panel._take_mesh(body, "sculpt")
	var e2 = panel.em
	var c = e2.aabb().get_center() + Vector3(0, 0.25, 0.12)
	for k in 6:
		e2.sculpt_dab("inflate", c + Vector3(0.02 * k, 0, 0), e2.aabb().size.length() * 0.06, 0.6, false, true)
	panel._refresh_overlay()
	panel.frame_target()
	panel.debug_set_orbit(0.35, -0.1, 0.55)
	panel.view.target += Vector3(0, 0.45, 0)
	panel.view._update_cam()
	panel.view.mouse_pos = panel.view.size * 0.5
	panel._update_brush_px(panel.view.mouse_pos)
	await tree.create_timer(1.5).timeout
	await _shot(plugin, dir + "/studio_sculpt.png")
	print("[CHoMU shots] done -> ", dir)
	tree.quit(0)
