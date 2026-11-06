@tool
extends RefCounted
## Editable polygon mesh for the studio's Edit / Sculpt / Weight / Shape-key / Modifier modes.
## Loads any triangle Mesh (vertices welded by position, so a quad mesh edits like quads after
## "Tris to quads"), keeps per-corner UVs, 4-bone skin weights, blend shapes and surface materials,
## and rebuilds an ArrayMesh (with tangents and blend shapes) for display or for writing back.

const SEL_VERT := 0
const SEL_EDGE := 1
const SEL_FACE := 2

var verts = PackedVector3Array()
var faces: Array = []          # Array[PackedInt32Array] - polygon vertex indices
var fuv: Array = []            # Array[PackedVector2Array] - per-corner UVs (parallel to faces)
var fsurf = PackedInt32Array() # surface index per face
var surf_mats: Array = []
var has_uv = false
var has_skin = false
var bidx = PackedInt32Array()   # 4 bone indices per vertex
var bwt = PackedFloat32Array()  # 4 weights per vertex
var shapes: Array = []           # [{name, pos: PackedVector3Array, w: float}]
var active_shape = -1           # -1 edits the basis
var flip = false                # true when the source winding needs the opposite normal sign
var smooth_shading = true

var sel_mode = SEL_VERT
var sel_v = {}
var sel_e = {}
var sel_f = {}

var _topo_dirty = true
var _edge_faces = {}
var _neighbors: Array = []

# ---------------------------------------------------------------- load / copy

func load_mesh(mesh: Mesh) -> bool:
	verts = PackedVector3Array()
	faces.clear()
	fuv.clear()
	fsurf = PackedInt32Array()
	surf_mats.clear()
	shapes.clear()
	bidx = PackedInt32Array()
	bwt = PackedFloat32Array()
	has_uv = false
	has_skin = false
	active_shape = -1
	sel_v.clear(); sel_e.clear(); sel_f.clear()
	if mesh == null:
		return false
	var weld = {}
	var shape_count = 0
	if mesh is ArrayMesh:
		shape_count = (mesh as ArrayMesh).get_blend_shape_count()
		for k in shape_count:
			shapes.append({"name": String((mesh as ArrayMesh).get_blend_shape_name(k)), "pos": PackedVector3Array(), "w": 0.0})
	var flip_votes = 0
	var vsrc_s = PackedInt32Array()
	var vsrc_i = PackedInt32Array()
	var surf_shapes = {}
	for s in mesh.get_surface_count():
		surf_mats.append(mesh.surface_get_material(s))
		var arr = mesh.surface_get_arrays(s)
		if arr.is_empty():
			continue
		var sv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var sn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var suv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var sb: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var sw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var si: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if si.is_empty():
			si.resize(sv.size())
			for i in sv.size():
				si[i] = i
		if suv.size() == sv.size() and sv.size() > 0:
			has_uv = true
		var bper = 0
		if sb.size() > 0 and sv.size() > 0:
			bper = sb.size() / sv.size()
			has_skin = true
		var sshape: Array = []
		if shape_count > 0:
			var bsa = mesh.surface_get_blend_shape_arrays(s)
			for k in shape_count:
				if k < bsa.size() and bsa[k] is Array and (bsa[k] as Array).size() > 0 and bsa[k][Mesh.ARRAY_VERTEX] != null:
					sshape.append(bsa[k][Mesh.ARRAY_VERTEX])
				else:
					sshape.append(sv)
			surf_shapes[s] = sshape
		var remap = PackedInt32Array()
		remap.resize(sv.size())
		for i in sv.size():
			var p = sv[i]
			var key = Vector3i(roundi(p.x * 100000.0), roundi(p.y * 100000.0), roundi(p.z * 100000.0))
			var ni: int
			if weld.has(key):
				ni = weld[key]
			else:
				ni = verts.size()
				weld[key] = ni
				verts.append(p)
				var b4 = [0, 0, 0, 0]
				var w4 = [0.0, 0.0, 0.0, 0.0]
				if bper > 0:
					var pairs = []
					for j in bper:
						pairs.append([sw[i * bper + j], sb[i * bper + j]])
					pairs.sort_custom(func(x, y): return x[0] > y[0])
					var tot = 0.0
					for j in mini(4, pairs.size()):
						w4[j] = pairs[j][0]
						b4[j] = pairs[j][1]
						tot += w4[j]
					if tot > 0.0:
						for j in 4:
							w4[j] /= tot
				for j in 4:
					bidx.append(b4[j])
					bwt.append(w4[j])
				vsrc_s.append(s)
				vsrc_i.append(i)
			remap[i] = ni
		for t in range(0, si.size() - 2, 3):
			var a = remap[si[t]]
			var b = remap[si[t + 1]]
			var c = remap[si[t + 2]]
			if a == b or b == c or a == c:
				continue
			faces.append(PackedInt32Array([a, b, c]))
			if has_uv and suv.size() == sv.size():
				fuv.append(PackedVector2Array([suv[si[t]], suv[si[t + 1]], suv[si[t + 2]]]))
			else:
				fuv.append(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
			fsurf.append(s)
			if sn.size() == sv.size() and absi(flip_votes) < 50:
				var nn = (verts[c] - verts[a]).cross(verts[b] - verts[a])
				var on = sn[si[t]] + sn[si[t + 1]] + sn[si[t + 2]]
				flip_votes += 1 if nn.dot(on) < 0.0 else -1
	flip = flip_votes > 0
	for k in shape_count:
		var acc = PackedVector3Array()
		acc.resize(verts.size())
		for j in verts.size():
			var arrs: Array = surf_shapes.get(vsrc_s[j], [])
			if k < arrs.size():
				var sa: PackedVector3Array = arrs[k]
				acc[j] = sa[vsrc_i[j]] if vsrc_i[j] < sa.size() else verts[j]
			else:
				acc[j] = verts[j]
		shapes[k].pos = acc
	_topo_dirty = true
	_tri_dirty = true
	return faces.size() > 0

func duplicate_mesh() -> RefCounted:
	var m: RefCounted = get_script().new()
	m.verts = verts.duplicate()
	m.faces = faces.map(func(f): return (f as PackedInt32Array).duplicate())
	m.fuv = fuv.map(func(f): return (f as PackedVector2Array).duplicate())
	m.fsurf = fsurf.duplicate()
	m.surf_mats = surf_mats.duplicate()
	m.has_uv = has_uv
	m.has_skin = has_skin
	m.bidx = bidx.duplicate()
	m.bwt = bwt.duplicate()
	m.shapes = shapes.map(func(s): return {"name": s.name, "pos": (s.pos as PackedVector3Array).duplicate(), "w": s.w})
	m.active_shape = active_shape
	m.flip = flip
	m.smooth_shading = smooth_shading
	return m

## Snapshot for undo (cheap enough for character-size meshes).
func snapshot() -> RefCounted:
	var m: RefCounted = duplicate_mesh()
	m.sel_mode = sel_mode
	m.sel_v = sel_v.duplicate()
	m.sel_e = sel_e.duplicate()
	m.sel_f = sel_f.duplicate()
	return m

func restore(m: RefCounted) -> void:
	var d: RefCounted = m.duplicate_mesh()
	verts = d.verts; faces = d.faces; fuv = d.fuv; fsurf = d.fsurf; surf_mats = d.surf_mats
	has_uv = d.has_uv; has_skin = d.has_skin; bidx = d.bidx; bwt = d.bwt; shapes = d.shapes
	active_shape = d.active_shape; flip = d.flip; smooth_shading = d.smooth_shading
	sel_mode = m.sel_mode; sel_v = m.sel_v.duplicate(); sel_e = m.sel_e.duplicate(); sel_f = m.sel_f.duplicate()
	_topo_dirty = true
	_tri_dirty = true

# ---------------------------------------------------------------- positions

func positions() -> PackedVector3Array:
	if active_shape >= 0 and active_shape < shapes.size():
		return shapes[active_shape].pos
	return verts

func set_positions(p: PackedVector3Array) -> void:
	if active_shape >= 0 and active_shape < shapes.size():
		shapes[active_shape].pos = p
	else:
		verts = p

## What the viewport shows: the active key, or the basis mixed with shape weights.
func display_positions() -> PackedVector3Array:
	if active_shape >= 0:
		return positions()
	var p = verts.duplicate()
	for s in shapes:
		var w: float = s.w
		if absf(w) < 0.0001:
			continue
		var sp: PackedVector3Array = s.pos
		for i in p.size():
			p[i] += (sp[i] - verts[i]) * w
	return p

func face_normal_p(f: PackedInt32Array, p: PackedVector3Array) -> Vector3:
	var n = Vector3.ZERO
	var c = f.size()
	for i in c:
		var a = p[f[i]]
		var b = p[f[(i + 1) % c]]
		n.x += (a.y - b.y) * (a.z + b.z)
		n.y += (a.z - b.z) * (a.x + b.x)
		n.z += (a.x - b.x) * (a.y + b.y)
	n = n.normalized()
	return n if flip else -n

func face_normal(fi: int) -> Vector3:
	return face_normal_p(faces[fi], positions())

func face_center(fi: int, p: PackedVector3Array = PackedVector3Array()) -> Vector3:
	if p.is_empty():
		p = positions()
	var f: PackedInt32Array = faces[fi]
	var c = Vector3.ZERO
	for v in f:
		c += p[v]
	return c / float(f.size())

func vertex_normals(p: PackedVector3Array) -> PackedVector3Array:
	var tri = tri_indices()
	var vn = PackedVector3Array()
	vn.resize(p.size())
	var sgn = -1.0 if flip else 1.0
	for t in range(0, tri.size(), 3):
		var a = tri[t]
		var b = tri[t + 1]
		var c = tri[t + 2]
		var n = (p[c] - p[a]).cross(p[b] - p[a]) * sgn
		vn[a] += n
		vn[b] += n
		vn[c] += n
	for i in vn.size():
		vn[i] = vn[i].normalized() if vn[i].length_squared() > 0.0 else Vector3.UP
	return vn

var _tri_cache = PackedInt32Array()
var _tri_dirty = true

## Fan-triangulated welded indices (cached until topology changes).
func tri_indices() -> PackedInt32Array:
	if _tri_dirty or _topo_dirty and _tri_cache.is_empty():
		_tri_cache = PackedInt32Array()
		for f in faces:
			for t in range(1, f.size() - 1):
				_tri_cache.append(f[0])
				_tri_cache.append(f[t])
				_tri_cache.append(f[t + 1])
		_tri_dirty = false
	return _tri_cache

## Fast preview mesh (welded, smooth, single surface) used while editing / sculpting / painting.
func build_fast(p: PackedVector3Array, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var am = ArrayMesh.new()
	var tri = tri_indices()
	if tri.is_empty():
		return am
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = p
	arr[Mesh.ARRAY_NORMAL] = vertex_normals(p)
	if colors.size() == p.size():
		arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = tri
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

func weight_colors(bone: int) -> PackedColorArray:
	var th = preload("res://addons/chomu_character_studio/ui/studio_theme.gd")
	var c = PackedColorArray()
	c.resize(verts.size())
	var ok = bone >= 0 and bidx.size() >= verts.size() * 4
	for i in verts.size():
		c[i] = th.heat(get_weight(i, bone) if ok else 0.0)
	return c

func aabb() -> AABB:
	if verts.is_empty():
		return AABB()
	var b = AABB(verts[0], Vector3.ZERO)
	for v in verts:
		b = b.expand(v)
	return b

# ---------------------------------------------------------------- topology helpers

static func ekey(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))

func _ensure_topo() -> void:
	if not _topo_dirty:
		return
	_edge_faces.clear()
	_neighbors.clear()
	_neighbors.resize(verts.size())
	for i in verts.size():
		_neighbors[i] = {}
	for fi in faces.size():
		var f: PackedInt32Array = faces[fi]
		var c = f.size()
		for i in c:
			var a = f[i]
			var b = f[(i + 1) % c]
			var k = ekey(a, b)
			if not _edge_faces.has(k):
				_edge_faces[k] = []
			_edge_faces[k].append(fi)
			_neighbors[a][b] = true
			_neighbors[b][a] = true
	_topo_dirty = false

func edge_faces() -> Dictionary:
	_ensure_topo()
	return _edge_faces

func neighbors() -> Array:
	_ensure_topo()
	return _neighbors

func all_edges() -> Array:
	return edge_faces().keys()

func mark_dirty() -> void:
	_topo_dirty = true
	_tri_dirty = true

# ---------------------------------------------------------------- selection

func selected_verts() -> Dictionary:
	var out = {}
	match sel_mode:
		SEL_VERT:
			out = sel_v.duplicate()
		SEL_EDGE:
			for e in sel_e:
				out[e.x] = true
				out[e.y] = true
		SEL_FACE:
			for fi in sel_f:
				if fi < faces.size():
					for v in faces[fi]:
						out[v] = true
	return out

func selected_faces_full() -> Array:
	if sel_mode == SEL_FACE:
		return sel_f.keys().filter(func(fi): return fi < faces.size())
	var sv = selected_verts()
	var out = []
	for fi in faces.size():
		var all_in = true
		for v in faces[fi]:
			if not sv.has(v):
				all_in = false
				break
		if all_in:
			out.append(fi)
	return out

func selected_edges_full() -> Array:
	if sel_mode == SEL_EDGE:
		return sel_e.keys()
	var sv = selected_verts()
	var out = []
	for e in all_edges():
		if sv.has(e.x) and sv.has(e.y):
			out.append(e)
	return out

func set_sel_mode(m: int) -> void:
	if m == sel_mode:
		return
	var sv = selected_verts()
	sel_v.clear(); sel_e.clear(); sel_f.clear()
	var old = sel_mode
	sel_mode = m
	match m:
		SEL_VERT:
			sel_v = sv
		SEL_EDGE:
			for e in all_edges():
				if sv.has(e.x) and sv.has(e.y):
					sel_e[e] = true
		SEL_FACE:
			for fi in faces.size():
				var ok = true
				for v in faces[fi]:
					if not sv.has(v):
						ok = false
						break
				if ok:
					sel_f[fi] = true
	if old == SEL_FACE and m == SEL_VERT and sel_v.is_empty():
		sel_v = sv

func select_all(on := true) -> void:
	sel_v.clear(); sel_e.clear(); sel_f.clear()
	if not on:
		return
	match sel_mode:
		SEL_VERT:
			for i in verts.size():
				sel_v[i] = true
		SEL_EDGE:
			for e in all_edges():
				sel_e[e] = true
		SEL_FACE:
			for fi in faces.size():
				sel_f[fi] = true

func select_invert() -> void:
	match sel_mode:
		SEL_VERT:
			var n = {}
			for i in verts.size():
				if not sel_v.has(i):
					n[i] = true
			sel_v = n
		SEL_EDGE:
			var n2 = {}
			for e in all_edges():
				if not sel_e.has(e):
					n2[e] = true
			sel_e = n2
		SEL_FACE:
			var n3 = {}
			for fi in faces.size():
				if not sel_f.has(fi):
					n3[fi] = true
			sel_f = n3

func select_linked() -> void:
	var nb = neighbors()
	var stack = selected_verts().keys()
	var seen = {}
	for v in stack:
		seen[v] = true
	while not stack.is_empty():
		var v: int = stack.pop_back()
		for w in nb[v]:
			if not seen.has(w):
				seen[w] = true
				stack.append(w)
	var m = sel_mode
	sel_mode = SEL_VERT
	sel_v = seen
	sel_mode = -1
	set_sel_mode(m)

func select_grow() -> void:
	var nb = neighbors()
	var sv = selected_verts()
	var out = sv.duplicate()
	for v in sv:
		for w in nb[v]:
			out[w] = true
	var m = sel_mode
	sel_mode = SEL_VERT
	sel_v = out
	sel_mode = -1
	set_sel_mode(m)

func toggle_vert(i: int, additive: bool) -> void:
	if not additive:
		sel_v.clear()
	if sel_v.has(i) and additive:
		sel_v.erase(i)
	else:
		sel_v[i] = true

func toggle_edge(e: Vector2i, additive: bool) -> void:
	if not additive:
		sel_e.clear()
	if sel_e.has(e) and additive:
		sel_e.erase(e)
	else:
		sel_e[e] = true

func toggle_face(fi: int, additive: bool) -> void:
	if not additive:
		sel_f.clear()
	if sel_f.has(fi) and additive:
		sel_f.erase(fi)
	else:
		sel_f[fi] = true

func selection_center() -> Vector3:
	var sv = selected_verts()
	var p = positions()
	if sv.is_empty():
		return aabb().get_center()
	var c = Vector3.ZERO
	for v in sv:
		c += p[v]
	return c / float(sv.size())

func selection_normal() -> Vector3:
	var fs = selected_faces_full()
	var n = Vector3.ZERO
	for fi in fs:
		n += face_normal(fi)
	if n.length_squared() < 1e-8:
		var vn = vertex_normals(positions())
		for v in selected_verts():
			n += vn[v]
	return n.normalized() if n.length_squared() > 1e-8 else Vector3.UP

# ---------------------------------------------------------------- vertex creation

func _add_vert_from(src: int, offset := Vector3.ZERO) -> int:
	var ni = verts.size()
	verts.append(verts[src] + offset)
	for s in shapes:
		var sp: PackedVector3Array = s.pos
		sp.append(sp[src] + offset)
		s.pos = sp
	for j in 4:
		bidx.append(bidx[src * 4 + j] if src * 4 + j < bidx.size() else 0)
		bwt.append(bwt[src * 4 + j] if src * 4 + j < bwt.size() else 0.0)
	return ni

## New vertex as a weighted mix of existing ones (positions, shape keys and skin weights).
func _add_vert_mix(combo: Dictionary) -> int:
	var ni = verts.size()
	var p = Vector3.ZERO
	for k in combo:
		p += verts[k] * float(combo[k])
	verts.append(p)
	for s in shapes:
		var sp: PackedVector3Array = s.pos
		var q = Vector3.ZERO
		for k in combo:
			q += sp[k] * float(combo[k])
		sp.append(q)
		s.pos = sp
	var w4 = _mix_weights(combo)
	for j in 4:
		bidx.append(w4[0][j])
		bwt.append(w4[1][j])
	return ni

func _mix_weights(combo: Dictionary) -> Array:
	var acc = {}
	if has_skin:
		for k in combo:
			for j in 4:
				var w = bwt[k * 4 + j] * float(combo[k])
				if w > 0.0:
					acc[bidx[k * 4 + j]] = acc.get(bidx[k * 4 + j], 0.0) + w
	var pairs = []
	for b in acc:
		pairs.append([acc[b], b])
	pairs.sort_custom(func(x, y): return x[0] > y[0])
	var b4 = [0, 0, 0, 0]
	var w4 = [0.0, 0.0, 0.0, 0.0]
	var tot = 0.0
	for j in mini(4, pairs.size()):
		w4[j] = pairs[j][0]
		b4[j] = pairs[j][1]
		tot += w4[j]
	if tot > 0.0:
		for j in 4:
			w4[j] /= tot
	return [b4, w4]

func _face_uv_of(fi: int, v: int) -> Vector2:
	var f: PackedInt32Array = faces[fi]
	var u: PackedVector2Array = fuv[fi]
	for i in f.size():
		if f[i] == v:
			return u[i]
	return Vector2.ZERO

func _add_face(f: PackedInt32Array, uv: PackedVector2Array, surf: int) -> int:
	faces.append(f)
	fuv.append(uv)
	fsurf.append(surf)
	return faces.size() - 1

# ---------------------------------------------------------------- transforms

func _apply_to_selection(fn: Callable) -> void:
	var sv = selected_verts()
	if sv.is_empty():
		return
	var p = positions()
	for v in sv:
		p[v] = fn.call(p[v])
	set_positions(p)
	if active_shape < 0:
		for s in shapes:
			var sp: PackedVector3Array = s.pos
			for v in sv:
				sp[v] = fn.call(sp[v])
			s.pos = sp

func translate(d: Vector3) -> void:
	_apply_to_selection(func(x: Vector3) -> Vector3: return x + d)

func rotate(axis: Vector3, angle: float, pivot: Vector3) -> void:
	var b = Basis(axis.normalized(), angle)
	_apply_to_selection(func(x: Vector3) -> Vector3: return pivot + b * (x - pivot))

func scale(f: Vector3, pivot: Vector3) -> void:
	_apply_to_selection(func(x: Vector3) -> Vector3: return pivot + (x - pivot) * f)

## Moves vertices from a captured base set (used by modal G/R/S so it never accumulates error).
func set_from_base(base: PackedVector3Array, sv: Array, fn: Callable) -> void:
	var p = positions()
	for v in sv:
		p[v] = fn.call(base[v])
	set_positions(p)

# ---------------------------------------------------------------- edit operations

## Extrude: faces as a region (Blender's E), or edges outward. Returns a message.
func extrude(dist: float) -> String:
	var fs = selected_faces_full()
	if not fs.is_empty():
		return _extrude_region(fs, dist)
	var es = selected_edges_full()
	if not es.is_empty():
		return _extrude_edges(es, dist)
	return "Nothing to extrude: select faces or edges."

func _extrude_region(fs: Array, dist: float) -> String:
	var inreg = {}
	for fi in fs:
		inreg[fi] = true
	var ecount = {}
	var edir = {}
	for fi in fs:
		var f: PackedInt32Array = faces[fi]
		for i in f.size():
			var a = f[i]
			var b = f[(i + 1) % f.size()]
			var k = ekey(a, b)
			ecount[k] = ecount.get(k, 0) + 1
			edir[k] = [a, b, fi]
	var region_verts = {}
	for fi in fs:
		for v in faces[fi]:
			region_verts[v] = true
	var n = Vector3.ZERO
	for fi in fs:
		n += face_normal(fi)
	n = n.normalized() if n.length_squared() > 1e-8 else Vector3.UP
	var boundary_v = {}
	for k in ecount:
		if ecount[k] == 1:
			boundary_v[k.x] = true
			boundary_v[k.y] = true
	var dup = {}
	for v in boundary_v:
		dup[v] = _add_vert_from(v)
	var side_count = 0
	for k in ecount:
		if ecount[k] != 1:
			continue
		var a: int = edir[k][0]
		var b: int = edir[k][1]
		var fi: int = edir[k][2]
		var ua = _face_uv_of(fi, a)
		var ub = _face_uv_of(fi, b)
		_add_face(PackedInt32Array([a, b, dup[b], dup[a]]), PackedVector2Array([ua, ub, ub, ua]), fsurf[fi])
		side_count += 1
	for fi in fs:
		var f: PackedInt32Array = faces[fi]
		for i in f.size():
			if dup.has(f[i]):
				f[i] = dup[f[i]]
		faces[fi] = f
	var moved = {}
	for fi in fs:
		for v in faces[fi]:
			moved[v] = true
	var p = positions()
	for v in moved:
		p[v] += n * dist
	set_positions(p)
	if active_shape < 0:
		for s in shapes:
			var sp: PackedVector3Array = s.pos
			for v in moved:
				sp[v] += n * dist
			s.pos = sp
	sel_mode = SEL_FACE
	sel_v.clear(); sel_e.clear(); sel_f.clear()
	for fi in fs:
		sel_f[fi] = true
	mark_dirty()
	return "Extruded %d face(s), %d side faces." % [fs.size(), side_count]

func _extrude_edges(es: Array, dist: float) -> String:
	var ef = edge_faces()
	var dup = {}
	var p = positions()
	var new_edges = []
	for e in es:
		var fl: Array = ef.get(e, [])
		var a: int = e.x
		var b: int = e.y
		var dirv = Vector3.UP
		var surf = 0
		var ua = Vector2.ZERO
		var ub = Vector2.ZERO
		if not fl.is_empty():
			var fi: int = fl[0]
			surf = fsurf[fi]
			var f: PackedInt32Array = faces[fi]
			# orient a->b as in the face
			for i in f.size():
				if f[i] == e.y and f[(i + 1) % f.size()] == e.x:
					a = e.y
					b = e.x
			ua = _face_uv_of(fi, a)
			ub = _face_uv_of(fi, b)
			var mid = (p[a] + p[b]) * 0.5
			var edge = (p[b] - p[a]).normalized()
			var out = mid - face_center(fi, p)
			out = (out - edge * out.dot(edge))
			dirv = out.normalized() if out.length_squared() > 1e-10 else face_normal(fi)
		for v in [a, b]:
			if not dup.has(v):
				dup[v] = _add_vert_from(v, dirv * dist)
		_add_face(PackedInt32Array([b, a, dup[a], dup[b]]), PackedVector2Array([ub, ua, ua, ub]), surf)
		new_edges.append(ekey(dup[a], dup[b]))
	sel_mode = SEL_EDGE
	sel_v.clear(); sel_e.clear(); sel_f.clear()
	for e in new_edges:
		sel_e[e] = true
	mark_dirty()
	return "Extruded %d edge(s)." % es.size()

## Individual inset of each selected face. t = 0..1 fraction toward the centre.
func inset(t: float) -> String:
	var fs = selected_faces_full()
	if fs.is_empty():
		return "Inset needs selected faces."
	for fi in fs:
		var f: PackedInt32Array = faces[fi]
		var u: PackedVector2Array = fuv[fi]
		var c = f.size()
		var inner = PackedInt32Array()
		var iuv = PackedVector2Array()
		var cuv = Vector2.ZERO
		for k in c:
			cuv += u[k]
		cuv /= float(c)
		for k in c:
			var combo = {}
			combo[f[k]] = 1.0 - t
			for j in c:
				combo[f[j]] = combo.get(f[j], 0.0) + t / float(c)
			inner.append(_add_vert_mix(combo))
			iuv.append(u[k].lerp(cuv, t))
		for k in c:
			var k1 = (k + 1) % c
			_add_face(PackedInt32Array([f[k], f[k1], inner[k1], inner[k]]), PackedVector2Array([u[k], u[k1], iuv[k1], iuv[k]]), fsurf[fi])
		faces[fi] = inner
		fuv[fi] = iuv
	sel_mode = SEL_FACE
	sel_f.clear()
	for fi in fs:
		sel_f[fi] = true
	mark_dirty()
	return "Inset %d face(s)." % fs.size()

## Subdivide selected faces (all if none): tris -> 4 tris, quads/ngons -> quads around a centre.
## Neighbouring faces get the new edge midpoints so no holes open.
func subdivide() -> String:
	var fs = selected_faces_full()
	if fs.is_empty():
		fs = range(faces.size())
	var mids = {}
	var sel = {}
	for fi in fs:
		sel[fi] = true
	for fi in fs:
		var f: PackedInt32Array = faces[fi]
		for i in f.size():
			var k = ekey(f[i], f[(i + 1) % f.size()])
			if not mids.has(k):
				mids[k] = _add_vert_mix({k.x: 0.5, k.y: 0.5})
	var nf = faces.size()
	var new_sel = []
	for fi in range(nf):
		var f: PackedInt32Array = faces[fi]
		var u: PackedVector2Array = fuv[fi]
		var c = f.size()
		if sel.has(fi):
			var m = PackedInt32Array()
			var mu = PackedVector2Array()
			for i in c:
				m.append(mids[ekey(f[i], f[(i + 1) % c])])
				mu.append((u[i] + u[(i + 1) % c]) * 0.5)
			if c == 3:
				faces[fi] = PackedInt32Array([m[0], m[1], m[2]])
				fuv[fi] = PackedVector2Array([mu[0], mu[1], mu[2]])
				new_sel.append(fi)
				new_sel.append(_add_face(PackedInt32Array([f[0], m[0], m[2]]), PackedVector2Array([u[0], mu[0], mu[2]]), fsurf[fi]))
				new_sel.append(_add_face(PackedInt32Array([m[0], f[1], m[1]]), PackedVector2Array([mu[0], u[1], mu[1]]), fsurf[fi]))
				new_sel.append(_add_face(PackedInt32Array([m[2], m[1], f[2]]), PackedVector2Array([mu[2], mu[1], u[2]]), fsurf[fi]))
			else:
				var combo = {}
				var cu = Vector2.ZERO
				for v in f:
					combo[v] = combo.get(v, 0.0) + 1.0 / float(c)
				for x in u:
					cu += x
				cu /= float(c)
				var ctr = _add_vert_mix(combo)
				var first = true
				for i in c:
					var prev = (i - 1 + c) % c
					var quad = PackedInt32Array([f[i], m[i], ctr, m[prev]])
					var quv = PackedVector2Array([u[i], mu[i], cu, mu[prev]])
					if first:
						faces[fi] = quad
						fuv[fi] = quv
						new_sel.append(fi)
						first = false
					else:
						new_sel.append(_add_face(quad, quv, fsurf[fi]))
		else:
			var changed = false
			var nfv = PackedInt32Array()
			var nuv = PackedVector2Array()
			for i in c:
				nfv.append(f[i])
				nuv.append(u[i])
				var k = ekey(f[i], f[(i + 1) % c])
				if mids.has(k):
					nfv.append(mids[k])
					nuv.append((u[i] + u[(i + 1) % c]) * 0.5)
					changed = true
			if changed:
				faces[fi] = nfv
				fuv[fi] = nuv
	if sel_mode == SEL_FACE:
		sel_f.clear()
		for fi in new_sel:
			sel_f[fi] = true
	mark_dirty()
	return "Subdivided %d face(s)." % fs.size()

func delete_selected() -> String:
	var kill_f = {}
	match sel_mode:
		SEL_VERT:
			for fi in faces.size():
				for v in faces[fi]:
					if sel_v.has(v):
						kill_f[fi] = true
						break
		SEL_EDGE:
			var ef = edge_faces()
			for e in sel_e:
				for fi in ef.get(e, []):
					kill_f[fi] = true
		SEL_FACE:
			kill_f = sel_f.duplicate()
	var n = kill_f.size()
	_remove_faces(kill_f)
	if sel_mode == SEL_VERT:
		# lone selected vertices are dropped by compact()
		pass
	sel_v.clear(); sel_e.clear(); sel_f.clear()
	compact()
	return "Deleted %d face(s)." % n

func _remove_faces(kill: Dictionary) -> void:
	var nf: Array = []
	var nu: Array = []
	var ns = PackedInt32Array()
	for fi in faces.size():
		if kill.has(fi):
			continue
		nf.append(faces[fi])
		nu.append(fuv[fi])
		ns.append(fsurf[fi])
	faces = nf
	fuv = nu
	fsurf = ns
	mark_dirty()

## Drops unused vertices and re-indexes everything.
func compact() -> void:
	var used = PackedInt32Array()
	used.resize(verts.size())
	used.fill(-1)
	for f in faces:
		for v in f:
			used[v] = 1
	var remap = PackedInt32Array()
	remap.resize(verts.size())
	var nv = PackedVector3Array()
	var nb = PackedInt32Array()
	var nw = PackedFloat32Array()
	for i in verts.size():
		if used[i] < 0:
			remap[i] = -1
			continue
		remap[i] = nv.size()
		nv.append(verts[i])
		for j in 4:
			nb.append(bidx[i * 4 + j] if i * 4 + j < bidx.size() else 0)
			nw.append(bwt[i * 4 + j] if i * 4 + j < bwt.size() else 0.0)
	for k in shapes.size():
		var old: PackedVector3Array = shapes[k].pos
		var acc = PackedVector3Array()
		acc.resize(nv.size())
		for i in verts.size():
			if remap[i] >= 0:
				acc[remap[i]] = old[i]
		shapes[k].pos = acc
	for fi in faces.size():
		var f: PackedInt32Array = faces[fi]
		for i in f.size():
			f[i] = remap[f[i]]
		faces[fi] = f
	var nsv = {}
	for v in sel_v:
		if v < remap.size() and remap[v] >= 0:
			nsv[remap[v]] = true
	sel_v = nsv
	var nse = {}
	for e in sel_e:
		if e.x < remap.size() and e.y < remap.size() and remap[e.x] >= 0 and remap[e.y] >= 0:
			nse[ekey(remap[e.x], remap[e.y])] = true
	sel_e = nse
	verts = nv
	bidx = nb
	bwt = nw
	mark_dirty()

## Collapse the selected vertices to their centre (Blender M > At Center).
func merge_at_center() -> String:
	var sv = selected_verts().keys()
	if sv.size() < 2:
		return "Select 2+ vertices to merge."
	var keep: int = sv[0]
	var combo = {}
	for v in sv:
		combo[v] = 1.0 / float(sv.size())
	var c = Vector3.ZERO
	for v in sv:
		c += verts[v]
	verts[keep] = c / float(sv.size())
	for s in shapes:
		var sp: PackedVector3Array = s.pos
		var q = Vector3.ZERO
		for v in sv:
			q += sp[v]
		sp[keep] = q / float(sv.size())
		s.pos = sp
	var remap = {}
	for v in sv:
		remap[v] = keep
	var n = _apply_vertex_remap(remap)
	sel_mode = SEL_VERT
	sel_v = {keep: true}
	sel_e.clear(); sel_f.clear()
	compact()
	return "Merged %d vertices (%d faces collapsed)." % [sv.size(), n]

## Weld vertices closer than `dist` (selection, or all when nothing is selected).
func merge_by_distance(dist: float) -> String:
	var sv = selected_verts().keys()
	if sv.is_empty():
		sv = range(verts.size())
	var p = positions()
	var grid = {}
	var remap = {}
	var inv = 1.0 / maxf(dist, 1e-6)
	for v in sv:
		var cell = Vector3i(floori(p[v].x * inv), floori(p[v].y * inv), floori(p[v].z * inv))
		var found = -1
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var key = cell + Vector3i(dx, dy, dz)
					if grid.has(key):
						for w in grid[key]:
							if p[w].distance_to(p[v]) <= dist:
								found = w
								break
					if found >= 0:
						break
				if found >= 0:
					break
			if found >= 0:
				break
		if found >= 0:
			remap[v] = found
		else:
			if not grid.has(cell):
				grid[cell] = []
			grid[cell].append(v)
	var n = _apply_vertex_remap(remap)
	compact()
	return "Merged %d vertices (%d degenerate faces removed)." % [remap.size(), n]

func _apply_vertex_remap(remap: Dictionary) -> int:
	var kill = {}
	for fi in faces.size():
		var f: PackedInt32Array = faces[fi]
		var u: PackedVector2Array = fuv[fi]
		var nfv = PackedInt32Array()
		var nuv = PackedVector2Array()
		for i in f.size():
			var v: int = remap.get(f[i], f[i])
			if nfv.size() > 0 and nfv[nfv.size() - 1] == v:
				continue
			nfv.append(v)
			nuv.append(u[i])
		if nfv.size() > 1 and nfv[0] == nfv[nfv.size() - 1]:
			nfv.remove_at(nfv.size() - 1)
			nuv.remove_at(nuv.size() - 1)
		var uniq = {}
		for v in nfv:
			uniq[v] = true
		if uniq.size() < 3:
			kill[fi] = true
		faces[fi] = nfv
		fuv[fi] = nuv
	_remove_faces(kill)
	return kill.size()

## Make a face from the selected vertices in selection order (Blender F).
func make_face() -> String:
	var sv = sel_v.keys() if sel_mode == SEL_VERT else selected_verts().keys()
	if sv.size() < 3:
		return "Select 3+ vertices (in order) to make a face."
	var f = PackedInt32Array(sv)
	var u = PackedVector2Array()
	for v in sv:
		u.append(Vector2.ZERO)
	_add_face(f, u, 0)
	mark_dirty()
	return "Made a %d-sided face." % f.size()

func flip_normals() -> String:
	var fs = selected_faces_full()
	if fs.is_empty():
		fs = range(faces.size())
	for fi in fs:
		var f: PackedInt32Array = faces[fi]
		var u: PackedVector2Array = fuv[fi]
		f.reverse()
		u.reverse()
		faces[fi] = f
		fuv[fi] = u
	mark_dirty()
	return "Flipped %d face(s)." % fs.size()

## Joins triangle pairs that share an edge and are nearly coplanar into quads.
func tris_to_quads(max_angle_deg := 25.0) -> String:
	var ef = edge_faces()
	var used = {}
	var kill = {}
	var n = 0
	var lim = cos(deg_to_rad(max_angle_deg))
	var p = positions()
	var cands = []
	for e in ef:
		var fl: Array = ef[e]
		if fl.size() != 2:
			continue
		var a: int = fl[0]
		var b: int = fl[1]
		if (faces[a] as PackedInt32Array).size() != 3 or (faces[b] as PackedInt32Array).size() != 3:
			continue
		if fsurf[a] != fsurf[b]:
			continue
		var d = face_normal_p(faces[a], p).dot(face_normal_p(faces[b], p))
		if d < lim:
			continue
		var elen = p[e.x].distance_to(p[e.y])
		cands.append([elen, e, a, b])
	cands.sort_custom(func(x, y): return x[0] > y[0])  # longest shared edge first = diagonals
	for c in cands:
		var e: Vector2i = c[1]
		var a: int = c[2]
		var b: int = c[3]
		if used.has(a) or used.has(b):
			continue
		var fa: PackedInt32Array = faces[a]
		var fb: PackedInt32Array = faces[b]
		var ua: PackedVector2Array = fuv[a]
		var ub: PackedVector2Array = fuv[b]
		var other_b = -1
		var other_b_uv = Vector2.ZERO
		for i in 3:
			if fb[i] != e.x and fb[i] != e.y:
				other_b = fb[i]
				other_b_uv = ub[i]
		var quad = PackedInt32Array()
		var quv = PackedVector2Array()
		for i in 3:
			quad.append(fa[i])
			quv.append(ua[i])
			var nx = fa[(i + 1) % 3]
			if ekey(fa[i], nx) == e:
				quad.append(other_b)
				quv.append(other_b_uv)
		if quad.size() != 4:
			continue
		faces[a] = quad
		fuv[a] = quv
		kill[b] = true
		used[a] = true
		used[b] = true
		n += 1
	_remove_faces(kill)
	sel_f.clear()
	return "Joined %d triangle pairs into quads." % n

# ---------------------------------------------------------------- sculpt

## Sculpt dab. kind: draw | smooth | inflate | grab(handled by grab_*). Returns touched count.
func sculpt_dab(kind: String, center: Vector3, radius: float, strength: float, invert := false, sym_x := false) -> int:
	var p = positions()
	var r2 = radius * radius
	var vn = vertex_normals(p)
	var centers = [center]
	if sym_x:
		centers.append(Vector3(-center.x, center.y, center.z))
	var touched = 0
	var sign = -1.0 if invert else 1.0
	var nb: Array = neighbors() if kind == "smooth" else []
	var orig = p.duplicate() if kind == "smooth" else PackedVector3Array()
	for c in centers:
		var avg_n = Vector3.ZERO
		if kind == "draw":
			for i in p.size():
				if (p[i] - c).length_squared() < r2:
					avg_n += vn[i]
			avg_n = avg_n.normalized() if avg_n.length_squared() > 0.0 else Vector3.UP
		for i in p.size():
			var d2 = (p[i] - c).length_squared()
			if d2 >= r2:
				continue
			var x = sqrt(d2) / radius
			var fall = 1.0 - x * x * (3.0 - 2.0 * x)  # smoothstep falloff
			match kind:
				"draw":
					p[i] += avg_n * (radius * 0.08 * strength * fall * sign)
				"inflate":
					p[i] += vn[i] * (radius * 0.08 * strength * fall * sign)
				"smooth":
					var nbs: Dictionary = nb[i]
					if nbs.is_empty():
						continue
					var a = Vector3.ZERO
					for w in nbs:
						a += orig[w]
					a /= float(nbs.size())
					p[i] = p[i].lerp(a, clampf(strength * fall, 0.0, 1.0))
			touched += 1
	set_positions(p)
	return touched

var _grab_set: Array = []
var _grab_w = PackedFloat32Array()
var _grab_base = PackedVector3Array()

func grab_begin(center: Vector3, radius: float, sym_x := false) -> int:
	var p = positions()
	_grab_base = p.duplicate()
	_grab_set.clear()
	_grab_w = PackedFloat32Array()
	for i in p.size():
		var d = p[i].distance_to(center)
		if sym_x:
			d = minf(d, p[i].distance_to(Vector3(-center.x, center.y, center.z)))
		if d < radius:
			var x = d / radius
			_grab_set.append(i)
			_grab_w.append(1.0 - x * x * (3.0 - 2.0 * x))
	return _grab_set.size()

func grab_update(delta: Vector3, sym_x := false) -> void:
	var p = positions()
	for k in _grab_set.size():
		var i: int = _grab_set[k]
		var d = delta
		if sym_x and _grab_base[i].x < 0.0:
			d.x = -d.x
		p[i] = _grab_base[i] + d * _grab_w[k]
	set_positions(p)

# ---------------------------------------------------------------- skin weights

func get_weight(v: int, bone: int) -> float:
	for j in 4:
		if bidx[v * 4 + j] == bone:
			return bwt[v * 4 + j]
	return 0.0

func set_weight(v: int, bone: int, w: float) -> void:
	w = clampf(w, 0.0, 1.0)
	var slot = -1
	for j in 4:
		if bidx[v * 4 + j] == bone and bwt[v * 4 + j] > 0.0:
			slot = j
	if slot < 0:
		var lo = 2.0
		for j in 4:
			if bwt[v * 4 + j] < lo:
				lo = bwt[v * 4 + j]
				slot = j
	bidx[v * 4 + slot] = bone
	var others = 0.0
	for j in 4:
		if j != slot:
			others += bwt[v * 4 + j]
	bwt[v * 4 + slot] = w
	var rest = 1.0 - w
	for j in 4:
		if j == slot:
			continue
		if others > 1e-6:
			bwt[v * 4 + j] = bwt[v * 4 + j] / others * rest
		else:
			bwt[v * 4 + j] = 0.0
	if others <= 1e-6 and w < 1.0:
		bwt[v * 4 + slot] = 1.0  # a lone influence stays fully weighted
	has_skin = true

## Weight brush dab: mode add | subtract | smooth.
func weight_dab(center: Vector3, radius: float, strength: float, bone: int, mode: String) -> int:
	if bidx.size() < verts.size() * 4:
		bidx.resize(verts.size() * 4)
		bwt.resize(verts.size() * 4)
	var p = display_positions()
	var nb: Array = neighbors() if mode == "smooth" else []
	var n = 0
	for i in p.size():
		var d = p[i].distance_to(center)
		if d >= radius:
			continue
		var x = d / radius
		var fall = 1.0 - x * x * (3.0 - 2.0 * x)
		var w = get_weight(i, bone)
		match mode:
			"add":
				w += strength * fall * 0.25
			"subtract":
				w -= strength * fall * 0.25
			"smooth":
				var a = 0.0
				var nbs: Dictionary = nb[i]
				if nbs.is_empty():
					continue
				for q in nbs:
					a += get_weight(q, bone)
				a /= float(nbs.size())
				w = lerpf(w, a, clampf(strength * fall, 0.0, 1.0))
		set_weight(i, bone, w)
		n += 1
	return n

## Automatic envelope weights: each vertex gets the nearest bone segments (inverse distance^4).
## segments: Array of [bone_index, head: Vector3, tail: Vector3] in mesh space.
func auto_weights(segments: Array) -> void:
	bidx = PackedInt32Array()
	bwt = PackedFloat32Array()
	bidx.resize(verts.size() * 4)
	bwt.resize(verts.size() * 4)
	for i in verts.size():
		var p = verts[i]
		var best = []
		for s in segments:
			var cp = Geometry3D.get_closest_point_to_segment(p, s[1], s[2])
			best.append([p.distance_to(cp), s[0]])
		best.sort_custom(func(x, y): return x[0] < y[0])
		var tot = 0.0
		var ws = []
		for j in mini(4, best.size()):
			var w = 1.0 / pow(maxf(best[j][0], 0.005), 4.0)
			ws.append(w)
			tot += w
		for j in 4:
			if j < ws.size():
				bidx[i * 4 + j] = best[j][1]
				bwt[i * 4 + j] = ws[j] / tot
			else:
				bidx[i * 4 + j] = 0
				bwt[i * 4 + j] = 0.0
	has_skin = true

# ---------------------------------------------------------------- shape keys

func add_shape(name: String, from_display := true) -> int:
	var p = display_positions() if from_display else verts.duplicate()
	shapes.append({"name": name, "pos": p, "w": 0.0})
	return shapes.size() - 1

func remove_shape(i: int) -> void:
	if i >= 0 and i < shapes.size():
		shapes.remove_at(i)
		if active_shape >= shapes.size():
			active_shape = -1

# ---------------------------------------------------------------- picking

## Ray in mesh space -> [face_index, hit_point] or [-1, Vector3()].
func raycast(origin: Vector3, dir: Vector3, p: PackedVector3Array = PackedVector3Array()) -> Array:
	if p.is_empty():
		p = display_positions()
	var best = INF
	var best_f = -1
	var best_p = Vector3.ZERO
	for fi in faces.size():
		var f: PackedInt32Array = faces[fi]
		for t in range(1, f.size() - 1):
			var hit: Variant = Geometry3D.ray_intersects_triangle(origin, dir, p[f[0]], p[f[t]], p[f[t + 1]])
			if hit == null:
				continue
			var d = origin.distance_to(hit)
			if d < best:
				best = d
				best_f = fi
				best_p = hit
	return [best_f, best_p]

# ---------------------------------------------------------------- build ArrayMesh

## color_mode: "" | "weights" (needs bone) | "sculpt" (plain clay)
func build_mesh(color_mode := "", bone := -1, positions_override: PackedVector3Array = PackedVector3Array()) -> ArrayMesh:
	var am = ArrayMesh.new()
	var p = positions_override if not positions_override.is_empty() else display_positions()
	if faces.is_empty():
		return am
	var vn = vertex_normals(p)
	var write_shapes = color_mode == "" and positions_override.is_empty() and not shapes.is_empty() and active_shape < 0
	if write_shapes:
		for s in shapes:
			am.add_blend_shape(StringName(s.name))
	var nsurf = 1
	for s in fsurf:
		nsurf = maxi(nsurf, s + 1)
	var shape_vn: Array = []
	if write_shapes:
		for s in shapes:
			shape_vn.append(vertex_normals(s.pos))
	for si in nsurf:
		var vtx = PackedVector3Array()
		var nrm = PackedVector3Array()
		var uvs = PackedVector2Array()
		var bon = PackedInt32Array()
		var wts = PackedFloat32Array()
		var col = PackedColorArray()
		var idx = PackedInt32Array()
		var src = PackedInt32Array()
		var dedupe = {}
		for fi in faces.size():
			if fsurf[fi] != si:
				continue
			var f: PackedInt32Array = faces[fi]
			var u: PackedVector2Array = fuv[fi]
			var fnrm = face_normal_p(f, p)
			var corner = PackedInt32Array()
			for k in f.size():
				var v = f[k]
				var key: Variant
				if smooth_shading:
					key = Vector3i(v, roundi(u[k].x * 65536.0), roundi(u[k].y * 65536.0))
				else:
					key = Vector4i(v, roundi(u[k].x * 65536.0), roundi(u[k].y * 65536.0), fi)
				var ci: int
				if dedupe.has(key):
					ci = dedupe[key]
				else:
					ci = vtx.size()
					dedupe[key] = ci
					vtx.append(p[v])
					nrm.append(vn[v] if smooth_shading else fnrm)
					uvs.append(u[k])
					src.append(v)
					if has_skin and bidx.size() >= verts.size() * 4:
						for j in 4:
							bon.append(bidx[v * 4 + j])
							wts.append(bwt[v * 4 + j])
					if color_mode == "weights":
						col.append(preload("res://addons/chomu_character_studio/ui/studio_theme.gd").heat(get_weight(v, bone) if bone >= 0 and bidx.size() >= verts.size() * 4 else 0.0))
				corner.append(ci)
			for t in range(1, corner.size() - 1):
				idx.append(corner[0])
				idx.append(corner[t])
				idx.append(corner[t + 1])
		if idx.is_empty():
			continue
		var arr = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vtx
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_TEX_UV] = uvs
		if not bon.is_empty() and color_mode == "":
			arr[Mesh.ARRAY_BONES] = bon
			arr[Mesh.ARRAY_WEIGHTS] = wts
		if not col.is_empty():
			arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_INDEX] = idx
		if has_uv and color_mode == "":
			var st = SurfaceTool.new()
			st.create_from_arrays(arr)
			st.generate_tangents()
			var arr2 = st.commit_to_arrays()
			if (arr2[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == vtx.size():
				arr = arr2
		var bsa: Array = []
		if write_shapes:
			for k in shapes.size():
				var sp: PackedVector3Array = shapes[k].pos
				var svn: PackedVector3Array = shape_vn[k]
				var bv = PackedVector3Array()
				var bn = PackedVector3Array()
				bv.resize(vtx.size())
				bn.resize(vtx.size())
				for c in vtx.size():
					bv[c] = sp[src[c]]
					bn[c] = svn[src[c]]
				var b = []
				b.resize(Mesh.ARRAY_MAX)
				b[Mesh.ARRAY_VERTEX] = bv
				b[Mesh.ARRAY_NORMAL] = bn
				if arr[Mesh.ARRAY_TANGENT] != null:
					b[Mesh.ARRAY_TANGENT] = arr[Mesh.ARRAY_TANGENT]
				bsa.append(b)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, bsa)
		var sidx = am.get_surface_count() - 1
		if si < surf_mats.size() and surf_mats[si] != null:
			am.surface_set_material(sidx, surf_mats[si])
	if write_shapes:
		pass
	return am

# ---------------------------------------------------------------- modifiers (return new meshes)

func mod_mirror(axis := 0, merge_dist := 0.001) -> RefCounted:
	var m: RefCounted = duplicate_mesh()
	var n: int = m.verts.size()
	var remap = PackedInt32Array()
	remap.resize(n)
	var ax = Vector3.ONE
	ax[axis] = -1.0
	for i in n:
		if absf(verts[i][axis]) <= merge_dist:
			remap[i] = i
			var v: Vector3 = m.verts[i]
			v[axis] = 0.0
			m.verts[i] = v
		else:
			remap[i] = m._add_vert_from(i)
			m.verts[remap[i]] = verts[i] * ax
			for s in m.shapes:
				var sp: PackedVector3Array = s.pos
				sp[remap[i]] = sp[i] * ax
				s.pos = sp
	var nf: int = faces.size()
	for fi in nf:
		var f: PackedInt32Array = faces[fi]
		var u: PackedVector2Array = fuv[fi]
		var g = PackedInt32Array()
		var gu = PackedVector2Array()
		for k in range(f.size() - 1, -1, -1):
			g.append(remap[f[k]])
			gu.append(u[k])
		m._add_face(g, gu, fsurf[fi])
	m.mark_dirty()
	return m

func mod_array(count := 3, rel_offset := Vector3(1.1, 0, 0)) -> RefCounted:
	var m: RefCounted = duplicate_mesh()
	var size = aabb().size
	var off = rel_offset * size
	var n: int = verts.size()
	for c in range(1, maxi(count, 1)):
		var base: int = m.verts.size()
		for i in n:
			m._add_vert_from(i, off * c)
		for fi in faces.size():
			var f: PackedInt32Array = (faces[fi] as PackedInt32Array).duplicate()
			for k in f.size():
				f[k] += base
			m._add_face(f, (fuv[fi] as PackedVector2Array).duplicate(), fsurf[fi])
	m.mark_dirty()
	return m

## Catmull-Clark subdivision (one level). Every new vertex is a linear mix of old ones, so
## shape keys and skin weights are subdivided too.
func mod_subdivide_cc() -> RefCounted:
	var m: RefCounted = get_script().new()
	m.surf_mats = surf_mats.duplicate()
	m.has_uv = has_uv
	m.has_skin = has_skin
	m.flip = flip
	m.smooth_shading = smooth_shading
	for s in shapes:
		m.shapes.append({"name": s.name, "pos": PackedVector3Array(), "w": s.w})
	var ef = edge_faces()
	var nb = neighbors()
	var n = verts.size()
	var face_combo: Array = []
	for f in faces:
		var c = {}
		for v in f:
			c[v] = c.get(v, 0.0) + 1.0 / float((f as PackedInt32Array).size())
		face_combo.append(c)
	var edge_list: Array = ef.keys()
	var edge_index = {}
	var edge_combo: Array = []
	for ei in edge_list.size():
		var e: Vector2i = edge_list[ei]
		edge_index[e] = ei
		var fl: Array = ef[e]
		var c = {}
		if fl.size() == 2:
			c[e.x] = 0.25
			c[e.y] = 0.25
			for fi in fl:
				for k in face_combo[fi]:
					c[k] = c.get(k, 0.0) + face_combo[fi][k] * 0.25
		else:
			c[e.x] = 0.5
			c[e.y] = 0.5
		edge_combo.append(c)
	var vfaces: Array = []
	vfaces.resize(n)
	for i in n:
		vfaces[i] = []
	for fi in faces.size():
		for v in faces[fi]:
			vfaces[v].append(fi)
	var vert_combo: Array = []
	for i in n:
		var c = {}
		var adj_e = []
		var boundary = []
		for w in nb[i]:
			var e = ekey(i, w)
			adj_e.append(e)
			if (ef.get(e, []) as Array).size() < 2:
				boundary.append(w)
		var k = adj_e.size()
		var vf: Array = vfaces[i]
		if k == 0:
			c[i] = 1.0
		elif not boundary.is_empty():
			if boundary.size() == 2:
				c[i] = 0.75
				c[boundary[0]] = c.get(boundary[0], 0.0) + 0.125
				c[boundary[1]] = c.get(boundary[1], 0.0) + 0.125
			else:
				c[i] = 1.0
		else:
			var kf = float(k)
			# (F + 2R + (k-3)P) / k
			c[i] = (kf - 3.0) / kf
			for fi in vf:
				for q in face_combo[fi]:
					c[q] = c.get(q, 0.0) + face_combo[fi][q] / float(vf.size()) / kf
			for e in adj_e:
				c[e.x] = c.get(e.x, 0.0) + 0.5 / float(k) * 2.0 / kf
				c[e.y] = c.get(e.y, 0.0) + 0.5 / float(k) * 2.0 / kf
		vert_combo.append(c)
	var all_combos: Array = vert_combo + face_combo + edge_combo
	var fbase = n
	var ebase = n + faces.size()
	for si in shapes.size():
		var sp: PackedVector3Array = shapes[si].pos
		var acc = PackedVector3Array()
		acc.resize(all_combos.size())
		for ci in all_combos.size():
			var cc: Dictionary = all_combos[ci]
			var qq = Vector3.ZERO
			for q in cc:
				qq += sp[q] * float(cc[q])
			acc[ci] = qq
		m.shapes[si].pos = acc
	var nverts = PackedVector3Array()
	nverts.resize(all_combos.size())
	var bi2 = PackedInt32Array()
	var bw2 = PackedFloat32Array()
	bi2.resize(all_combos.size() * 4)
	bw2.resize(all_combos.size() * 4)
	for ci in all_combos.size():
		var c: Dictionary = all_combos[ci]
		var pnt = Vector3.ZERO
		for q in c:
			pnt += verts[q] * float(c[q])
		nverts[ci] = pnt
		if has_skin:
			var w4 = _mix_weights(c)
			for j in 4:
				bi2[ci * 4 + j] = w4[0][j]
				bw2[ci * 4 + j] = w4[1][j]
	m.verts = nverts
	m.bidx = bi2
	m.bwt = bw2
	for fi in faces.size():
		var f: PackedInt32Array = faces[fi]
		var u: PackedVector2Array = fuv[fi]
		var c = f.size()
		var cu = Vector2.ZERO
		for x in u:
			cu += x
		cu /= float(c)
		for j in c:
			var jn = (j + 1) % c
			var jp = (j - 1 + c) % c
			var e_next: int = ebase + edge_index[ekey(f[j], f[jn])]
			var e_prev: int = ebase + edge_index[ekey(f[jp], f[j])]
			m._add_face(PackedInt32Array([f[j], e_next, fbase + fi, e_prev]),
				PackedVector2Array([u[j], (u[j] + u[jn]) * 0.5, cu, (u[jp] + u[j]) * 0.5]), fsurf[fi])
	m.mark_dirty()
	return m

## Applies a modifier stack: [{type, enabled, ...params}]
func evaluate(stack: Array) -> RefCounted:
	var m: RefCounted = self
	for md in stack:
		if not md.get("enabled", true):
			continue
		match md.type:
			"Mirror":
				m = m.mod_mirror(int(md.get("axis", 0)), float(md.get("merge", 0.001)))
			"Array":
				m = m.mod_array(int(md.get("count", 3)), md.get("offset", Vector3(1.1, 0, 0)))
			"Subdivision":
				for l in clampi(int(md.get("levels", 1)), 0, 3):
					m = m.mod_subdivide_cc()
	return m
