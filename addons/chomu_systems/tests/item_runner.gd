extends Node3D
## Runs one item test: godot --headless --path <project> res://addons/chomu_systems/tests/item_runner.tscn -- --item=test_f_16.gd

var passed := 0
var failed := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  PASS  ", name, ("  (" + detail + ")") if detail != "" else "")
	else:
		failed += 1
		print("  FAIL  ", name, ("  (" + detail + ")") if detail != "" else "")

func physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	var item := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--item="):
			item = a.trim_prefix("--item=")
	await get_tree().process_frame
	var scr: Script = load("res://addons/chomu_systems/tests/items/" + item)
	if scr == null or not scr.can_instantiate():
		print("  FAIL  item script failed to load")
		failed += 1
	else:
		var inst: Object = scr.new()
		await inst.call("run", self)
	print("=== %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 and passed > 0 else 1)
