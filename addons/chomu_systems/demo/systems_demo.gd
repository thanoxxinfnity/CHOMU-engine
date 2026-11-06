extends Node3D
## CHoMU Systems demo: exercises every system in one small scene.
## Autopilot walks the player for 6 s while ChomuReplay records, then the run is
## replayed from the same seed and checksums are compared.
## Keys: WASD move (when autopilot is off), 1/2/3 power profile, P photosensitivity-safe,
## T toggle autopilot. Command line: -- --chomu-demo-seconds=12 (auto quit + summary).

const ACTIONS := {"chomu_fwd": KEY_W, "chomu_back": KEY_S, "chomu_left": KEY_A, "chomu_right": KEY_D}
const RECORD_SECONDS := 6.0
const HUD_TEXT := Color(0.92, 0.94, 0.96)
const HUD_ACCENT := Color(0.35, 0.85, 0.95)
const HUD_WARN := Color(1.0, 0.72, 0.25)

var player: CharacterBody3D
var camera: Camera3D
var enemy: CharacterBody3D
var perception: ChomuPerception
var fsm: ChomuHFSM
var goap := ChomuGOAP.new()
var director: ChomuTensionDirector
var stress: ChomuStressPostFX
var fear: ChomuFearExposure
var streamer: ChomuWorldStreamer
var ragdoll: ChomuActiveRagdoll
var flickers: Array[ChomuFlickerCircuit] = []
var crates: Array[RigidBody3D] = []
var hud: Label
var autopilot := true
var t := 0.0
var phase := "record"   ## record -> replay -> live
var replay_result := "pending"
var plan_text := "-"
var bt_choice := "-"
var events: Array[String] = []
var quit_after := -1.0
var _replay_start := Vector3(0, 0, 4)
var _ap_t := 0.0
var _driver: Node

func _ready() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var ev := InputEventKey.new()
			ev.physical_keycode = ACTIONS[a]
			InputMap.action_add_event(a, ev)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--chomu-demo-seconds="):
			quit_after = arg.get_slice("=", 1).to_float()
	_build_world()
	_build_player()
	_build_enemy()
	_build_atmosphere()
	_build_streaming()
	_build_physics()
	_build_hud()
	# autopilot input driver runs before ChomuReplay (-1000) so recording sees it
	_driver = Node.new()
	_driver.name = "AutopilotDriver"
	_driver.process_physics_priority = -2000
	_driver.set_script(preload("res://addons/chomu_systems/demo/autopilot_driver.gd"))
	_driver.set("demo", self)
	add_child(_driver)
	var rp := _replay()
	if rp:
		rp.desync.connect(func(f: int, _e: int, _g: int) -> void: _log("Replay desync at tick %d" % f))
		var acts: Array[StringName] = [&"chomu_fwd", &"chomu_back", &"chomu_left", &"chomu_right"]
		rp.start_recording(4242, acts)
	var dt := _tier()
	if dt:
		dt.tier_applied.connect(func(ti: int, _s: Dictionary) -> void: _log("Tier applied: %s" % dt.TIER_NAMES[ti]))

func _replay() -> Node:
	return get_node_or_null("/root/ChomuReplay")

func _tier() -> Node:
	return get_node_or_null("/root/ChomuDeviceTier")

func _log(s: String) -> void:
	events.append("%5.1fs %s" % [t, s])
	if events.size() > 6:
		events.remove_at(0)
	print("[demo] ", s)

# ------------------------------------------------------------------ build

func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.27, 0.3)
	env.ambient_light_energy = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var dt := _tier()
	if dt:
		dt.apply_to_environment(env)
	var floor_body := StaticBody3D.new()
	floor_body.name = "BaseFloor"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200, 1, 200)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	add_child(floor_body)
	# a wall to block line of sight in places
	var wall := CSGBox3D.new()
	wall.size = Vector3(0.4, 3, 8)
	wall.position = Vector3(-4, 1.5, 0)
	wall.use_collision = true
	add_child(wall)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.add_to_group(&"chomu_perceivable")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cs.shape = cap
	cs.position.y = 1.0
	player.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = CapsuleMesh.new()
	mi.position.y = 1.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.6, 0.85)
	mi.material_override = m
	player.add_child(mi)
	player.position = _replay_start
	add_child(player)
	camera = Camera3D.new()
	camera.position = Vector3(0, 6, 9)
	camera.fov = 70
	add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 1, 0))

func _build_enemy() -> void:
	enemy = CharacterBody3D.new()
	enemy.name = "Wraith"
	enemy.add_to_group(&"chomu_threat")
	var cs := CollisionShape3D.new()
	cs.shape = CapsuleShape3D.new()
	cs.position.y = 1.0
	enemy.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	mi.mesh = cm
	mi.position.y = 1.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.88, 0.9)
	m.emission_enabled = true
	m.emission = Color(0.4, 0.6, 0.7)
	m.emission_energy_multiplier = 0.3
	mi.material_override = m
	enemy.add_child(mi)
	enemy.position = Vector3(-10, 0, -8)
	add_child(enemy)
	perception = ChomuPerception.new()
	perception.position = Vector3(0, 1.7, 0)
	perception.exclude_bodies = [enemy]
	enemy.add_child(perception)
	perception.target_spotted.connect(func(_n: Node3D) -> void: _log("Wraith spotted the player"))
	perception.target_lost.connect(func(_n: Node3D) -> void: _log("Wraith lost sight"))
	perception.noise_heard.connect(func(_p: Vector3, _l: float) -> void: fsm.blackboard["noise"] = _p)
	# GOAP actions for searching
	goap.add_action("go_to_last_known", {"at_last_known": false}, {"at_last_known": true}, 2.0)
	goap.add_action("listen", {"at_last_known": true}, {"has_lead": true}, 1.0)
	goap.add_action("sweep_room", {"at_last_known": true}, {"has_lead": true}, 3.0)
	goap.add_action("follow_lead", {"has_lead": true}, {"player_found": true}, 2.0)
	# HFSM: Patrol | Hunt{Chase, Search}
	fsm = ChomuHFSM.new()
	fsm.name = "WraithBrain"
	add_child(fsm)
	fsm.add_state("Patrol", null, Callable(), Callable(), _patrol)
	var hunt := fsm.add_state("Hunt")
	fsm.add_state("Chase", hunt, Callable(), Callable(), _chase)
	fsm.add_state("Search", hunt, _on_search_enter, Callable(), _search)
	fsm.add_transition("Patrol", "Hunt", func() -> bool: return perception.sees(player) or fsm.blackboard.has("noise"))
	fsm.add_transition("Hunt", "Patrol", func() -> bool: return perception.confidence_of(player) <= 0.0 and not fsm.blackboard.has("noise") and fsm.is_in("Search") and fsm.blackboard.get("search_time", 0.0) > 6.0)
	fsm.add_transition("Chase", "Search", func() -> bool: return not perception.sees(player))
	fsm.add_transition("Search", "Chase", func() -> bool: return perception.sees(player))
	# Chase leaf behaviour: utility picks lunge vs stalk
	var bt := ChomuBT.new(ChomuBT.utility(
		[ChomuBT.action(_bt_stalk, "stalk"), ChomuBT.action(_bt_lunge, "lunge")],
		[func(_bb: Dictionary) -> float: return 0.5,
		 func(_bb: Dictionary) -> float: return 1.0 - clampf(enemy.global_position.distance_to(player.global_position) / 6.0, 0.0, 1.0) + 0.1]))
	fsm.set_behavior("Chase", bt)
	fsm.state_entered.connect(func(p: String) -> void: _log("Wraith -> " + p))
	fsm.start("Patrol")

func _build_atmosphere() -> void:
	var lamp_pos := [Vector3(0, 3, 0), Vector3(-8, 3, -6), Vector3(8, 3, -4)]
	for i in lamp_pos.size():
		var l := OmniLight3D.new()
		l.position = lamp_pos[i]
		l.omni_range = 9.0
		l.light_energy = 1.6
		l.light_color = Color(1.0, 0.85, 0.6)
		add_child(l)
		var fc := ChomuFlickerCircuit.new()
		fc.seed = 100 + i
		fc.chaos = 0.25 + 0.2 * i
		fc.light = l
		l.add_child(fc)
		flickers.append(fc)
	ChomuLightProbe.invalidate()
	director = ChomuTensionDirector.new()
	director.player = player
	director.time_ramp = 20.0
	director.min_scare_interval = 8.0
	add_child(director)
	director.state_changed.connect(func(s: int, _o: int) -> void: _log("Tension state: " + director.STATE_NAMES[s]))
	director.scare_window_opened.connect(_on_scare_window)
	stress = ChomuStressPostFX.new()
	stress.tension_director = director
	stress.camera = camera
	add_child(stress)
	fear = ChomuFearExposure.new()
	fear.camera = camera
	fear.tension_director = director
	camera.add_child(fear)

func _build_streaming() -> void:
	streamer = ChomuWorldStreamer.new()
	streamer.name = "WorldStreamer"
	streamer.cell_size = 32.0
	streamer.load_radius = 1
	streamer.cell_path_pattern = "res://addons/chomu_systems/demo/cells/cell_{x}_{z}.tscn"
	streamer.target = player
	streamer.position.y = -0.02
	add_child(streamer)
	streamer.cell_loaded.connect(func(c: Vector2i, _n: Node) -> void: _log("Cell %s loaded" % c))
	streamer.cell_unloaded.connect(func(c: Vector2i) -> void: _log("Cell %s unloaded" % c))

func _build_physics() -> void:
	var d := ChomuRagdollBuilder.build(self)
	(d["root"] as Node3D).position = Vector3(5, 0.05, -5)
	ragdoll = ChomuActiveRagdoll.new()
	ragdoll.simulator = d["simulator"]
	ragdoll.strength = 0.7
	(d["root"] as Node3D).add_child(ragdoll)
	var wind := ChomuWind.new()
	wind.strength = 3.0
	add_child(wind)
	var water := ChomuWater.new()
	water.position = Vector3(14, 1.0, 6)
	water.mesh_size = 12.0
	add_child(water)
	for i in 3:
		var rb := RigidBody3D.new()
		rb.mass = 200.0
		rb.position = Vector3(12 + i * 2.0, 2.5 + i * 0.5, 6)
		rb.add_to_group(&"chomu_wind")
		rb.set_meta("wind_area", 1.0)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(1, 0.8, 1)
		cs.shape = bx
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bx.size
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.38, 0.24)
		mi.material_override = m
		rb.add_child(mi)
		var by := ChomuBuoyancy.new()
		by.volume = 0.8
		by.water = water
		rb.add_child(by)
		add_child(rb)
		crates.append(rb)

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.09, 0.78)
	sb.border_color = HUD_ACCENT
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(12, 12)
	cl.add_child(panel)
	hud = Label.new()
	hud.add_theme_color_override("font_color", HUD_TEXT)
	hud.add_theme_font_size_override("font_size", 14)
	panel.add_child(hud)

# ------------------------------------------------------------------ AI callbacks

func _move_enemy(to: Vector3, speed: float, delta: float) -> void:
	var p := enemy.global_position
	var d := Vector3(to.x - p.x, 0, to.z - p.z)
	if d.length() > 0.05:
		enemy.global_position += d.normalized() * minf(speed * delta, d.length())
		enemy.look_at(Vector3(to.x, p.y, to.z), Vector3.UP, true)
		# look_at with use_model_front=true faces +Z; perception looks down -Z, so flip it
		perception.rotation.y = PI

var _patrol_pts := [Vector3(-10, 0, -8), Vector3(10, 0, -8), Vector3(10, 0, 6), Vector3(-10, 0, 6)]
var _patrol_i := 0
func _patrol(delta: float) -> void:
	var tgt: Vector3 = _patrol_pts[_patrol_i]
	_move_enemy(tgt, 2.0, delta)
	if enemy.global_position.distance_to(tgt) < 0.3:
		_patrol_i = (_patrol_i + 1) % _patrol_pts.size()

func _chase(_delta: float) -> void:
	fsm.blackboard["last_known"] = player.global_position

func _bt_stalk(_bb: Dictionary, dt: float) -> int:
	bt_choice = "stalk"
	_move_enemy(player.global_position, 1.6, dt)
	return ChomuBT.RUNNING

func _bt_lunge(_bb: Dictionary, dt: float) -> int:
	bt_choice = "lunge"
	_move_enemy(player.global_position, 3.5, dt)
	if enemy.global_position.distance_to(player.global_position) < 1.2:
		director.register_damage(0.3)
		return ChomuBT.SUCCESS
	return ChomuBT.RUNNING

func _on_search_enter() -> void:
	fsm.blackboard["search_time"] = 0.0
	var plan := goap.plan({"at_last_known": false, "has_lead": false}, {"player_found": true})
	fsm.blackboard["plan"] = plan
	plan_text = " > ".join(plan) if not plan.is_empty() else "(no plan)"
	_log("GOAP plan: " + plan_text)

func _search(delta: float) -> void:
	fsm.blackboard["search_time"] = float(fsm.blackboard.get("search_time", 0.0)) + delta
	var target: Vector3 = fsm.blackboard.get("noise", fsm.blackboard.get("last_known", enemy.global_position))
	_move_enemy(target, 1.8, delta)
	if enemy.global_position.distance_to(target) < 0.5:
		fsm.blackboard.erase("noise")

func _on_scare_window(_tension: float) -> void:
	_log("Scare window - lights stutter")
	for f in flickers:
		f.chaos = 0.9
	director.register_scare()
	fear.hold_darkness(3.0)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		for i in flickers.size():
			flickers[i].chaos = 0.25 + 0.2 * i)

# ------------------------------------------------------------------ input / loop

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var dt := _tier()
		match (e as InputEventKey).physical_keycode:
			KEY_1:
				if dt: dt.set_power_profile(0)
			KEY_2:
				if dt: dt.set_power_profile(1)
			KEY_3:
				if dt: dt.set_power_profile(2)
			KEY_P:
				ChomuSettings.photosensitivity_safe = not ChomuSettings.photosensitivity_safe
				_log("Photosensitivity-safe: %s" % ChomuSettings.photosensitivity_safe)
			KEY_T:
				autopilot = not autopilot

## Called by the driver node at physics priority -2000.
func drive_autopilot(delta: float) -> void:
	var rp := _replay()
	if rp and rp.is_playing():
		return
	if not autopilot or phase != "record":
		for a in ACTIONS:
			if Input.is_action_pressed(a) and not Input.is_key_pressed(ACTIONS[a]):
				Input.action_release(a)
		return
	_ap_t += delta
	var seg := int(_ap_t / 1.5) % 4
	var want: StringName = [&"chomu_fwd", &"chomu_left", &"chomu_back", &"chomu_right"][seg]
	for a in ACTIONS:
		if a == want:
			Input.action_press(a)
		elif Input.is_action_pressed(a):
			Input.action_release(a)

func _physics_process(delta: float) -> void:
	t += delta
	# deterministic player movement from (recorded) input + replay RNG
	var rp := _replay()
	var dir := Vector3(Input.get_axis("chomu_left", "chomu_right"), 0, Input.get_axis("chomu_fwd", "chomu_back"))
	var jitter := 0.0
	if rp:
		jitter = rp.rng.randf_range(-0.05, 0.05)
	player.position += dir.normalized() * (4.0 + jitter) * delta
	if rp and (rp.is_recording() or rp.is_playing()):
		rp.checksum(player.position.snapped(Vector3.ONE * 0.0001))
	if dir.length() > 0.1 and int(t * 60) % 30 == 0:
		ChomuPerception.emit_noise(get_tree(), player.global_position, 0.6)
	camera.global_position = player.global_position + Vector3(0, 6, 8)
	# phases
	if phase == "record" and t >= RECORD_SECONDS and rp:
		rp.stop()
		_log("Recorded %d ticks, replaying" % rp.frame_count())
		player.position = _replay_start
		rp.playback_finished.connect(_on_playback_done, CONNECT_ONE_SHOT)
		rp.start_playback()
		phase = "replay"
	elif phase == "record" and rp == null:
		phase = "live"
	# ragdoll script
	if t > 1.0 and not ragdoll.active:
		ragdoll.start()
		_log("Active ragdoll started")
	if t > 3.0 and t - delta <= 3.0:
		ragdoll.hit(ragdoll.bones[0].global_position + Vector3(0, 0.5, 0), Vector3(30, 5, 0), 1.5)
		_log("Ragdoll hit (limp 1.5 s)")
	if quit_after > 0.0 and t >= quit_after:
		_print_summary()
		get_tree().quit(0)

func _on_playback_done(matched: bool) -> void:
	replay_result = "MATCH" if matched else "DESYNC at tick %d" % _replay().desync_frame
	_log("Replay finished: " + replay_result)
	phase = "live"

func _process(_delta: float) -> void:
	var dt := _tier()
	var lines := PackedStringArray()
	lines.append("CHoMU Systems demo")
	lines.append(dt.status_text() if dt else "DeviceTier autoload missing")
	lines.append("Tension %.2f  [%s]  dark %.2f" % [director.tension, director.state_name(), director.darkness])
	lines.append("Exposure %.2f%s  Stress FX %.2f  Safe mode %s" % [fear.exposure, " (holding)" if fear.is_holding() else "", stress.stress, "on" if ChomuSettings.photosensitivity_safe else "off"])
	lines.append("Flicker %.2f / %.2f / %.2f" % [flickers[0].level, flickers[1].level, flickers[2].level])
	lines.append("Wraith %s  BT:%s  sees:%s" % [fsm.current_path(), bt_choice, perception.sees(player)])
	lines.append("GOAP: %s" % plan_text)
	lines.append("Replay: %s (%s)" % [phase, replay_result])
	lines.append("Cells loaded %d  pending %d  at %s" % [streamer.loaded.size(), streamer.pending.size(), streamer.current_cell])
	lines.append("Ragdoll strength %.2f  pose err %.2f m" % [ragdoll.strength, ragdoll.pose_error()])
	var sub := 0.0
	for c in crates:
		sub += (c.get_child(2) as ChomuBuoyancy).submerged
	lines.append("Crates afloat %.2f  crate0 y %.2f" % [sub / 3.0, crates[0].global_position.y])
	lines.append("")
	lines.append_array(events)
	hud.text = "\n".join(lines)

func _print_summary() -> void:
	var dt := _tier()
	print("=== CHoMU Systems demo summary (t=%.1fs) ===" % t)
	if dt: print("DeviceTier: ", dt.status_text())
	print("Tension: %.2f state=%s" % [director.tension, director.state_name()])
	print("Exposure: %.2f  StressFX: %.2f" % [fear.exposure, stress.stress])
	print("Wraith: %s  plan: %s" % [fsm.current_path(), plan_text])
	print("Replay: %s" % replay_result)
	print("Streaming: loaded=%d cells %s" % [streamer.loaded.size(), str(streamer.loaded.keys())])
	print("Ragdoll: active=%s strength=%.2f pose_err=%.2f hips_y=%.2f" % [ragdoll.active, ragdoll.strength, ragdoll.pose_error(), ragdoll.bones[0].global_position.y])
	var ys := PackedStringArray()
	for c in crates:
		ys.append("%.2f" % c.global_position.y)
	print("Crates y: ", ", ".join(ys))
