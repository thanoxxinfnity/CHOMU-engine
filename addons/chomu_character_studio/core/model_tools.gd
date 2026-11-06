@tool
extends RefCounted
## Modelling: CSG block-out (primitives + booleans), bake to mesh, and editable mesh primitives.

const SU := preload("res://addons/chomu_character_studio/core/scene_util.gd")

const OPS := {"Union": CSGShape3D.OPERATION_UNION, "Subtract": CSGShape3D.OPERATION_SUBTRACTION, "Intersect": CSGShape3D.OPERATION_INTERSECTION}

static func _csg_parent(ur: EditorUndoRedoManager) -> Node:
	var sel = SU.first_selected("CSGCombiner3D")
	if sel:
		return sel
	var anycsg = SU.first_selected("CSGShape3D")
	if anycsg:
		var p = anycsg.get_parent()
		if p is CSGShape3D:
			return p
	var r = SU.root()
	var existing = r.get_node_or_null("CHoMU_Model")
	if existing is CSGCombiner3D:
		return existing
	var c = CSGCombiner3D.new()
	c.name = "CHoMU_Model"
	SU.add_node(ur, "CHoMU: CSG model root", r, c)
	return c

static func add_csg(ur: EditorUndoRedoManager, kind: String, op: String) -> String:
	var parent = _csg_parent(ur)
	var n: CSGShape3D
	match kind:
		"Box":
			n = CSGBox3D.new()
		"Sphere":
			var s = CSGSphere3D.new()
			s.radial_segments = 24
			s.rings = 12
			n = s
		"Cylinder":
			var c = CSGCylinder3D.new()
			c.sides = 24
			n = c
		"Cone":
			var c2 = CSGCylinder3D.new()
			c2.cone = true
			c2.sides = 24
			n = c2
		"Torus":
			var t = CSGTorus3D.new()
			t.sides = 24
			t.ring_sides = 12
			n = t
		_:
			n = CSGBox3D.new()
	n.name = SU.unique_name(parent, kind)
	n.operation = OPS.get(op, CSGShape3D.OPERATION_UNION)
	var count = parent.get_child_count()
	if count > 0 and op != "Union":
		n.position = Vector3(0.35, 0.35, 0)
	elif count > 0:
		n.position = Vector3(0.6 * count, 0, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#9aa4ae") if op == "Union" else Color("#3d8bfd")
	mat.roughness = 0.6
	n.material = mat
	SU.add_node(ur, "CHoMU: CSG " + kind, parent, n, true)
	return "Added CSG %s (%s) under %s." % [kind, op, parent.name]

static func set_operation(ur: EditorUndoRedoManager, op: String) -> String:
	var n = 0
	ur.create_action("CHoMU: CSG operation " + op)
	for s in SU.selected():
		if s is CSGShape3D:
			ur.add_do_property(s, "operation", OPS[op])
			ur.add_undo_property(s, "operation", s.operation)
			n += 1
	ur.commit_action()
	return "Set %d CSG node(s) to %s." % [n, op]

## Bakes the selected CSG tree to a MeshInstance3D (ready for Edit / Sculpt).
static func bake_csg(ur: EditorUndoRedoManager) -> MeshInstance3D:
	var csg = SU.first_selected("CSGShape3D") as CSGShape3D
	if csg == null:
		var r = SU.root()
		csg = r.get_node_or_null("CHoMU_Model") as CSGShape3D
	if csg == null:
		return null
	while csg.get_parent() is CSGShape3D:
		csg = csg.get_parent()
	csg._update_shape()
	var mesh = csg.bake_static_mesh()
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var mi = MeshInstance3D.new()
	mi.name = SU.unique_name(csg.get_parent(), String(csg.name) + "_Mesh")
	mi.mesh = mesh
	mi.transform = csg.transform
	SU.add_node(ur, "CHoMU: Bake CSG", csg.get_parent(), mi, true)
	SU.set_prop(ur, "CHoMU: hide CSG", csg, "visible", false)
	return mi

## Adds an editable ArrayMesh primitive (quads kept by welding in the edit mesh).
static func add_mesh_primitive(ur: EditorUndoRedoManager, kind: String) -> MeshInstance3D:
	var pm: PrimitiveMesh
	match kind:
		"Cube":
			var b = BoxMesh.new()
			b.subdivide_width = 0
			b.subdivide_height = 0
			b.subdivide_depth = 0
			pm = b
		"Sphere":
			var s = SphereMesh.new()
			s.radial_segments = 24
			s.rings = 12
			s.radius = 0.5
			s.height = 1.0
			pm = s
		"Cylinder":
			var c = CylinderMesh.new()
			c.radial_segments = 16
			c.rings = 2
			pm = c
		"Plane":
			var p = PlaneMesh.new()
			p.subdivide_width = 3
			p.subdivide_depth = 3
			pm = p
		_:
			pm = BoxMesh.new()
	var am = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, pm.get_mesh_arrays())
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#a7b0ba")
	am.surface_set_material(0, mat)
	var mi = MeshInstance3D.new()
	var r = SU.root()
	mi.name = SU.unique_name(r, kind)
	mi.mesh = am
	SU.add_node(ur, "CHoMU: Mesh " + kind, r, mi, true)
	return mi
