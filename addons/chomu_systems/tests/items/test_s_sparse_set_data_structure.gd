extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/sparse_set_data_structure.gd")

func run(t: Node) -> void:
	var set := Impl.new()
	
	# F-S17-01: Empty set has size 0 and is empty
	t.check("F-S17-01 empty set size", set.size() == 0, "size should be 0")
	t.check("F-S17-02 empty set is_empty", set.is_empty(), "is_empty should be true")
	
	# F-S17-03: Insert returns true for new entities
	t.check("F-S17-03 insert new entity", set.insert(5) == true, "insert should return true")
	t.check("F-S17-04 size after insert", set.size() == 1, "size should be 1")
	
	# F-S17-05: Insert duplicate returns false
	t.check("F-S17-05 insert duplicate", set.insert(5) == false, "duplicate insert should return false")
	
	# F-S17-06: Contains works correctly
	t.check("F-S17-06 contains existing", set.contains(5) == true, "should contain 5")
	t.check("F-S17-07 contains missing", set.contains(10) == false, "should not contain 10")
	
	# F-S17-08: Insert multiple entities
	set.insert(10)
	set.insert(20)
	set.insert(30)
	t.check("F-S17-08 multiple inserts", set.size() == 4, "size should be 4")
	
	# F-S17-09: Erase returns true for existing entities
	t.check("F-S17-09 erase existing", set.erase(10) == true, "erase should return true")
	t.check("F-S17-10 size after erase", set.size() == 3, "size should be 3")
	
	# F-S17-11: Erase non-existent returns false
	t.check("F-S17-11 erase missing", set.erase(99) == false, "erase missing should return false")
	
	# F-S17-12: Contains after erase
	t.check("F-S17-12 contains after erase", set.contains(10) == false, "should not contain erased entity")
	
	# F-S17-13: to_array returns correct entities
	var arr := set.to_array()
	t.check("F-S17-13 to_array count", arr.size() == 3, "array should have 3 elements")
	t.check("F-S17-14 to_array contains 5", arr.has(5), "array should contain 5")
	t.check("F-S17-15 to_array contains 20", arr.has(20), "array should contain 20")
	t.check("F-S17-16 to_array contains 30", arr.has(30), "array should contain 30")
	
	# F-S17-17: Clear resets set
	set.clear()
	t.check("F-S17-17 clear size", set.size() == 0, "size should be 0 after clear")
	t.check("F-S17-18 clear is_empty", set.is_empty(), "is_empty should be true after clear")
	
	# F-S17-19: Serialization round-trip
	set.insert(100)
	set.insert(200)
	set.insert(300)
	var state := set.get_state()
	
	var set2 := Impl.new()
	set2.set_state(state)
	t.check("F-S17-19 deserialize size", set2.size() == 3, "deserialized size should be 3")
	t.check("F-S17-20 deserialize contains 100", set2.contains(100), "should contain 100")
	t.check("F-S17-21 deserialize contains 200", set2.contains(200), "should contain 200")
	t.check("F-S17-22 deserialize contains 300", set2.contains(300), "should contain 300")
	
	# F-S17-23: Erase and re-insert same entity
	set.erase(100)
	t.check("F-S17-23 erase 100", set.contains(100) == false, "should not contain 100")
	set.insert(100)
	t.check("F-S17-24 reinsert 100", set.contains(100), "should contain 100 after reinsert")
	
	# F-S17-25: Large entity ID handling
	var set3 := Impl.new()
	set3.insert(10000)
	set3.insert(20000)
	t.check("F-S17-26 large entity IDs", set3.size() == 2, "should handle large entity IDs")
	t.check("F-S17-27 contains large 10000", set3.contains(10000), "should contain 10000")
	t.check("F-S17-28 contains large 20000", set3.contains(20000), "should contain 20000")
