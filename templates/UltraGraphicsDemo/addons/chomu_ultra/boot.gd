extends Node
## CHoMU Ultra boot autoload (added as "ChomuUltraBoot" when the plugin is enabled).
## On game start - and on every scene change - applies Project Settings > chomu_ultra/runtime_preset
## ("Auto" picks by device tier). Turns on the adaptive governor on phones when chomu_ultra/adaptive_resolution is on.

const Api = preload("res://addons/chomu_ultra/chomu_ultra.gd")
const Presets = preload("res://addons/chomu_ultra/presets.gd")

var _last_scene: Node

func _ready() -> void:
	if not bool(ProjectSettings.get_setting(Presets.APPLY_ON_START, true)):
		return
	_apply_now.call_deferred()
	if bool(ProjectSettings.get_setting(Presets.ADAPTIVE, true)) and OS.has_feature("mobile"):
		Api.enable_adaptive(float(ProjectSettings.get_setting(Presets.TARGET_FPS, 60)))
	if get_tree().has_signal("scene_changed"):
		get_tree().connect("scene_changed", _apply_now)
	else:
		get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	if n == get_tree().current_scene and n != _last_scene:
		_apply_now.call_deferred()

func _apply_now() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene == _last_scene:
		return
	_last_scene = scene
	var wanted := Api.current_preset if Api.current_preset != "" else str(ProjectSettings.get_setting(Presets.RUNTIME_PRESET, "Auto"))
	Api.apply(wanted, scene)
