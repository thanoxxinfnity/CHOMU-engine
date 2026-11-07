extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/generational_handles.gd")

func run(t: Node) -> void:
	var h: ChomuGenerationalHandles = Impl.new()

	# F-S-18 alloc returns distinct handles and tracks count
	var h1: int = h.alloc_handle()
	var h2: int = h.alloc_handle()
	t.check("F-S-18 alloc returns distinct handles", h1 != h2, "h1=%d h2=%d" % [h1, h2])
	t.check("F-S-18 count after two allocs", h.count() == 2, "count=%d" % h.count())

	# F-S-18 set/get round trip
	h.set_value(h1, 42)
	t.check("F-S-18 get returns stored value", h.get_value(h1) == 42, "got=%s" % str(h.get_value(h1)))

	# F-S-18 invalid handle rejected
	t.check("F-S-18 invalid handle is_valid false", not h.is_valid(12345), "")
	t.check("F-S-18 get invalid returns null", h.get_value(12345) == null, "")
	t.check("F-S-18 set invalid returns false", not h.set_value(12345, 1), "")

	# F-S-18 free invalidates handle and recycles slot
	t.check("F-S-18 free returns true", h.free_handle(h1), "")
	t.check("F-S-18 freed handle invalid", not h.is_valid(h1), "")
	t.check("F-S-18 count after free", h.count() == 1, "count=%d" % h.count())

	# F-S-18 recycled slot gets new generation, old handle stays stale
	var h3: int = h.alloc_handle()
	t.check("F-S-18 recycled handle differs from freed", h3 != h1, "h3=%d h1=%d" % [h3, h1])
	t.check("F-S-18 old handle still invalid after reuse", not h.is_valid(h1), "")
	t.check("F-S-18 new handle valid", h.is_valid(h3), "")

	# F-S-18 save/load round trip
	h.set_value(h2, "hello")
	h.set_value(h3, [1, 2, 3])
	var state: Dictionary = h.save_state()
	var h2_copy: ChomuGenerationalHandles = Impl.new()
	t.check("F-S-18 load_state returns true", h2_copy.load_state(state), "")
	t.check("F-S-18 restored count matches", h2_copy.count() == h.count(), "orig=%d copy=%d" % [h.count(), h2_copy.count()])
	t.check("F-S-18 restored values match", h2_copy.get_value(h2) == "hello" and h2_copy.get_value(h3) == [1, 2, 3], "")
	t.check("F-S-18 restored invalid stays invalid", not h2_copy.is_valid(h1), "")

	# F-S-18 deterministic seeding
	var ha: ChomuGenerationalHandles = Impl.new(12345)
	var hb: ChomuGenerationalHandles = Impl.new(12345)
	t.check("F-S-18 same seed same alloc sequence", ha.alloc_handle() == hb.alloc_handle(), "a=%d b=%d" % [ha.alloc_handle(), hb.alloc_handle()])
