extends Node3D
## CHoMU Ultra demo: terrain, water, wind foliage, hero PBR props, atmospheric sky, fog, post FX.
## On start it applies `start_preset` ("Auto" = by device tier) through the runtime API.

const Ultra = preload("res://addons/chomu_ultra/chomu_ultra.gd")

@export var start_preset := "Auto"
@export var wet_materials: Array[ShaderMaterial] = []
@export var terrain_material: ShaderMaterial

var _wet_target := 0.0
var _wet := 0.0
var _tier := {}

func _ready() -> void:
	_tier = Ultra.detect()
	var ui := get_node_or_null("UI/Overlay")
	if ui:
		ui.preset_chosen.connect(_on_preset)
		ui.post_toggled.connect(_on_post)
		ui.rain_toggled.connect(func(on: bool): _wet_target = 1.0 if on else 0.0)
	_on_preset(start_preset)
	if OS.has_feature("mobile"):
		Ultra.enable_adaptive(60.0)

func _on_preset(p: String) -> void:
	var r := Ultra.apply(p, self)
	var density: float = {"Low": 0.4, "Medium": 0.7}.get(str(r.preset), 1.0)
	for f in get_node("Foliage").get_children():
		f.set("density", density)
	var ui := get_node_or_null("UI/Overlay")
	if ui:
		ui.set_report(r, _tier)

func _on_post(on: bool) -> void:
	var post := get_node_or_null("ChomuPost")
	if post:
		for c in post.get_children():
			if c.name == "Grade":
				c.visible = on

func _process(delta: float) -> void:
	if absf(_wet - _wet_target) < 0.001:
		return
	_wet = move_toward(_wet, _wet_target, delta * 0.4)
	for m in wet_materials:
		m.set_shader_parameter("wetness", _wet)
	if terrain_material:
		terrain_material.set_shader_parameter("wet_shore", lerpf(0.5, 1.0, _wet))
