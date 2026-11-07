extends RefCounted

const Impl := preload("res://addons/chomu_systems/sheet/game_state_machine.gd")

# Mock state for testing
class MockState extends Impl.GameState:
	var entered_count := 0
	var exited_count := 0
	var update_count := 0
	var internal_val := 0
	
	func enter(_m, data):
		entered_count += 1
		if data.has("val"):
			internal_val = data["val"]
			
	func update(_m, _d):
		update_count += 1
		
	func exit(_m):
		exited_count += 1
		
	func get_save_data():
		return {"val": internal_val}
		
	func load_save_data(data):
		internal_val = data.get("val", 0)

func run(t: Node) -> void:
	var gsm := Impl.new(12345)
	var state_a := MockState.new()
	var state_b := MockState.new()
	
	gsm.add_state("A", state_a)
	gsm.add_state("B", state_b)
	
	# Test 1: Basic Transition
	gsm.transition_to("A", {"val": 10})
	t.check("S-36 transition_to A", gsm.get_current_state() == "A", "Should be in state A")
	t.check("S-36 enter callback", state_a.entered_count == 1, "State A enter should be called")
	t.check("S-36 enter data", state_a.internal_val == 10, "Data should be passed to enter")
	
	# Test 2: Update loop
	gsm.update(0.016)
	gsm.update(0.016)
	t.check("S-36 update loop", state_a.update_count == 2, "State A update should be called twice")
	
	# Test 3: State Switch (A -> B)
	gsm.transition_to("B")
	t.check("S-36 transition A to B", gsm.get_current_state() == "B", "Should be in state B")
	t.check("S-36 exit callback", state_a.exited_count == 1, "State A exit should be called")
	t.check("S-36 enter B", state_b.entered_count == 1, "State B enter should be called")
	
	# Test 4: Determinism (RNG)
	var rng := gsm.get_rng()
	var val1 := rng.randf()
	# Re-init new machine with same seed
	var gsm2 := Impl.new(12345)
	var val2 := gsm2.get_rng().randf()
	t.check("S-36 determinism", val1 == val2, "RNG should be seeded and deterministic")
	
	# Test 5: Save/Load
	state_b.internal_val = 42
	var saved := gsm.save_state()
	t.check("S-36 save state name", saved["current_state"] == "B", "Saved state should be B")
	t.check("S-36 save data", saved["state_data"]["val"] == 42, "Saved data should be 42")
	
	# Create new machine to simulate reload
	var gsm_reload := Impl.new()
	var state_a_rel := MockState.new()
	var state_b_rel := MockState.new()
	gsm_reload.add_state("A", state_a_rel)
	gsm_reload.add_state("B", state_b_rel)
	
	gsm_reload.load_state(saved)
	t.check("S-36 load state name", gsm_reload.get_current_state() == "B", "Reloaded state should be B")
	t.check("S-36 load data", state_b_rel.internal_val == 42, "Reloaded data should be 42")
	
	# Test 6: Invalid state
	var success := gsm.transition_to("NON_EXISTENT")
	t.check("S-36 invalid transition", success == false, "Transition to missing state should fail")
