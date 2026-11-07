extends RefCounted

const Impl := preload("res://addons/chomu_systems/net/lag_compensation.gd")

func run(t: Node) -> void:
	var lag = Impl.new(60, 1.0)
	
	t.check("F-36 initial state", lag.oldest_tick() == 0 and lag.newest_tick() == 0, "oldest/newest start at 0")
	t.check("F-36 capacity", lag.get_capacity() == 60, "capacity = tick_rate * history_seconds = 60")
	
	var center = Vector3(0, 0, 0)
	lag.record(0, 1, center, 0.5)
	t.check("F-36 record first tick", lag.oldest_tick() == 0 and lag.newest_tick() == 0, "first record sets oldest/newest to 0")
	t.check("F-36 position_at exact", lag.position_at(1, 0) == center, "position_at returns recorded center")
	
	lag.record(1, 1, Vector3(1, 0, 0), 0.5)
	lag.record(2, 1, Vector3(2, 0, 0), 0.5)
	t.check("F-36 newest advances", lag.newest_tick() == 2, "newest_tick advances with newer ticks")
	t.check("F-36 oldest stays", lag.oldest_tick() == 0, "oldest_tick stays at 0")
	
	var interp = lag.position_at(1, 1)
	t.check("F-36 interpolation", interp == Vector3(1, 0, 0), "position_at exact tick returns exact position")
	
	interp = lag.position_at(1, 1)  # exact
	t.check("F-36 exact tick", interp == Vector3(1, 0, 0), "exact tick returns exact position")
	
	interp = lag.position_at(1, 0)  # oldest
	t.check("F-36 oldest tick", interp == Vector3(0, 0, 0), "oldest tick returns oldest position")
	
	interp = lag.position_at(1, 2)  # newest
	t.check("F-36 newest tick", interp == Vector3(2, 0, 0), "newest tick returns newest position")
	
	interp = lag.position_at(1, -10)  # clamp to oldest
	t.check("F-36 clamp older", interp == Vector3(0, 0, 0), "tick older than history clamps to oldest")
	
	interp = lag.position_at(1, 100)  # clamp to newest
	t.check("F-36 clamp newer", interp == Vector3(2, 0, 0), "tick newer than history clamps to newest")
	
	for i in range(3, 63):
		lag.record(i, 1, Vector3(i, 0, 0), 0.5)
	
	t.check("F-36 history cap oldest", lag.oldest_tick() == 3, "after 60 entries oldest advances to 3 (63-60)")
	t.check("F-36 history cap newest", lag.newest_tick() == 62, "newest is 62")
	t.check("F-36 capacity maintained", lag.get_capacity() == 60, "capacity remains 60")
	
	interp = lag.position_at(1, 0)  # older than oldest (3)
	t.check("F-36 clamp after wrap", interp == Vector3(3, 0, 0), "request for tick 0 clamps to oldest (3)")
	
	lag.record(10, 2, Vector3(0, 5, 0), 1.0)
	lag.record(11, 2, Vector3(1, 5, 0), 1.0)
	lag.record(12, 2, Vector3(2, 5, 0), 1.0)
	
	var hit = lag.raycast_at(11, Vector3(0, 0, 0), Vector3(1, 5, 0).normalized(), 10.0)
	t.check("F-36 raycast hit entity 2", hit.has("id") and hit.id == 2, "raycast_at finds entity 2 at tick 11")
	# Hit point should be on sphere surface (distance from center == radius)
	var sphere_center = Vector3(1, 5, 0)
	var radius = 1.0
	t.check("F-36 raycast point on sphere", hit.has("point") and abs(hit.point.distance_to(sphere_center) - radius) < 0.01, "hit point lies on sphere surface")
	t.check("F-36 raycast distance", hit.has("distance") and hit.distance > 0.0, "hit distance positive")
	
	hit = lag.raycast_at(11, Vector3(100, 0, 0), Vector3(-1, 0, 0), 10.0)
	t.check("F-36 raycast miss", hit == {}, "raycast_at returns empty dict on miss")
	
	# At tick 0 (clamped to 3) entity 1 is at (3,0,0) radius 0.5. Ray from origin along +X hits it.
	hit = lag.raycast_at(0, Vector3(0, 0, 0), Vector3(1, 0, 0), 10.0)
	t.check("F-36 raycast old tick clamped hits", hit.has("id") and hit.id == 1, "raycast_at with tick 0 (clamped to 3) hits entity 1 at tick 3")
	t.check("F-36 raycast clamped hit point", hit.has("point") and hit.point.distance_to(Vector3(3, 0, 0)) < 0.51, "hit point near entity 1 at tick 3")
	
	var lag2 = Impl.new(30, 2.0)
	t.check("F-36 custom params capacity", lag2.get_capacity() == 60, "30 tick_rate * 2.0 seconds = 60 capacity")
	t.check("F-36 custom params tick_rate", lag2.get_tick_rate() == 30, "tick_rate stored correctly")
	t.check("F-36 custom params history", lag2.get_history_seconds() == 2.0, "history_seconds stored correctly")
	
	lag2.record(0, 1, Vector3(0, 0, 0), 0.5)
	lag2.record(1, 1, Vector3(10, 0, 0), 0.5)
	var mid = lag2.position_at(1, 0)  # exact
	t.check("F-36 custom exact", mid == Vector3(0, 0, 0), "exact tick works with custom params")
	mid = lag2.position_at(1, 1)
	t.check("F-36 custom exact 2", mid == Vector3(10, 0, 0), "exact tick 1 works")
	
	lag2.record(100, 1, Vector3(100, 0, 0), 0.5)
	t.check("F-36 large gap clears", lag2.oldest_tick() == 100, "large tick gap clears history and resets oldest")
	t.check("F-36 large gap newest", lag2.newest_tick() == 100, "large tick gap resets newest")
	
	t.check("F-36 missing entity returns zero", lag.position_at(999, 10) == Vector3.ZERO, "position_at for unknown entity returns ZERO")
	
	hit = lag.raycast_at(10, Vector3(0, 0, 0), Vector3(1, 0, 0), 5.0)
	t.check("F-36 raycast missing tick empty", hit == {}, "raycast_at for tick with no data returns empty")
	
	lag.record(10, 3, Vector3(5, 0, 0), 2.0)
	hit = lag.raycast_at(10, Vector3(0, 0, 0), Vector3(1, 0, 0), 10.0)
	t.check("F-36 raycast hits large sphere", hit.has("id") and hit.id == 3, "raycast hits large sphere at tick 10")
	t.check("F-36 raycast hit distance", hit.distance < 5.0, "hit distance less than sphere center distance")
