extends Node3D
## CHoMU Systems self-test. Run headless:
##   godot --headless --path <project> res://addons/chomu_systems/tests/self_test.tscn
## Prints PASS/FAIL per check and exits with code 0 when everything passes.

var passed := 0
var failed := 0
var failures: Array[String] = []

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  PASS  ", name, ("  (" + detail + ")") if detail != "" else "")
	else:
		failed += 1
		failures.append(name)
		print("  FAIL  ", name, ("  (" + detail + ")") if detail != "" else "")

func physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	print("=== CHoMU Systems self-test ===")
	await get_tree().process_frame
	await test_device_tier()
	test_tension()
	test_flicker()
	test_fear_exposure()
	test_stress_fx()
	test_hfsm()
	test_bt()
	test_goap()
	await test_perception()
	await test_replay()
	await test_streamer()
	await test_ragdoll()
	await test_wind_buoyancy()
	await run_item_tests()
	print("=== %d passed, %d failed ===" % [passed, failed])
	if failed > 0:
		print("FAILED: ", ", ".join(failures))
	get_tree().quit(0 if failed == 0 else 1)

# ------------------------------------------------------------------ 1 DeviceTier
func test_device_tier() -> void:
	print("[DeviceTier]")
	var dt := get_node_or_null("/root/ChomuDeviceTier")
	check("autoload present", dt != null)
	if dt == null:
		return
	var DT: GDScript = dt.get_script()
	var lo: float = DT.classify_score(5.0, 30.0, 4, 3.0)
	var hi: float = DT.classify_score(60.0, 300.0, 16, 32.0)
	check("score ordering", hi > lo, "low %.1f high %.1f" % [lo, hi])
	check("tier from score", DT.tier_from_score(lo) == 0 and DT.tier_from_score(hi) == 3, "%d / %d" % [DT.tier_from_score(lo), DT.tier_from_score(hi)])
	# benchmark (autoload starts it on first launch; force a fresh one)
	if dt.benchmarking:
		await dt.benchmark_finished
	dt.clear_cache()
	dt.run_benchmark()
	check("benchmark is time-sliced (frames keep coming)", dt.benchmarking)
	await dt.benchmark_finished
	var took: float = dt.last_benchmark_seconds
	check("benchmark ~2 s", took > 1.8 and took < 3.0, "%.2f s, tier %s" % [took, dt.TIER_NAMES[dt.tier]])
	check("benchmark cached", FileAccess.file_exists(dt.CACHE_PATH))
	dt.apply_tier(2)
	check("apply tier sets viewport msaa", get_viewport().msaa_3d == Viewport.MSAA_2X)
	dt.set_power_profile(2)
	check("saver caps fps at 30", Engine.max_fps == 30)
	dt.set_power_profile(1)
	check("balanced caps fps at 60", Engine.max_fps == 60)
	# DRS
	dt.target_ms = 16.67
	dt.set_resolution_scale(1.0)
	var prev: float = dt.resolution_scale
	var max_step := 0.0
	for i in 60:
		var ns: float = dt.drs_step(33.0)
		max_step = maxf(max_step, absf(ns - dt.resolution_scale))
		dt.set_resolution_scale(ns)
	check("DRS lowers scale under load", dt.resolution_scale < prev - 0.2, "1.00 -> %.2f" % dt.resolution_scale)
	check("DRS step <= 0.1", max_step <= 0.1001, "max %.3f" % max_step)
	for i in 120:
		dt.set_resolution_scale(dt.drs_step(8.0))
	check("DRS recovers when light", dt.resolution_scale > 0.95, "%.2f" % dt.resolution_scale)
	var before: float = dt.resolution_scale
	dt.set_resolution_scale(dt.drs_step(16.0))
	check("DRS hysteresis holds near target", absf(dt.resolution_scale - before) < 0.031)
	var rising := PackedFloat32Array()
	for i in 30:
		rising.append(16.0 + i * 0.2)
	check("thermal trend slope", DT.trend_slope(rising) > 0.15, "%.3f" % DT.trend_slope(rising))
	dt.set_thermal_stage(2, "test")
	check("thermal stage 2 drops tier", dt.tier == 1 and dt.resolution_scale <= dt.scale_min + 0.001, "tier %d" % dt.tier)
	dt.set_thermal_stage(0, "test")
	print("    temp read: %.1f C, power source: %s" % [dt.read_temperature_c(), dt.get_power_source()])

# ------------------------------------------------------------------ 2 Atmosphere
func test_tension() -> void:
	print("[TensionDirector]")
	var player := Node3D.new()
	add_child(player)
	var threat := Node3D.new()
	add_child(threat)
	threat.position = Vector3(40, 0, 0)
	var td := ChomuTensionDirector.new()
	td.player = player
	td.threats = [threat]
	td.darkness_override = 0.2
	add_child(td)
	td.set_physics_process(false)
	for i in 60:
		td.step(1.0 / 30.0)
	var calm := td.tension
	check("calm when threat far", calm < 0.3, "%.2f" % calm)
	threat.position = Vector3(1.5, 0, 0)
	td.darkness_override = 1.0
	var states: Array[int] = []
	td.state_changed.connect(func(s: int, _o: int) -> void: states.append(s))
	for i in 90:
		td.step(1.0 / 30.0)
	check("tension rises near threat", td.tension > 0.75, "%.2f" % td.tension)
	check("enters PEAK", states.has(ChomuTensionDirector.State.PEAK))
	threat.position = Vector3(60, 0, 0)
	td.darkness_override = 0.0
	for i in 30 * 14:
		td.step(1.0 / 30.0)
	check("peak -> relax", states.has(ChomuTensionDirector.State.RELAX))
	check("relax -> build-up (hysteresis)", states.size() >= 3 and states[-1] == ChomuTensionDirector.State.BUILD_UP, str(states))
	td.queue_free()
	player.queue_free()
	threat.queue_free()

func test_flicker() -> void:
	print("[FlickerCircuit]")
	var a := ChomuFlickerCircuit.new()
	var b := ChomuFlickerCircuit.new()
	var c := ChomuFlickerCircuit.new()
	a.make_audio = false
	b.make_audio = false
	c.make_audio = false
	var la := OmniLight3D.new()
	la.light_energy = 2.0
	add_child(la)
	a.light = la
	la.add_child(a)
	add_child(b)
	add_child(c)
	a.reseed(77)
	b.reseed(77)
	c.reseed(78)
	var same := true
	var diff := false
	var min_l := 1.0
	for i in 300:
		var x := a.step(1.0 / 60.0)
		var y := b.step(1.0 / 60.0)
		var z := c.step(1.0 / 60.0)
		same = same and is_equal_approx(x, y)
		diff = diff or not is_equal_approx(x, z)
		min_l = minf(min_l, x)
	check("same seed -> identical flicker", same)
	check("different seed -> different flicker", diff)
	check("light energy follows circuit", is_equal_approx(la.light_energy, 2.0 * a.level), "%.2f" % la.light_energy)
	check("flicker dips", min_l < 0.6, "min %.2f" % min_l)
	ChomuSettings.photosensitivity_safe = true
	a.chaos = 1.0
	a.rate_hz = 15.0
	var worst := 0
	var safe_min := 1.0
	for i in 600:
		safe_min = minf(safe_min, a.step(1.0 / 60.0))
		if i >= 60: # ignore the window that still holds pre-safe-mode dips
			worst = maxi(worst, a.flashes_last_second())
	check("safe mode <= 3 dips/s", worst <= 3, "worst %d per s" % worst)
	check("safe mode shallow dips", safe_min > 0.6, "min %.2f" % safe_min)
	ChomuSettings.photosensitivity_safe = false
	# buzz shares the circuit: amplitude is a function of level
	check("buzz tied to level", a.effective_rate() == 15.0)
	la.queue_free()
	b.queue_free()
	c.queue_free()

func test_fear_exposure() -> void:
	print("[FearExposure]")
	var fe := ChomuFearExposure.new()
	fe.camera_attributes = CameraAttributesPractical.new()
	fe.probe_luminance = false
	add_child(fe)
	fe.set_process(false)
	fe.luminance = 0.05
	for i in 60:
		fe.step(1.0 / 60.0)
	var one_s := fe.exposure
	check("dark adaptation is slow", one_s > 1.0 and one_s < 1.6, "%.2f after 1 s" % one_s)
	for i in 60 * 15:
		fe.step(1.0 / 60.0)
	check("adapts fully to dark", fe.exposure > 2.0, "%.2f" % fe.exposure)
	fe.luminance = 2.0
	for i in 60:
		fe.step(1.0 / 60.0)
	check("bright adaptation is fast", fe.exposure < 0.8, "%.2f" % fe.exposure)
	fe.luminance = 0.05
	var e0 := fe.exposure
	fe.hold_darkness(2.0)
	for i in 60:
		fe.step(1.0 / 60.0)
	check("hold darkness suppresses adaptation", fe.exposure - e0 < 0.05, "%.3f -> %.3f" % [e0, fe.exposure])
	check("writes camera attributes", is_equal_approx(fe.camera_attributes.exposure_multiplier, fe.exposure))
	fe.queue_free()

func test_stress_fx() -> void:
	print("[StressPostFX]")
	var sf := ChomuStressPostFX.new()
	var cam := Camera3D.new()
	cam.fov = 70
	add_child(cam)
	sf.camera = cam
	add_child(sf)
	sf.set_process(false)
	sf.stress_input = 1.0
	for i in 120:
		sf.step(1.0 / 60.0)
	var p := sf.current_params()
	check("full stress -> strong aberration", float(p["aberration"]) > 0.008, str(p))
	var fovs := []
	for i in 60:
		sf.step(1.0 / 60.0)
		fovs.append(cam.fov)
	check("FOV breathing moves", fovs.max() - fovs.min() > 1.0, "%.2f deg" % (fovs.max() - fovs.min()))
	sf.safe_mode = true
	for i in 30:
		sf.step(1.0 / 60.0)
	p = sf.current_params()
	check("safe mode caps aberration + grain", float(p["aberration"]) <= 0.002 and float(p["grain"]) == 0.0, str(p))
	sf.stress_input = 0.0
	sf.step(0.1)
	check("safe mode slew-limits stress", sf.stress > 0.9, "%.2f" % sf.stress)
	sf.queue_free()
	cam.queue_free()

# ------------------------------------------------------------------ 3 AI
func test_hfsm() -> void:
	print("[HFSM]")
	var f := ChomuHFSM.new()
	f.auto_update = false
	add_child(f)
	var log: Array[String] = []
	var flags := {"see": false, "alarm": false}
	f.add_state("Idle", null, func() -> void: log.append("+Idle"), func() -> void: log.append("-Idle"))
	var combat := f.add_state("Combat", null, func() -> void: log.append("+Combat"), func() -> void: log.append("-Combat"))
	f.add_state("Attack", combat, func() -> void: log.append("+Attack"), func() -> void: log.append("-Attack"))
	f.add_state("Search", combat, func() -> void: log.append("+Search"), func() -> void: log.append("-Search"))
	f.add_state("Flee", null, func() -> void: log.append("+Flee"))
	f.add_transition("Idle", "Combat", func() -> bool: return flags["see"])
	f.add_transition("Attack", "Search", func() -> bool: return not flags["see"])
	f.add_transition("Combat", "Flee", func() -> bool: return flags["alarm"])
	f.start("Idle")
	f.update(0.1)
	check("starts in Idle", f.current_path() == "Idle")
	flags["see"] = true
	f.update(0.1)
	check("enters initial child", f.current_path() == "Combat/Attack", f.current_path())
	flags["see"] = false
	f.update(0.1)
	check("sibling transition keeps parent", f.current_path() == "Combat/Search" and not log.slice(-2).has("-Combat"), str(log.slice(-2)))
	flags["alarm"] = true
	f.update(0.1)
	check("outer transition overrides", f.current_path() == "Flee" and log.slice(-3) == ["-Search", "-Combat", "+Flee"], str(log.slice(-3)))
	f.queue_free()

func test_bt() -> void:
	print("[BehaviourTree]")
	var hits := []
	var bt := ChomuBT.new(ChomuBT.selector([
		ChomuBT.sequence([ChomuBT.condition(func(bb: Dictionary) -> bool: return bb["armed"]), ChomuBT.action(func(_bb: Dictionary, _dt: float) -> int:
			hits.append("shoot")
			return ChomuBT.SUCCESS)]),
		ChomuBT.action(func(_bb: Dictionary, _dt: float) -> int:
			hits.append("run")
			return ChomuBT.RUNNING)]))
	check("selector falls through", bt.tick({"armed": false}) == ChomuBT.RUNNING and hits[-1] == "run")
	check("sequence succeeds", bt.tick({"armed": true}) == ChomuBT.SUCCESS and hits[-1] == "shoot")
	var u := ChomuBT.utility([ChomuBT.action(func(_b: Dictionary, _d: float) -> int: return ChomuBT.SUCCESS), ChomuBT.action(func(_b: Dictionary, _d: float) -> int: return ChomuBT.FAILURE)],
		[func(bb: Dictionary) -> float: return bb["a"], func(bb: Dictionary) -> float: return bb["b"]])
	var ub := ChomuBT.new(u)
	ub.tick({"a": 0.2, "b": 0.9})
	check("utility picks highest score", u.last_choice == 1)
	ub.tick({"a": 0.9, "b": 0.1})
	check("utility switches", u.last_choice == 0)
	var inv := ChomuBT.new(ChomuBT.invert(ChomuBT.condition(func(_bb: Dictionary) -> bool: return true)))
	check("inverter", inv.tick({}) == ChomuBT.FAILURE)

func test_goap() -> void:
	print("[GOAP]")
	var g := ChomuGOAP.new()
	g.add_action("get_axe", {"has_axe": false}, {"has_axe": true}, 2.0)
	g.add_action("chop_wood", {"has_axe": true}, {"has_wood": true}, 4.0)
	g.add_action("gather_sticks", {}, {"has_wood": true}, 8.0)
	g.add_action("make_fire", {"has_wood": true}, {"warm": true}, 1.0)
	var p := g.plan({"has_axe": false}, {"warm": true})
	check("finds cheapest plan", p == ["get_axe", "chop_wood", "make_fire"], str(p))
	check("plan cost", is_equal_approx(g.plan_cost(p), 7.0))
	g.add_action("buy_axe_cheap", {}, {"has_axe": true}, 0.5)
	p = g.plan({}, {"warm": true})
	check("replans with new action", p[0] == "buy_axe_cheap", str(p))
	var g2 := ChomuGOAP.new()
	g2.add_action("a", {"x": true}, {"y": true}, 1.0)
	check("impossible goal fails", g2.plan({}, {"y": true}).is_empty() and g2.status == ChomuGOAP.FAILED)
	g.start({}, {"warm": true})
	var frames := 0
	while g.step(1) == ChomuGOAP.SEARCHING:
		frames += 1
	check("time-sliced search matches", g.result == p and frames > 0, "%d slices" % frames)

func test_perception() -> void:
	print("[Perception]")
	ChomuLightProbe.invalidate()
	var target := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = SphereShape3D.new()
	target.add_child(cs)
	target.add_to_group(&"chomu_perceivable")
	add_child(target)
	target.global_position = Vector3(0, 0, -8)
	var light := OmniLight3D.new()
	light.omni_range = 6.0
	light.light_energy = 2.0
	add_child(light)
	light.global_position = Vector3(0, 2.5, -8)
	ChomuLightProbe.invalidate()
	var pc := ChomuPerception.new()
	add_child(pc)
	pc.global_position = Vector3(0, 1.0, 0)
	pc.set_physics_process(false)
	await physics_frames(2)
	pc.sense(0.1)
	check("sees lit target in cone", pc.sees(target))
	pc.rotation.y = PI
	pc.sense(0.1)
	check("loses target behind", not pc.sees(target) and pc.confidence_of(target) < 1.0, "conf %.2f" % pc.confidence_of(target))
	pc.rotation.y = 0
	light.visible = false
	ChomuLightProbe.invalidate()
	pc.sense(0.1)
	check("dark far target hidden", not pc.sees(target))
	target.global_position = Vector3(0, 0, -2)
	pc.sense(0.1)
	check("dark near target seen", pc.sees(target))
	light.visible = true
	target.global_position = Vector3(0, 0, -8)
	var wall := StaticBody3D.new()
	var ws := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(4, 4, 0.3)
	ws.shape = bx
	wall.add_child(ws)
	add_child(wall)
	wall.global_position = Vector3(0, 1, -4)
	ChomuLightProbe.invalidate()
	await physics_frames(2)
	pc.sense(0.1)
	check("wall blocks sight", not pc.sees(target))
	check("hears close noise", pc.hear(Vector3(3, 1, 0), 1.0))
	check("misses far noise", not pc.hear(Vector3(40, 1, 0), 1.0))
	check("occluded noise is quieter", not pc.hear(Vector3(0, 1, -10), 1.0) and pc.hear(Vector3(0, 1, -6), 1.0))
	for i in 60:
		pc.sense(0.1)
	check("memory decays and forgets", not pc.memory.has(target))
	for n in [target, light, pc, wall]:
		n.queue_free()

# ------------------------------------------------------------------ 4 Replay
const TickHook := preload("res://addons/chomu_systems/tests/tick_hook.gd")
var _sim_pos := Vector2.ZERO
var _sim_on := false
var _drive_on := false
var _driver_rng := RandomNumberGenerator.new()
var _acts: Array[StringName] = [&"chomu_t_left", &"chomu_t_right", &"chomu_t_up", &"chomu_t_down"]

func _sim_tick(_d: float) -> void:
	var rp := get_node("/root/ChomuReplay")
	if not _sim_on or not (rp.is_recording() or rp.is_playing()):
		return
	var v := Vector2(Input.get_axis(&"chomu_t_left", &"chomu_t_right"), Input.get_axis(&"chomu_t_up", &"chomu_t_down"))
	_sim_pos += v * 0.1 + Vector2(rp.rng.randf() - 0.5, rp.rng.randf() - 0.5) * 0.01
	rp.checksum(_sim_pos)

func _drive_tick(_d: float) -> void:
	if not _drive_on:
		return
	for a in _acts:
		Input.action_release(a)
	if _driver_rng.randf() < 0.7:
		Input.action_press(_acts[_driver_rng.randi() % 4])

func test_replay() -> void:
	print("[Replay]")
	var rp := get_node_or_null("/root/ChomuReplay")
	check("autoload present", rp != null)
	if rp == null:
		return
	for a in _acts:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	var drv := TickHook.new()
	drv.process_physics_priority = -2000
	drv.cb = _drive_tick
	add_child(drv)
	var sim := TickHook.new()
	sim.process_physics_priority = 10
	sim.cb = _sim_tick
	add_child(sim)
	_driver_rng.seed = 99
	_sim_pos = Vector2.ZERO
	_drive_on = true
	_sim_on = true
	rp.start_recording(12345, _acts)
	await physics_frames(120)
	_drive_on = false
	_sim_on = false
	for a in _acts:
		Input.action_release(a)
	rp.stop()
	var rec_pos := _sim_pos
	check("recorded 120 ticks", rp.frame_count() >= 119, str(rp.frame_count()))
	_sim_pos = Vector2.ZERO
	_sim_on = true
	rp.start_playback()
	var n: int = rp.frame_count()
	await physics_frames(n + 2)
	check("playback ended", not rp.is_playing())
	check("playback reproduces final state", _sim_pos.is_equal_approx(rec_pos), "%s vs %s" % [_sim_pos, rec_pos])
	check("no desync", rp.desync_frame < 0)
	var path := "user://chomu_replay_test.bin"
	check("save", rp.save_to(path) == OK)
	check("load", rp.load_from(path) == OK and rp.frame_count() == n)
	# tamper with one frame -> desync detected at that tick
	var f: Dictionary = rp.frames[40]
	f["a"] = {&"chomu_t_left": 1.0} if f["a"].has(&"chomu_t_right") else {&"chomu_t_right": 1.0}
	_sim_pos = Vector2.ZERO
	rp.start_playback()
	await physics_frames(n + 2)
	_sim_on = false
	check("tampered input -> desync found", rp.desync_frame == 40, "tick %d" % rp.desync_frame)
	drv.queue_free()
	sim.queue_free()

# ------------------------------------------------------------------ 5 Streaming
func test_streamer() -> void:
	print("[WorldStreamer]")
	var tgt := Node3D.new()
	add_child(tgt)
	var ws := ChomuWorldStreamer.new()
	ws.cell_size = 32.0
	ws.load_radius = 1
	ws.unload_margin = 0
	ws.max_instances_per_frame = 4
	ws.update_interval = 0.05
	ws.cell_path_pattern = "res://addons/chomu_systems/demo/cells/cell_{x}_{z}.tscn"
	ws.target = tgt
	add_child(ws)
	tgt.global_position = Vector3(10, 0, 10)
	var ok := false
	for i in 240:
		await get_tree().process_frame
		if ws.loaded.size() == 9:
			ok = true
			break
	check("loads 3x3 around player async", ok, "%d cells" % ws.loaded.size())
	check("cells placed at grid origin", ws.loaded.has(Vector2i(-1, -1)) and (ws.loaded[Vector2i(-1, -1)] as Node3D).position.is_equal_approx(Vector3(-32, 0, -32)))
	tgt.global_position = Vector3(80, 0, 80) # cell (2,2): only 4 neighbours exist on disk
	ok = false
	for i in 240:
		await get_tree().process_frame
		if ws.loaded.size() == 4 and ws.loaded.has(Vector2i(2, 2)) and not ws.loaded.has(Vector2i(0, 0)):
			ok = true
			break
	check("streams forward, unloads behind, skips missing", ok, str(ws.loaded.keys()))
	ws.queue_free()
	tgt.queue_free()

# ------------------------------------------------------------------ 6 Physics
func _floor() -> StaticBody3D:
	var fb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(60, 1, 60)
	cs.shape = bs
	cs.position.y = -0.5
	fb.add_child(cs)
	return fb

func test_ragdoll() -> void:
	print("[ActiveRagdoll]")
	var fl := _floor()
	fl.position = Vector3(100, 0, 0)
	add_child(fl)
	var holder := Node3D.new()
	add_child(holder)
	var limp_d := ChomuRagdollBuilder.build(holder)
	(limp_d["root"] as Node3D).position = Vector3(97, 0.05, 0)
	var act_d := ChomuRagdollBuilder.build(holder)
	(act_d["root"] as Node3D).position = Vector3(103, 0.05, 0)
	var limp := ChomuActiveRagdoll.new()
	limp.simulator = limp_d["simulator"]
	limp.strength = 0.0
	limp_d["root"].add_child(limp)
	var act := ChomuActiveRagdoll.new()
	act.simulator = act_d["simulator"]
	act.strength = 1.0
	act_d["root"].add_child(act)
	await physics_frames(2)
	check("found 7 physical bones", limp.bones.size() == 7 and act.bones.size() == 7, "%d/%d" % [limp.bones.size(), act.bones.size()])
	limp.start()
	act.start()
	await physics_frames(2)
	check("simulating", limp.simulator.is_simulating_physics() and act.simulator.is_simulating_physics())
	await physics_frames(90)
	var le := limp.pose_error()
	var ae := act.pose_error()
	check("powered ragdoll holds pose better than limp", ae < le, "powered %.2f m vs limp %.2f m" % [ae, le])
	var hips_before: Vector3 = act.bones[0].global_position
	act.hit(hips_before, Vector3(40, 0, 0), 0.5)
	check("hit goes limp", act.strength == 0.0)
	await physics_frames(10)
	check("hit moves the body", act.bones[0].global_position.distance_to(hips_before) > 0.05, "%.2f m" % act.bones[0].global_position.distance_to(hips_before))
	await physics_frames(40)
	check("recovers strength", is_equal_approx(act.strength, 1.0))
	holder.queue_free()
	fl.queue_free()

func test_wind_buoyancy() -> void:
	print("[Wind + Buoyancy]")
	var fl := _floor()
	fl.position = Vector3(-100, 0, 0)
	add_child(fl)
	var wind := ChomuWind.new()
	wind.direction = Vector3(1, 0, 0)
	wind.strength = 8.0
	wind.turbulence = 0.0
	add_child(wind)
	var w := wind.sample(Vector3.ZERO)
	check("wind blows along direction", w.x > 7.0 and absf(w.z) < 0.5, str(w))
	var kite := RigidBody3D.new()
	kite.gravity_scale = 0.0
	kite.mass = 1.0
	kite.add_to_group(&"chomu_wind")
	var cs := CollisionShape3D.new()
	cs.shape = SphereShape3D.new()
	kite.add_child(cs)
	add_child(kite)
	kite.global_position = Vector3(-100, 20, 0)
	var water := ChomuWater.new()
	water.make_mesh = false
	add_child(water)
	water.global_position = Vector3(-110, 1.5, 10)
	var crate := _crate(Vector3(-110, 3.0, 10), water)
	var rock := _crate(Vector3(-106, 3.0, 10), null) # no buoyancy
	await physics_frames(240)
	check("wind pushes bodies", kite.linear_velocity.x > 1.0, "vx %.2f" % kite.linear_velocity.x)
	var wh := water.height_at(crate.global_position.x, crate.global_position.z)
	check("crate floats at the surface", absf(crate.global_position.y - wh) < 0.6, "y %.2f water %.2f" % [crate.global_position.y, wh])
	check("body without buoyancy sinks to floor", rock.global_position.y < 0.6, "y %.2f" % rock.global_position.y)
	for n in [wind, kite, water, crate, rock, fl]:
		n.queue_free()

func _crate(pos: Vector3, water: ChomuWater) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = 300.0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1, 0.8, 1)
	cs.shape = bx
	rb.add_child(cs)
	if water:
		var b := ChomuBuoyancy.new()
		b.water = water
		b.volume = 0.8
		rb.add_child(b)
	add_child(rb)
	rb.global_position = pos
	return rb

# ------------------------------------------------------------------ per-feature item tests
## Every tests/items/test_*.gd extends RefCounted and has `func run(t: Node) -> void`
## (it may await). It reports through t.check(name, cond, detail).
const ITEMS_DIR := "res://addons/chomu_systems/tests/items"

func run_item_tests() -> void:
	var files := DirAccess.get_files_at(ITEMS_DIR)
	var names: Array[String] = []
	for f in files:
		var n := String(f).trim_suffix(".remap")
		if n.begins_with("test_") and n.ends_with(".gd") and not names.has(n):
			names.append(n)
	names.sort()
	for n in names:
		var scr: Script = load(ITEMS_DIR + "/" + n)
		if scr == null or not scr.can_instantiate():
			check("item " + n + " loads", false, "script failed to load")
			continue
		print("[item ", n.trim_prefix("test_").trim_suffix(".gd"), "]")
		var inst: Object = scr.new()
		await inst.call("run", self)
