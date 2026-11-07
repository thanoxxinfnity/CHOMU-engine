extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/component_schema_migration_versioning.gd")

func run(t: Node) -> void:
	var migrator := Impl.new()
	
	# Setup: Component "PlayerStats" evolves from v0 -> v1 -> v2
	migrator.register_component("PlayerStats", 2)
	
	# v0 -> v1: Rename 'hp' to 'health'
	migrator.add_migration("PlayerStats", 0, func(data: Dictionary):
		var new_data = data.duplicate()
		if new_data.has("hp"):
			new_data["health"] = new_data["hp"]
			new_data.erase("hp")
		return new_data
	)
	
	# v1 -> v2: Add 'stamina' with default value
	migrator.add_migration("PlayerStats", 1, func(data: Dictionary):
		var new_data = data.duplicate()
		new_data["stamina"] = 100
		return new_data
	)

	# Test 1: No migration needed (already v2)
	var data_v2 = {"version": 2, "data": {"health": 50, "stamina": 80}}
	var res2 = migrator.migrate("PlayerStats", data_v2)
	t.check("S-38 No migration needed", res2.version == 2 and res2.data.health == 50, "Should remain unchanged")

	# Test 2: Single step migration (v1 -> v2)
	var data_v1 = {"version": 1, "data": {"health": 50}}
	var res1 = migrator.migrate("PlayerStats", data_v1)
	t.check("S-38 Single step migration", res1.version == 2 and res1.data.has("stamina"), "v1 should gain stamina")

	# Test 3: Multi step migration (v0 -> v2)
	var data_v0 = {"version": 0, "data": {"hp": 50}}
	var res0 = migrator.migrate("PlayerStats", data_v0)
	t.check("S-38 Multi step migration", res0.version == 2 and res0.data.has("health") and not res0.data.has("hp"), "v0 should become v2")
	t.check("S-38 Multi step data integrity", res0.data.health == 50 and res0.data.stamina == 100, "Values should be preserved/added")

	# Test 4: Missing migration path (gap in versions)
	migrator.register_component("BrokenComp", 2)
	# Only provide v0 -> v1, skip v1 -> v2
	migrator.add_migration("BrokenComp", 0, func(d): return d)
	var data_broken = {"version": 0, "data": {}}
	var res_broken = migrator.migrate("BrokenComp", data_broken)
	t.check("S-38 Handle migration gap", res_broken.version == 1, "Should stop at the last available migration")

	# Test 5: Unregistered component
	var data_unknown = {"version": 0, "data": {}}
	var res_unknown = migrator.migrate("Unknown", data_unknown)
	t.check("S-38 Unregistered component", res_unknown.version == 0, "Should return original data if component unknown")

	# Test 6: State persistence
	var state = migrator.save_state()
	var migrator2 := Impl.new()
	migrator2.load_state(state)
	t.check("S-38 State persistence", migrator2.get_current_version("PlayerStats") == 2, "Version mapping should persist")
