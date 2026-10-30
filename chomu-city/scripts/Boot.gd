extends Node
## Entry scene: goes to the main menu (keeps project.godot main_scene stable).
func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred(Game.MENU_SCENE)
