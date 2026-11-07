extends RefCounted

const Impl := preload("res://addons/chomu_systems/core/residency_budget.gd")

func run(t: Node) -> void:
	# Test 1: Big budget keeps everything at mip 0
	var budget_big = Impl.new(1000000)
	budget_big.add("tex1", 1024, 3, 1.0) # 1024 + 256 + 64 = 1344
	budget_big.add("tex2", 1024, 3, 1.0) # 1344
	var plan_big = budget_big.plan()
	t.check("F-08 big budget mip0", plan_big["tex1"] == 0 and plan_big["tex2"] == 0, "Should stay at mip 0")

	# Test 2: Tight budget drops mips from far/low-importance textures
	var budget_tight = Impl.new(500) # Very tight
	# tex_near: high priority
	budget_tight.add("tex_near", 1024, 3, 1.0) 
	budget_tight.update_view("tex_near", 1.0, 1.0) # prio = 1.0
	# tex_far: low priority
	budget_tight.add("tex_far", 1024, 3, 1.0)
	budget_tight.update_view("tex_far", 1.0, 10.0) # prio = 0.1
	
	var plan_tight = budget_tight.plan()
	t.check("F-08 tight budget priority", plan_tight["tex_far"] > plan_tight["tex_near"], "Far texture should be dropped more")

	# Test 3: Total bytes within budget
	var budget_limit = Impl.new(1000)
	budget_limit.add("t1", 2048, 5, 1.0)
	budget_limit.add("t2", 2048, 5, 1.0)
	var plan_limit = budget_limit.plan()
	var bytes = budget_limit.total_bytes(plan_limit)
	t.check("F-08 within budget", bytes <= 1000, "Total bytes %d should be <= 1000" % bytes)

	# Test 4: Raising importance protects texture
	var budget_imp = Impl.new(500)
	budget_imp.add("t_low", 1024, 3, 0.1)
	budget_imp.add("t_high", 1024, 3, 10.0)
	budget_imp.update_view("t_low", 1.0, 1.0)
	budget_imp.update_view("t_high", 1.0, 1.0)
	
	var plan_imp = budget_imp.plan()
	t.check("F-08 importance protection", plan_imp["t_high"] < plan_imp["t_low"], "High importance should have lower mip index (higher res)")

	# Test 5: Screen size influence
	var budget_screen = Impl.new(500)
	budget_screen.add("t_small", 1024, 3, 1.0)
	budget_screen.add("t_large", 1024, 3, 1.0)
	budget_screen.update_view("t_small", 0.1, 1.0) # prio 0.1
	budget_screen.update_view("t_large", 1.0, 1.0) # prio 1.0
	
	var plan_screen = budget_screen.plan()
	t.check("F-08 screen size influence", plan_screen["t_small"] > plan_screen["t_large"], "Small screen size should drop mips first")
