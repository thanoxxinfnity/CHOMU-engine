@tool
extends EditorPlugin
## CHoMU Character Studio - main-screen tab next to 2D / 3D / Script / AssetLib.
## MIT licensed. See README.md.

const StudioPanel = preload("res://addons/chomu_character_studio/ui/studio_panel.gd")
const IC = preload("res://addons/chomu_character_studio/ui/icons.gd")
const SelfTest = preload("res://addons/chomu_character_studio/tests/studio_selftest.gd")

var panel: Control

func _enter_tree() -> void:
	panel = StudioPanel.new()
	panel.name = "CHoMUCharacterStudio"
	panel.setup(self)
	EditorInterface.get_editor_main_screen().add_child(panel)
	_make_visible(false)
	for a in OS.get_cmdline_user_args():
		if a == "--chomu-studio-selftest":
			SelfTest.run_selftest.call_deferred(self, panel)
		elif a.begins_with("--chomu-studio-shots="):
			SelfTest.run_shots.call_deferred(self, panel, a.substr(21))

func _exit_tree() -> void:
	if panel:
		panel.queue_free()
		panel = null

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if panel:
		panel.visible = visible

func _get_plugin_name() -> String:
	return "Character Studio"

func _get_plugin_icon() -> Texture2D:
	return IC.get_icon("studio", 16)
