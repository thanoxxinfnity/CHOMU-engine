extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/debug_draw_gizmo_pipeline.gd")

func run(t: Node) -> void:
	var pipeline := Impl.new()

	# F-78 register and configure a sphere gizmo
	pipeline.register_gizmo("player_collider", {
		"type": Impl.GIZMO_SPHERE,
		"color": Color(1, 0, 0, 0.5),
		"radius": 1.0,
		"enabled": true,
	})
	t.check("F-78 sphere gizmo registered", pipeline.has_gizmo("player_collider"), "sphere gizmo should exist")
	var cfg := pipeline.get_gizmo_config("player_collider")
	t.check("F-78 sphere config values", cfg != null and cfg.type == Impl.GIZMO_SPHERE and cfg.radius == 1.0, "config should match input")

	# F-78 update transform and draw
	var xform := Transform3D(Basis.IDENTITY, Vector3(5, 2, 0))
	pipeline.update_gizmo_transform("player_collider", xform)
	pipeline.tick()
	var results := pipeline.draw(null, 0.016)
	t.check("F-78 draw returns sphere result", results.size() > 0 and results[0].gizmo_id == "player_collider", "should draw registered gizmo")
	t.check("F-78 draw transform matches", results[0].transform.origin == Vector3(5, 2, 0), "transform should be applied to result")

	# F-78 line gizmo
	pipeline.register_gizmo("debug_line", {
		"type": Impl.GIZMO_LINE,
		"from": Vector3(0, 0, 0),
		"to": Vector3(10, 0, 0),
		"color": Color(0, 1, 0, 1),
	})
	pipeline.tick()
	results = pipeline.draw(null, 0.016)
	var line_found := false
	for r in results:
		if r.gizmo_id == "debug_line":
			line_found = true
			break
	t.check("F-78 line gizmo drawn", line_found, "line gizmo should appear in draw results")

	# F-78 disabled gizmo not drawn
	pipeline.set_gizmo_enabled("debug_line", false)
	pipeline.tick()
	results = pipeline.draw(null, 0.016)
	line_found = false
	for r in results:
		if r.gizmo_id == "debug_line":
			line_found = true
			break
	t.check("F-78 disabled gizmo skipped", not line_found, "disabled gizmo should not be drawn")

	# F-78 box and light gizmos
	pipeline.register_gizmo("hitbox", {"type": Impl.GIZMO_BOX, "size": Vector3(2, 2, 2)})
	pipeline.register_gizmo("light_icon", {"type": Impl.GIZMO_LIGHT, "light_type": "spot", "radius": 0.5})
	pipeline.tick()
	results = pipeline.draw(null, 0.016)
	var box_found := false
	var light_found := false
	for r in results:
		if r.gizmo_id == "hitbox": box_found = true
		if r.gizmo_id == "light_icon": light_found = true
	t.check("F-78 box and light drawn", box_found and light_found, "box and light gizmos should be drawn")

	# F-78 unregister
	pipeline.unregister_gizmo("player_collider")
	t.check("F-78 unregister removes gizmo", not pipeline.has_gizmo("player_collider"), "unregistered gizmo should be gone")
	pipeline.tick()
	results = pipeline.draw(null, 0.016)
	var still_present := false
	for r in results:
		if r.gizmo_id == "player_collider":
			still_present = true
			break
	t.check("F-78 unregistered not drawn", not still_present, "unregistered gizmo should not draw")

	# F-78 save/load state
	pipeline.register_gizmo("persist_sphere", {"type": Impl.GIZMO_SPHERE, "radius": 3.0, "color": Color(0, 0, 1, 1)})
	pipeline.update_gizmo_transform("persist_sphere", Transform3D(Basis.IDENTITY, Vector3(1, 1, 1)))
	pipeline.set_seed(999)
	pipeline.tick()
	var state := pipeline.save_state()
	t.check("F-78 state contains gizmos", state.has("gizmos") and state.has("instances"), "state should serialize gizmos and instances")
	var pipeline2 := Impl.new()
	pipeline2.load_state(state)
	t.check("F-78 loaded state has gizmo", pipeline2.has_gizmo("persist_sphere"), "loaded state should restore gizmo")
	var loaded_cfg := pipeline2.get_gizmo_config("persist_sphere")
	t.check("F-78 loaded config matches", loaded_cfg != null and loaded_cfg.radius == 3.0 and loaded_cfg.color == Color(0, 0, 1, 1), "loaded config should match")
	var loaded_inst := pipeline2._instances.get("persist_sphere", null)
	t.check("F-78 loaded transform matches", loaded_inst != null and loaded_inst.transform.origin == Vector3(1, 1, 1), "loaded transform should match")
	t.check("F-78 loaded seed matches", pipeline2.get_seed() == 999, "loaded seed should match")

	# F-78 clear_frame hides non-persistent gizmos
	pipeline.register_gizmo("temp_gizmo", {"type": Impl.GIZMO_SPHERE, "persistent": false})
	pipeline.register_gizmo("perm_gizmo", {"type": Impl.GIZMO_SPHERE, "persistent": true})
	pipeline.update_gizmo_transform("temp_gizmo", Transform3D.IDENTITY)
	pipeline.update_gizmo_transform("perm_gizmo", Transform3D.IDENTITY)
	pipeline.set_gizmo_visible("temp_gizmo", true)
	pipeline.set_gizmo_visible("perm_gizmo", true)
	pipeline.clear_frame()
	t.check("F-78 clear_frame hides non-persistent", not pipeline._instances.get("temp_gizmo", null).visible, "non-persistent should be hidden")
	t.check("F-78 clear_frame keeps visible flag on persistent", pipeline._instances.get("perm_gizmo", null).visible, "persistent should keep visibility flag")

	# F-78 max results cap
	pipeline.clear_all()
	for i in range(200):
		pipeline.register_gizmo("cap_%d" % i, {"type": Impl.GIZMO_SPHERE})
	pipeline.set_max_results_per_frame(50)
	for i in range(200):
		pipeline.update_gizmo_transform("cap_%d" % i, Transform3D.IDENTITY)
		pipeline.set_gizmo_visible("cap_%d" % i, true)
	pipeline.tick()
	results = pipeline.draw(null, 0.016)
	t.check("F-78 max results cap enforced", results.size() <= 50, "draw results should not exceed cap")

	pipeline.clear_all()
