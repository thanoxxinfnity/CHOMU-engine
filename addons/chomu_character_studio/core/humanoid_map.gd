@tool
extends RefCounted
## Guesses a SkeletonProfileHumanoid BoneMap from bone names.
## Handles Unreal/Quaternius (pelvis, spine_01, thigh_l), Mixamo (mixamorig:LeftUpLeg),
## VRM (J_Bip_L_UpperArm), Blender/Rigify-style (upper_arm.L, shin.R) and already-humanoid names.

const CENTER_RULES := [
	["Root", "^root$"],
	["Hips", "^(hips?|pelvis|cog)$"],
	["Spine", "^(spine|spine0?0|spine01|abdomen|torso|lowerspine|spinelower)$"],
	["Chest", "^(spine1|spine02|chest|midspine)$"],
	["UpperChest", "^(spine2|spine03|upperchest|chestupper)$"],
	["Neck", "^(neck|neck0?1)$"],
	["Head", "^head$"],
	["Jaw", "^jaw$"],
]
const SIDE_RULES := [
	["Eye", "^eye(ball)?$"],
	["Shoulder", "^(clavicle|shoulder|collar)$"],
	["UpperArm", "^(upperarm|arm|uparm)$"],
	["LowerArm", "^(lowerarm|forearm|elbow|loarm)$"],
	["Hand", "^(hand|wrist)$"],
	["UpperLeg", "^(thigh|upleg|upperleg|upleg)$"],
	["LowerLeg", "^(calf|leg|shin|lowerleg|knee|loleg)$"],
	["Foot", "^(foot|ankle)$"],
	["Toes", "^(ball|toe|toes|toebase)$"],
]
const FINGERS := {"thumb": "Thumb", "index": "Index", "middle": "Middle", "ring": "Ring", "pinky": "Little", "little": "Little"}

## Returns [side, core] where side is "Left", "Right" or "".
static func normalize(bone: String) -> Array:
	var n = bone.to_lower()
	for pre in ["mixamorig:", "mixamorig_", "mixamorig1:", "def-", "def_", "org-", "bip01 ", "bip001 ", "bip01_", "bip001_", "armature_", "cc_base_", "rig_"]:
		if n.begins_with(pre):
			n = n.substr(pre.length())
	var side = ""
	if n.begins_with("j_bip_l_") or n.begins_with("j_sec_l_"):
		side = "Left"; n = n.substr(8)
	elif n.begins_with("j_bip_r_") or n.begins_with("j_sec_r_"):
		side = "Right"; n = n.substr(8)
	elif n.begins_with("j_bip_c_"):
		n = n.substr(8)
	if side == "":
		if n.begins_with("left"):
			side = "Left"; n = n.substr(4)
		elif n.begins_with("right"):
			side = "Right"; n = n.substr(5)
	var toks = []
	var cur = ""
	for ch in n:
		if ch in ["_", ".", "-", ":", " "]:
			if cur != "":
				toks.append(cur)
			cur = ""
		else:
			cur += ch
	if cur != "":
		toks.append(cur)
	var keep = []
	for t in toks:
		if side == "" and t in ["l", "left"]:
			side = "Left"; continue
		if side == "" and t in ["r", "right"]:
			side = "Right"; continue
		if t in ["l", "r"]:
			continue
		keep.append(t)
	var core = "".join(keep)
	# trailing "l"/"r" glued to a word (e.g. "handl") is ambiguous; only accept for known words
	if side == "" and core.length() > 3:
		for w in ["hand", "foot", "arm", "leg", "thigh", "calf", "clavicle", "upperarm", "lowerarm", "shoulder", "eye", "toe"]:
			if core == w + "l":
				side = "Left"; core = w
			elif core == w + "r":
				side = "Right"; core = w
	return [side, core]

static func _match(re_src: String, s: String) -> bool:
	var re = RegEx.new()
	re.compile(re_src)
	return re.search(s) != null

static func profile_name_for(bone: String) -> String:
	# Already a humanoid profile name?
	var prof = SkeletonProfileHumanoid.new()
	if prof.find_bone(StringName(bone)) >= 0:
		return bone
	var nc = normalize(bone)
	var side: String = nc[0]
	var core: String = nc[1]
	if side == "":
		for r in CENTER_RULES:
			if _match(r[1], core):
				return r[0]
		return ""
	for r in SIDE_RULES:
		if _match(r[1], core):
			return side + r[0]
	# fingers: thumb_01 / handthumb1 / index2 / pinky_03 ...
	var re = RegEx.new()
	re.compile("^(hand)?(thumb|index|middle|ring|pinky|little)(\\d+)$")
	var m = re.search(core)
	if m:
		var f: String = FINGERS[m.get_string(2)]
		var num = int(m.get_string(3))
		if num == 0:
			num = 1
		var seg = ""
		if f == "Thumb":
			seg = ["Metacarpal", "Proximal", "Distal"][clampi(num - 1, 0, 2)]
		else:
			if num > 3:
				return ""
			seg = ["Proximal", "Intermediate", "Distal"][num - 1]
		return side + f + seg
	return ""

## profile bone name -> skeleton bone name
static func map_skeleton(skel: Skeleton3D) -> Dictionary:
	var out = {}
	if skel == null:
		return out
	for i in skel.get_bone_count():
		var b = skel.get_bone_name(i)
		var p = profile_name_for(b)
		if p != "" and not out.has(p):
			out[p] = b
	# Fallback: if there is no Spine but a Chest, shift down (common with 2-spine rigs)
	if not out.has("Spine") and out.has("Chest"):
		out["Spine"] = out["Chest"]
		out.erase("Chest")
	return out

static func make_bone_map(skel: Skeleton3D) -> BoneMap:
	var bm = BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	var m = map_skeleton(skel)
	for k in m:
		bm.set_skeleton_bone_name(StringName(k), StringName(m[k]))
	return bm

static func find_bone(skel: Skeleton3D, profile_bone: String) -> int:
	var m = map_skeleton(skel)
	if m.has(profile_bone):
		return skel.find_bone(m[profile_bone])
	return -1
