@tool
extends EditorPlugin
## Registers the CHoMU Systems autoloads when the plugin is enabled.

const AUTOLOADS := {
	"ChomuDeviceTier": "res://addons/chomu_systems/core/device_tier.gd",
	"ChomuReplay": "res://addons/chomu_systems/replay/replay.gd",
}

func _enable_plugin() -> void:
	for n in AUTOLOADS:
		add_autoload_singleton(n, AUTOLOADS[n])

func _disable_plugin() -> void:
	for n in AUTOLOADS:
		remove_autoload_singleton(n)
