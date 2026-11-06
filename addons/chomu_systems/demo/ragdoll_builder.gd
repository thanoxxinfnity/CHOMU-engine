class_name ChomuRagdollBuilder
extends RefCounted
## Builds a simple 7-bone test dummy (Skeleton3D + PhysicalBoneSimulator3D +
## capsule PhysicalBone3Ds with visible meshes). Used by the demo and self-test.

const BONES := [
	# name, parent, local rest offset, capsule radius, capsule height
	["hips", "", Vector3(0, 1.0, 0), 0.16, 0.35],
	["spine", "hips", Vector3(0, 0.35, 0), 0.17, 0.5],
	["head", "spine", Vector3(0, 0.5, 0), 0.13, 0.3],
	["arm_l", "spine", Vector3(-0.3, 0.35, 0), 0.07, 0.6],
	["arm_r", "spine", Vector3(0.3, 0.35, 0), 0.07, 0.6],
	["leg_l", "hips", Vector3(-0.14, -0.1, 0), 0.09, 0.85],
	["leg_r", "hips", Vector3(0.14, -0.1, 0), 0.09, 0.85],
]

static func build(parent: Node3D, color := Color(0.55, 0.58, 0.62)) -> Dictionary:
	var root := Node3D.new()
	root.name = "RagdollDummy"
	parent.add_child(root)
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	var idx := {}
	for b in BONES:
		var i := sk.get_bone_count()
		sk.add_bone(b[0])
		idx[b[0]] = i
		if b[1] != "":
			sk.set_bone_parent(i, idx[b[1]])
		var rest := Transform3D(Basis(), b[2])
		sk.set_bone_rest(i, rest)
		sk.set_bone_pose_position(i, b[2])
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "PhysicalBoneSimulator3D"
	sk.add_child(sim)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	for b in BONES:
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + b[0]
		pb.bone_name = b[0]
		pb.mass = 4.0 if b[0] in ["hips", "spine"] else 1.5
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE if b[1] != "" else PhysicalBone3D.JOINT_TYPE_NONE
		# capsule hangs downward from limbs, upward for torso/head
		var down: bool = b[0].begins_with("arm") or b[0].begins_with("leg")
		var off := Vector3(0, -float(b[4]) * 0.5 if down else float(b[4]) * 0.5, 0)
		pb.body_offset = Transform3D(Basis(), off)
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = b[3]
		cap.height = maxf(b[4], b[3] * 2.0 + 0.01)
		cs.shape = cap
		pb.add_child(cs)
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = b[3]
		cm.height = cap.height
		mi.mesh = cm
		mi.material_override = mat
		pb.add_child(mi)
		sim.add_child(pb)
	return {"root": root, "skeleton": sk, "simulator": sim}
