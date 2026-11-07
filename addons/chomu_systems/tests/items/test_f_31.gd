extends RefCounted

const Impl := preload("res://addons/chomu_systems/tools/perf_regression.gd")

func run(t: Node) -> void:
	var perf = Impl.new()
	
	# Test 1: record_flythrough basic stats
	var samples = PackedFloat32Array([16.0, 16.5, 17.0, 16.2, 16.8, 17.2, 16.1, 16.9, 16.4, 17.1])
	var result = perf.record_flythrough(samples, "medium")
	t.check("F-31 record_flythrough returns correct keys", result.has("tier") and result.has("avg") and result.has("p95") and result.has("p99") and result.has("count"), "Missing keys in result")
	t.check("F-31 record_flythrough tier preserved", result["tier"] == "medium", "Tier not preserved")
	t.check("F-31 record_flythrough count correct", result["count"] == 10, "Count mismatch: %d" % result["count"])
	t.check("F-31 record_flythrough avg reasonable", result["avg"] > 16.0 and result["avg"] < 17.5, "Avg out of range: %.2f" % result["avg"])
	t.check("F-31 record_flythrough p95 >= avg", result["p95"] >= result["avg"], "p95 < avg: %.2f vs %.2f" % [result["p95"], result["avg"]])
	t.check("F-31 record_flythrough p99 >= p95", result["p99"] >= result["p95"], "p99 < p95: %.2f vs %.2f" % [result["p99"], result["p95"]])
	
	# Test 2: save/load baseline roundtrip
	var baseline_path = "user://test_baseline_f31.json"
	var baseline_data = [result, {"tier": "low", "avg": 12.0, "p95": 13.0, "p99": 14.0, "count": 5}]
	perf.save_baseline(baseline_path, baseline_data)
	var loaded = perf.load_baseline(baseline_path)
	t.check("F-31 save/load baseline preserves count", loaded.size() == 2, "Loaded count: %d" % loaded.size())
	t.check("F-31 save/load baseline preserves tier", loaded[0]["tier"] == "medium", "Tier mismatch: %s" % loaded[0]["tier"])
	t.check("F-31 save/load baseline preserves values", abs(loaded[0]["avg"] - result["avg"]) < 0.001, "Avg mismatch: %.3f vs %.3f" % [loaded[0]["avg"], result["avg"]])
	
	# Cleanup
	DirAccess.remove_absolute(ProjectSettings.globalize_path(baseline_path))
	
	# Test 3: compare identical runs -> no regressions
	var current_identical = [result.duplicate(true), {"tier": "low", "avg": 12.0, "p95": 13.0, "p99": 14.0, "count": 5}]
	var regressions = perf.compare(baseline_data, current_identical, 0.03)
	t.check("F-31 compare identical runs reports nothing", regressions.is_empty(), "Got %d regressions for identical data" % regressions.size())
	
	# Test 4: 5% slower p95 -> reported
	var current_slow = [{"tier": "medium", "avg": result["avg"] * 1.02, "p95": result["p95"] * 1.05, "p99": result["p99"] * 1.02, "count": 10}]
	regressions = perf.compare(baseline_data, current_slow, 0.03)
	t.check("F-31 compare 5% slower p95 reported", regressions.size() == 1, "Expected 1 regression, got %d" % regressions.size())
	if regressions.size() > 0:
		t.check("F-31 regression tier correct", regressions[0]["tier"] == "medium", "Tier: %s" % regressions[0]["tier"])
		t.check("F-31 regression metric is p95", regressions[0]["metric"] == "p95", "Metric: %s" % regressions[0]["metric"])
		t.check("F-31 regression pct > 3%", regressions[0]["pct"] > 0.03, "Pct: %.4f" % regressions[0]["pct"])
	
	# Test 5: 2% slower -> not reported (below 3% threshold)
	var current_slight = [{"tier": "medium", "avg": result["avg"] * 1.02, "p95": result["p95"] * 1.02, "p99": result["p99"] * 1.02, "count": 10}]
	regressions = perf.compare(baseline_data, current_slight, 0.03)
	t.check("F-31 compare 2% slower not reported", regressions.is_empty(), "Got %d regressions for 2%% change" % regressions.size())
	
	# Test 6: write_issue only when regressions exist
	var issue_path = "user://test_issue_f31.md"
	var wrote = perf.write_issue(issue_path, [])
	t.check("F-31 write_issue empty regressions returns false", wrote == false, "Should return false for empty regressions")
	t.check("F-31 write_issue empty regressions creates no file", not FileAccess.file_exists(issue_path), "File should not exist")
	
	wrote = perf.write_issue(issue_path, [{"tier": "high", "metric": "p99", "base": 20.0, "now": 22.0, "pct": 0.1}])
	t.check("F-31 write_issue with regressions returns true", wrote == true, "Should return true for non-empty regressions")
	t.check("F-31 write_issue creates markdown file", FileAccess.file_exists(issue_path), "File should exist")
	
	# Verify content
	var file = FileAccess.open(issue_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	t.check("F-31 issue file contains tier", content.find("high") >= 0, "Missing tier in issue")
	t.check("F-31 issue file contains metric", content.find("p99") >= 0, "Missing metric in issue")
	t.check("F-31 issue file contains pct", content.find("10.00%") >= 0, "Missing percentage in issue")
	
	# Cleanup
	DirAccess.remove_absolute(ProjectSettings.globalize_path(issue_path))
	
	# Test 7: FlyThrough.camera_path_points
	var curve = Curve3D.new()
	curve.add_point(Vector3(0, 0, 0))
	curve.add_point(Vector3(10, 0, 0))
	curve.add_point(Vector3(10, 10, 0))
	
	var points = Impl.FlyThrough.camera_path_points(curve, 5)
	t.check("F-31 FlyThrough returns correct count", points.size() == 5, "Got %d points" % points.size())
	t.check("F-31 FlyThrough first point at start", points[0].distance_to(Vector3(0, 0, 0)) < 0.01, "First point: %s" % points[0])
	t.check("F-31 FlyThrough last point at end", points[-1].distance_to(Vector3(10, 10, 0)) < 0.01, "Last point: %s" % points[-1])
	
	# Test 8: FlyThrough with n=1
	var single = Impl.FlyThrough.camera_path_points(curve, 1)
	t.check("F-31 FlyThrough n=1 returns one point", single.size() == 1, "Got %d points" % single.size())
	t.check("F-31 FlyThrough n=1 at start", single[0].distance_to(Vector3(0, 0, 0)) < 0.01, "Point: %s" % single[0])
	
	# Test 9: FlyThrough with empty curve
	var empty_curve = Curve3D.new()
	var empty_pts = Impl.FlyThrough.camera_path_points(empty_curve, 10)
	t.check("F-31 FlyThrough empty curve returns empty", empty_pts.is_empty(), "Got %d points" % empty_pts.size())
	
	# Curve3D is RefCounted, no free() needed
