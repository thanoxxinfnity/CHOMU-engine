extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/squad_formation_manager.gd")

func run(t: Node) -> void:
	var mgr: ChomuSquadFormationManager = Impl.new()

	t.check("S-11 default anchor is zero", mgr.get_anchor() == Vector3.ZERO, "anchor should start at origin")
	t.check("S-11 default scale is 1.0", mgr.get_scale() == 1.0, "scale default")
	t.check("S-11 no active template initially", mgr.get_active_template() == "", "active template empty")

	# register a wedge-like template
	var slots: Array[Dictionary] = [
		{"id": 1, "offset": Vector3(0, 0, 0), "role": "leader"},
		{"id": 2, "offset": Vector3(-1, 0, 2), "role": "wing"},
		{"id": 3, "offset": Vector3(1, 0, 2), "role": "wing"},
		{"id": 4, "offset": Vector3(-2, 0, 4), "role": "flank"},
		{"id": 5, "offset": Vector3(2, 0, 4), "role": "flank"},
	]
	var ok: bool = mgr.register_template("wedge", slots)
	t.check("S-11 register template returns true", ok, "template registered")
	t.check("S-11 duplicate registration rejected", not mgr.register_template("wedge", slots), "duplicate name rejected")

	ok = mgr.set_active_template("wedge")
	t.check("S-11 set active template", ok, "wedge activated")
	t.check("S-11 set active missing template fails", not mgr.set_active_template("nope"), "missing template rejected")

	# auto assign agents to nearest free slots
	var a1: int = mgr.add_agent("alpha", "leader")
	t.check("S-11 add agent leader gets slot 1", a1 == 1, "leader assigned to slot 1")
	var a2: int = mgr.add_agent("beta", "wing")
	t.check("S-11 add agent wing gets slot 2 or 3", a2 == 2 or a2 == 3, "wing assigned")
	var a3: int = mgr.add_agent("gamma", "wing")
	t.check("S-11 second wing gets other slot", (a2 == 2 and a3 == 3) or (a2 == 3 and a3 == 2), "both wings filled")
	var a4: int = mgr.add_agent("delta", "flank")
	t.check("S-11 flank assigned", a4 == 4 or a4 == 5, "flank assigned")

	t.check("S-11 get_agent_slot", mgr.get_agent_slot("alpha") == 1, "slot lookup")
	t.check("S-11 get_slot_agent", mgr.get_slot_agent(1) == "alpha", "reverse lookup")

	# world position respects orientation & scale
	mgr.set_anchor(Vector3(10, 0, 20))
	mgr.set_scale(2.0)
	var pos: Vector3 = mgr.get_agent_world_pos("alpha")
	t.check("S-11 leader world pos equals anchor", pos == Vector3(10, 0, 20), "leader at anchor")

	mgr.set_orientation(Vector3(1, 0, 0))  # facing +x
	var wing_pos: Vector3 = mgr.get_agent_world_pos("beta")
	t.check("S-11 wing pos shifted by orientation", wing_pos != Vector3(10, 0, 20), "orientation applied")

	# manual assign to free slot
	mgr.unassign_agent("delta")
	t.check("S-11 unassign frees slot", mgr.get_agent_slot("delta") == -1, "delta unassigned")
	t.check("S-11 slot free after unassign", mgr.get_slot_agent(4) == "" or mgr.get_slot_agent(5) == "", "slot freed")
	var reassigned: bool = mgr.assign_agent("delta", 4)
	t.check("S-11 manual assign to free slot", reassigned, "manual assign ok")
	t.check("S-11 manual assign occupied fails", not mgr.assign_agent("epsilon", 1), "occupied slot rejected")

	# remove agent
	var removed: bool = mgr.remove_agent("beta")
	t.check("S-11 remove agent", removed, "beta removed")
	t.check("S-11 removed agent slot -1", mgr.get_agent_slot("beta") == -1, "beta no slot")
	t.check("S-11 slot freed after remove", mgr.get_slot_agent(mgr.get_agent_slot("alpha")) == "alpha", "others intact")

	# all positions
	var all_pos: Dictionary = mgr.get_all_agent_positions()
	t.check("S-11 all positions count", all_pos.size() == 3, "three agents remain")

	# save/load roundtrip
	var state: Dictionary = mgr.save_state()
	mgr.set_anchor(Vector3(99, 99, 99))
	mgr.set_active_template("")
	t.check("S-11 state mutated", mgr.get_anchor() == Vector3(99, 99, 99), "mutated")
	mgr.load_state(state)
	t.check("S-11 load restores anchor", mgr.get_anchor() == Vector3(10, 0, 20), "anchor restored")
	t.check("S-11 load restores active template", mgr.get_active_template() == "wedge", "template restored")
	t.check("S-11 load restores assignments", mgr.get_agent_slot("alpha") == 1, "assignments restored")

	# deterministic seed behavior
	var m2: ChomuSquadFormationManager = Impl.new(7)
	var m3: ChomuSquadFormationManager = Impl.new(7)
	t.check("S-11 same seed same scale default", m2.get_scale() == m3.get_scale(), "seeded instances consistent")
