extends RefCounted

const Impl := preload("res://addons/chomu_systems/core/thermal_pid.gd")

func run(t: Node) -> void:
	var pid := Impl.new()
	var dt := 0.1
	
	# Check 1: Steady high headroom keeps stage 0
	var out_high := pid.update(1.0, dt) # Very cool
	var stage_high := pid.stage(out_high)
	t.check("F-03 steady cool is stage 0", stage_high == 0, "Expected stage 0 for headroom 1.0")
	
	# Check 2: Falling headroom escalates stages (1 -> 2 -> 3)
	# Use a fresh PID to ensure we start from stage 0
	var pid_esc := Impl.new()
	var stages_hit: Array[int] = []
	
	# Simulate critical heat (headroom 0.0)
	for i in range(300):
		var out := pid_esc.update(0.0, dt)
		var s := pid_esc.stage(out)
		if stages_hit.is_empty() or s != stages_hit[-1]:
			stages_hit.append(s)
	
	# We expect the sequence to eventually reach 3. 
	# The sequence might be [1, 2, 3] or [0, 1, 2, 3] depending on initial PID state.
	var escalated := stages_hit.size() >= 3 and stages_hit[-1] == 3
	t.check("F-03 escalation 1->2->3", escalated, "Should escalate to stage 3. Sequence: %s" % str(stages_hit))
	
	# Check 3: Recovery steps back down
	var recovered := false
	for i in range(300):
		var out := pid_esc.update(1.0, dt) # Cool down
		var s := pid_esc.stage(out)
		if s == 0:
			recovered = true
			break
	t.check("F-03 recovery to stage 0", recovered, "Should return to stage 0 when cool")
	
	# Check 4: Integral stays bounded (Anti-windup)
	var pid_windup := Impl.new()
	for i in range(1000):
		pid_windup.update(-10.0, dt)
	
	var integral_val := pid_windup._integral
	t.check("F-03 integral bounded", abs(integral_val) <= 2.01, "Integral should be clamped")
	
	# Check 5: No oscillation at target
	var pid_stab := Impl.new()
	var oscillation_count := 0
	var last_s := -1
	for i in range(600):
		var out := pid_stab.update(pid_stab.target_headroom, dt)
		var s := pid_stab.stage(out)
		if last_s != -1 and s != last_s:
			oscillation_count += 1
		last_s = s
	
	t.check("F-03 stability at target", oscillation_count <= 2, "Too many stage changes at target: %d" % oscillation_count)
	
	# Check 6: Static headroom utility
	var h_cool := Impl.headroom_from_temp(30.0)
	var h_mid := Impl.headroom_from_temp(41.5)
	var h_hot := Impl.headroom_from_temp(50.0)
	
	t.check("F-03 headroom_from_temp cool", h_cool == 1.0, "30C should be 1.0")
	t.check("F-03 headroom_from_temp mid", abs(h_mid - 0.5) < 0.01, "41.5C should be ~0.5")
	t.check("F-03 headroom_from_temp hot", h_hot == 0.0, "50C should be 0.0")
