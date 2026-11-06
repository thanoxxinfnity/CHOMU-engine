@tool
extends RefCounted
## Material presets: realistic skin (subsurface), hair (anisotropic), cloth, leather, metal, eyes and anime toon.
## Existing albedo / normal / roughness textures are carried over so a model keeps its look.
## Compatibility renderer note: subsurface scattering and anisotropy are Forward+/Mobile features;
## Compatibility silently falls back to plain PBR.

const TOON := preload("res://addons/chomu_character_studio/shaders/chomu_toon.gdshader")
const OUTLINE := preload("res://addons/chomu_character_studio/shaders/chomu_outline.gdshader")

const PRESETS := ["Skin (realistic)", "Hair (anisotropic)", "Cloth", "Leather", "Metal", "Eyes (glossy)", "Anime toon", "Anime toon + outline"]

static func _src_textures(mat: Material) -> Dictionary:
	var d = {"albedo": null, "normal": null, "rough": null, "color": Color.WHITE}
	if mat is BaseMaterial3D:
		var b = mat as BaseMaterial3D
		d.albedo = b.albedo_texture
		d.color = b.albedo_color
		if b.normal_enabled:
			d.normal = b.normal_texture
		d.rough = b.roughness_texture
	elif mat is ShaderMaterial:
		var t: Variant = (mat as ShaderMaterial).get_shader_parameter("base_texture")
		if t is Texture2D:
			d.albedo = t
		var c: Variant = (mat as ShaderMaterial).get_shader_parameter("base_color")
		if c is Color:
			d.color = c
	return d

static func make(preset: String, src: Material) -> Material:
	var tx = _src_textures(src)
	if preset.begins_with("Anime toon"):
		var sm = ShaderMaterial.new()
		sm.shader = TOON
		if tx.albedo:
			sm.set_shader_parameter("base_texture", tx.albedo)
		sm.set_shader_parameter("base_color", tx.color)
		if preset.ends_with("outline"):
			var ol = ShaderMaterial.new()
			ol.shader = OUTLINE
			sm.next_pass = ol
		return sm
	var m = StandardMaterial3D.new()
	m.albedo_texture = tx.albedo
	m.albedo_color = tx.color
	if tx.normal:
		m.normal_enabled = true
		m.normal_texture = tx.normal
	if tx.rough:
		m.roughness_texture = tx.rough
	match preset:
		"Skin (realistic)":
			m.roughness = 0.55
			m.metallic_specular = 0.45
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.35
			m.subsurf_scatter_skin_mode = true
			m.backlight_enabled = true
			m.backlight = Color(0.55, 0.22, 0.12)
			m.rim_enabled = true
			m.rim = 0.12
			m.rim_tint = 0.6
		"Hair (anisotropic)":
			m.roughness = 0.42
			m.metallic_specular = 0.65
			m.anisotropy_enabled = true
			m.anisotropy = 0.75
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.4
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.rim_enabled = true
			m.rim = 0.2
		"Cloth":
			m.roughness = 0.92
			m.metallic_specular = 0.25
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.75
		"Leather":
			m.roughness = 0.45
			m.metallic_specular = 0.5
			m.clearcoat_enabled = true
			m.clearcoat = 0.25
			m.clearcoat_roughness = 0.5
		"Metal":
			m.metallic = 1.0
			m.roughness = 0.28
		"Eyes (glossy)":
			m.roughness = 0.05
			m.clearcoat_enabled = true
			m.clearcoat = 1.0
			m.clearcoat_roughness = 0.02
	return m

## Applies a preset to one surface (or all when surface < 0) of a MeshInstance3D, undoable.
static func apply(ur: EditorUndoRedoManager, mi: GeometryInstance3D, preset: String, surface := -1) -> String:
	if mi == null:
		return "Select a MeshInstance3D first."
	var mesh_mi = mi as MeshInstance3D
	if mesh_mi == null or mesh_mi.mesh == null:
		ur.create_action("CHoMU: Material " + preset)
		ur.add_do_property(mi, "material_override", make(preset, mi.material_override))
		ur.add_undo_property(mi, "material_override", mi.material_override)
		ur.commit_action()
		return "Applied %s as material override." % preset
	ur.create_action("CHoMU: Material " + preset, UndoRedo.MERGE_DISABLE, mi)
	var n = 0
	for s in mesh_mi.mesh.get_surface_count():
		if surface >= 0 and s != surface:
			continue
		var cur = mesh_mi.get_active_material(s)
		var nm = make(preset, cur)
		ur.add_do_method(mesh_mi, "set_surface_override_material", s, nm)
		ur.add_undo_method(mesh_mi, "set_surface_override_material", s, mesh_mi.get_surface_override_material(s))
		n += 1
	ur.commit_action()
	var note = ""
	if preset.begins_with("Skin") or preset.begins_with("Hair"):
		if str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "gl_compatibility":
			note = " (Compatibility renderer: SSS/anisotropy fall back to plain PBR - switch to Forward+ to see them.)"
	return "Applied %s to %d surface(s) of %s.%s" % [preset, n, mi.name, note]
