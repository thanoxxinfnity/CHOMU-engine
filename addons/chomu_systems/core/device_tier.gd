extends Node
## ChomuDeviceTier (autoload) - F-1 tier classifier, F-4 power profiles,
## F-5 frame-time driven dynamic resolution, F-3 thermal governor.
##
## First launch: a ~2 s time-sliced benchmark (CPU math + render frame times)
## plus a small device DB -> Tier (LOW/MID/HIGH/ULTRA). The result is cached in
## user://chomu_device_tier.cfg and applied on every later launch instantly.

signal benchmark_finished(tier: int, score: float)
signal tier_applied(tier: int, settings: Dictionary)
signal power_profile_changed(profile: int)
signal resolution_scale_changed(scale: float)
## stage 0 = normal, 1 = DRS pinned at minimum, 2 = effects lowered (tier -1), 3 = sim LOD requested
signal thermal_stage_changed(stage: int, reason: String)

enum Tier { LOW, MID, HIGH, ULTRA }
enum PowerProfile { PERFORMANCE, BALANCED, SAVER }

const TIER_NAMES := ["Low", "Mid", "High", "Ultra"]
const PROFILE_NAMES := ["Performance", "Balanced", "Saver"]
const CACHE_PATH := "user://chomu_device_tier.cfg"
const BENCH_VERSION := 1

## Quality per tier. Applied to the root viewport; environment-level flags are
## exposed through apply_to_environment() and the tier_applied signal.
const TIER_SETTINGS := {
	Tier.LOW: {"scale": 0.6, "scale_min": 0.5, "msaa": Viewport.MSAA_DISABLED, "fxaa": false,
		"shadow_atlas": 1024, "dir_shadow": 1024, "ssao": false, "ssil": false, "sdfgi": false,
		"glow": false, "volumetric_fog": false, "lod_threshold": 4.0, "fsr": true, "target_fps": 30},
	Tier.MID: {"scale": 0.8, "scale_min": 0.55, "msaa": Viewport.MSAA_DISABLED, "fxaa": true,
		"shadow_atlas": 2048, "dir_shadow": 2048, "ssao": true, "ssil": false, "sdfgi": false,
		"glow": true, "volumetric_fog": false, "lod_threshold": 2.0, "fsr": true, "target_fps": 60},
	Tier.HIGH: {"scale": 1.0, "scale_min": 0.65, "msaa": Viewport.MSAA_2X, "fxaa": false,
		"shadow_atlas": 4096, "dir_shadow": 4096, "ssao": true, "ssil": true, "sdfgi": false,
		"glow": true, "volumetric_fog": true, "lod_threshold": 1.0, "fsr": false, "target_fps": 60},
	Tier.ULTRA: {"scale": 1.0, "scale_min": 0.75, "msaa": Viewport.MSAA_4X, "fxaa": false,
		"shadow_atlas": 8192, "dir_shadow": 8192, "ssao": true, "ssil": true, "sdfgi": true,
		"glow": true, "volumetric_fog": true, "lod_threshold": 0.5, "fsr": false, "target_fps": 60},
}

## Substring device DB: "vendor:device" (lower case) -> max tier allowed / min tier.
## Extend in your game: ChomuDeviceTier.device_db["adreno (tm) 610"] = Tier.LOW
var device_db := {
	"llvmpipe": Tier.LOW, "swiftshader": Tier.LOW, "mali-g52": Tier.LOW, "mali-g57": Tier.LOW,
	"adreno (tm) 610": Tier.LOW, "adreno (tm) 619": Tier.MID, "powervr": Tier.LOW,
	"intel(r) uhd": Tier.LOW, "intel(r) hd": Tier.LOW, "iris": Tier.MID,
	"adreno (tm) 7": Tier.HIGH, "mali-g7": Tier.MID, "immortalis": Tier.HIGH,
	"apple m": Tier.HIGH, "rtx 40": Tier.ULTRA, "rtx 50": Tier.ULTRA, "rx 7": Tier.ULTRA,
}

@export var auto_benchmark := true
@export var benchmark_seconds := 2.0
@export var drs_enabled := true
@export var thermal_enabled := true

var tier: int = Tier.MID
var score: float = 0.0
var power_profile: int = PowerProfile.BALANCED
var resolution_scale: float = 1.0
var benchmarking := false
var thermal_stage := 0
var last_temperature_c: float = -1.0
var device_key := ""
var last_benchmark_seconds := 0.0

# DRS state (formula from blueprint F-5)
var target_ms := 16.67
var drs_alpha := 0.2
var drs_k := 1.0
var drs_hysteresis := 0.03
var drs_max_step := 0.1
var scale_min := 0.5
var _ewma := 16.67
var _ewvar := 0.0
var _gpu_measure_on := false

# thermal
var _trend: PackedFloat32Array = PackedFloat32Array()
var _trend_timer := 0.0
var _thermal_timer := 0.0
var _min_scale_time := 0.0
var _base_tier := Tier.MID
var _temp_path := ""
var _bench_phase := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	device_key = _make_device_key()
	_temp_path = _find_temperature_path()
	if _load_cache():
		apply_tier(tier)
	elif auto_benchmark:
		run_benchmark()
	else:
		apply_tier(Tier.MID)

# ---------------------------------------------------------------- F-1 benchmark

func run_benchmark() -> void:
	if benchmarking:
		return
	benchmarking = true
	_run_benchmark_async()

func _run_benchmark_async() -> void:
	var total := benchmark_seconds
	# Phase 1: CPU micro-benchmark, time-sliced (~8 ms per frame so the app keeps rendering).
	_bench_phase = "cpu"
	var t_start := Time.get_ticks_usec()
	var headless := DisplayServer.get_name() == "headless"
	# no real renderer when headless: spend the whole budget on the CPU phase
	var cpu_frac := 1.0 if headless else 0.4
	var cpu_ops := 0
	var cpu_end := Time.get_ticks_usec() + int(total * cpu_frac * 1e6)
	var acc := 0.0
	while Time.get_ticks_usec() < cpu_end:
		var slice_end := mini(Time.get_ticks_usec() + 8000, cpu_end)
		while Time.get_ticks_usec() < slice_end:
			for i in 2000:
				acc += sin(float(i) * 0.001) * cos(acc * 0.5) + sqrt(float(i + 1))
			cpu_ops += 2000
		await get_tree().process_frame
	var cpu_secs := total * cpu_frac
	var cpu_score := float(cpu_ops) / cpu_secs / 1.0e6 # Mops/s of the loop above
	# Phase 2: render frame times (skipped on the dummy renderer / headless).
	# A real build should also keep a 3D scene on screen during this phase.
	_bench_phase = "gpu"
	var frame_ms := PackedFloat32Array()
	if not headless:
		var gpu_end := Time.get_ticks_usec() + int(total * 0.6 * 1e6)
		var last := Time.get_ticks_usec()
		var old_vsync := DisplayServer.window_get_vsync_mode()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var old_max := Engine.max_fps
		Engine.max_fps = 0
		while Time.get_ticks_usec() < gpu_end:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			frame_ms.append(float(now - last) / 1000.0)
			last = now
		Engine.max_fps = old_max
		DisplayServer.window_set_vsync_mode(old_vsync)
	var gpu_score := 60.0
	if frame_ms.size() > 5:
		var sorted := Array(frame_ms)
		sorted.sort()
		var med: float = sorted[sorted.size() / 2]
		gpu_score = 1000.0 / maxf(med, 0.1)
	score = classify_score(cpu_score, gpu_score, OS.get_processor_count(), _ram_gb())
	var t := tier_from_score(score)
	t = _apply_device_db(t)
	tier = t
	_base_tier = t
	benchmarking = false
	_bench_phase = ""
	last_benchmark_seconds = float(Time.get_ticks_usec() - t_start) / 1e6
	_save_cache(cpu_score, gpu_score)
	apply_tier(tier)
	print("[ChomuDeviceTier] benchmark cpu=%.1f Mops gpu=%.0f fps cores=%d ram=%.1fGB score=%.1f -> %s (%s)" % [cpu_score, gpu_score, OS.get_processor_count(), _ram_gb(), score, TIER_NAMES[tier], device_key])
	benchmark_finished.emit(tier, score)

## Pure function so it can be unit-tested. Returns a 0..100 score.
static func classify_score(cpu_mops: float, gpu_fps: float, cores: int, ram_gb: float) -> float:
	var s_cpu := clampf(cpu_mops / 40.0, 0.0, 1.0) * 35.0
	var s_gpu := clampf(gpu_fps / 240.0, 0.0, 1.0) * 45.0
	var s_cores := clampf(float(cores) / 12.0, 0.0, 1.0) * 10.0
	var s_ram := clampf(ram_gb / 16.0, 0.0, 1.0) * 10.0
	return s_cpu + s_gpu + s_cores + s_ram

static func tier_from_score(s: float) -> int:
	if s < 30.0:
		return Tier.LOW
	if s < 55.0:
		return Tier.MID
	if s < 78.0:
		return Tier.HIGH
	return Tier.ULTRA

func _apply_device_db(t: int) -> int:
	var key := device_key.to_lower()
	for k in device_db:
		if key.contains(k):
			var cap: int = device_db[k]
			# DB entries act as a ceiling for weak chips and a floor for strong ones.
			if cap <= Tier.MID:
				return mini(t, cap)
			return maxi(t, cap)
	return t

func _make_device_key() -> String:
	var vendor := RenderingServer.get_video_adapter_vendor()
	var dev := RenderingServer.get_video_adapter_name()
	var model := OS.get_model_name()
	return "%s:%s:%s" % [vendor, dev, model]

func _ram_gb() -> float:
	var info := OS.get_memory_info()
	var phys: int = info.get("physical", -1)
	if phys <= 0:
		return 4.0
	return float(phys) / 1073741824.0

# ---------------------------------------------------------------- apply quality

## Sets the tier chosen by the game/user (also the thermal governor's baseline).
func apply_tier(t: int) -> void:
	_base_tier = clampi(t, Tier.LOW, Tier.ULTRA)
	_apply_tier_internal(_base_tier)

func _apply_tier_internal(t: int) -> void:
	tier = clampi(t, Tier.LOW, Tier.ULTRA)
	var s: Dictionary = (TIER_SETTINGS[tier] as Dictionary).duplicate()
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = s["msaa"]
		var method := RenderingServer.get_current_rendering_method()
		if method != "gl_compatibility":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if s["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.positional_shadow_atlas_size = s["shadow_atlas"]
		vp.mesh_lod_threshold = s["lod_threshold"]
		# FSR1 is Forward+ only; Mobile/Compatibility fall back to bilinear
		var fsr_ok := method == "forward_plus"
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if (s["fsr"] and fsr_ok) else Viewport.SCALING_3D_MODE_BILINEAR
	RenderingServer.directional_shadow_atlas_set_size(s["dir_shadow"], true)
	scale_min = s["scale_min"]
	_apply_profile_targets()
	set_resolution_scale(s["scale"])
	tier_applied.emit(tier, s)

## Applies the environment-level flags of the current tier to `env`.
func apply_to_environment(env: Environment) -> void:
	if env == null:
		return
	var s: Dictionary = TIER_SETTINGS[tier]
	env.ssao_enabled = s["ssao"]
	env.ssil_enabled = s["ssil"]
	env.sdfgi_enabled = s["sdfgi"]
	env.glow_enabled = s["glow"]
	env.volumetric_fog_enabled = s["volumetric_fog"]

func get_settings() -> Dictionary:
	return TIER_SETTINGS[tier]

# ---------------------------------------------------------------- F-4 power

func set_power_profile(p: int) -> void:
	power_profile = clampi(p, 0, 2)
	_apply_profile_targets()
	power_profile_changed.emit(power_profile)

func _apply_profile_targets() -> void:
	var tfps: int = (TIER_SETTINGS[tier] as Dictionary)["target_fps"]
	match power_profile:
		PowerProfile.PERFORMANCE:
			Engine.max_fps = 0
			target_ms = 1000.0 / float(maxi(tfps, 60))
		PowerProfile.BALANCED:
			Engine.max_fps = 60
			target_ms = 1000.0 / float(tfps)
		PowerProfile.SAVER:
			Engine.max_fps = 30
			target_ms = 1000.0 / 30.0

## Reads the OS battery status (Linux/Android sysfs). Returns "plugged", "battery" or "unknown".
func get_power_source() -> String:
	for p in ["/sys/class/power_supply/battery/status", "/sys/class/power_supply/BAT0/status", "/sys/class/power_supply/BAT1/status"]:
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f:
				var st := f.get_as_text().strip_edges().to_lower()
				if st == "charging" or st == "full" or st == "not charging":
					return "plugged"
				if st == "discharging":
					return "battery"
	return "unknown"

## Plugged -> Performance, Battery -> Balanced, unknown -> unchanged.
func auto_power_profile() -> void:
	match get_power_source():
		"plugged":
			set_power_profile(PowerProfile.PERFORMANCE)
		"battery":
			set_power_profile(PowerProfile.BALANCED)

# ---------------------------------------------------------------- F-5 DRS

func set_resolution_scale(s: float) -> void:
	resolution_scale = clampf(s, scale_min, 1.0)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = resolution_scale
	resolution_scale_changed.emit(resolution_scale)

## One DRS step from a frame-time sample. Pure maths; returns the new scale.
## y_hat = EWMA(ms) + k*sigma ; scale' = clamp(scale*sqrt(target/y_hat), s_min, 1)
## hysteresis |delta| > 0.03, max step 0.1 per update.
func drs_step(sample_ms: float) -> float:
	var d := sample_ms - _ewma
	_ewma += drs_alpha * d
	_ewvar = (1.0 - drs_alpha) * (_ewvar + drs_alpha * d * d)
	var y_hat := _ewma + drs_k * sqrt(_ewvar)
	var want := clampf(resolution_scale * sqrt(target_ms / maxf(y_hat, 0.01)), scale_min, 1.0)
	var delta := want - resolution_scale
	if absf(delta) > drs_hysteresis:
		return clampf(resolution_scale + clampf(delta, -drs_max_step, drs_max_step), scale_min, 1.0)
	return resolution_scale

func _frame_ms(delta: float) -> float:
	var vp := get_viewport()
	if vp:
		var rid := vp.get_viewport_rid()
		if not _gpu_measure_on:
			RenderingServer.viewport_set_measure_render_time(rid, true)
			_gpu_measure_on = true
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
		if gpu > 0.0:
			return maxf(gpu, RenderingServer.viewport_get_measured_render_time_cpu(rid))
	return delta * 1000.0

func _process(delta: float) -> void:
	if benchmarking:
		return
	var ms := _frame_ms(delta)
	if drs_enabled and DisplayServer.get_name() != "headless":
		var ns := drs_step(ms)
		if not is_equal_approx(ns, resolution_scale):
			set_resolution_scale(ns)
	if thermal_enabled:
		_thermal_update(delta, ms)

# ---------------------------------------------------------------- F-3 thermal

func _find_temperature_path() -> String:
	for p in ["/sys/class/power_supply/battery/temp", "/sys/class/power_supply/BAT0/temp", "/sys/class/thermal/thermal_zone0/temp"]:
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f and f.get_as_text().strip_edges().is_valid_int():
				return p
	return ""

## Battery temperature in Celsius, or -1 when unreadable (Android 10+ may deny sysfs).
func read_temperature_c() -> float:
	if _temp_path.is_empty():
		return -1.0
	var f := FileAccess.open(_temp_path, FileAccess.READ)
	if f == null:
		return -1.0
	var raw := f.get_as_text().strip_edges().to_float()
	# battery/temp is deci-degrees, thermal_zone is milli-degrees
	if raw > 1000.0:
		return raw / 1000.0
	if raw > 150.0:
		return raw / 10.0
	return raw

## Slope (ms per sample) of the frame-time trend window; >0 means slowing down.
static func trend_slope(samples: PackedFloat32Array) -> float:
	var n := samples.size()
	if n < 4:
		return 0.0
	var sx := 0.0
	var sy := 0.0
	var sxy := 0.0
	var sxx := 0.0
	for i in n:
		var x := float(i)
		sx += x
		sy += samples[i]
		sxy += x * samples[i]
		sxx += x * x
	var den := float(n) * sxx - sx * sx
	if absf(den) < 1e-6:
		return 0.0
	return (float(n) * sxy - sx * sy) / den

func _thermal_update(delta: float, ms: float) -> void:
	_trend_timer += delta
	if resolution_scale <= scale_min + 0.001:
		_min_scale_time += delta
	else:
		_min_scale_time = 0.0
	if _trend_timer >= 1.0:
		_trend_timer = 0.0
		_trend.append(ms)
		if _trend.size() > 30:
			_trend.remove_at(0)
	_thermal_timer += delta
	if _thermal_timer < 2.0:
		return
	_thermal_timer = 0.0
	last_temperature_c = read_temperature_c()
	var hot := false
	var cool := false
	var reason := ""
	if last_temperature_c > 0.0:
		hot = last_temperature_c >= 42.0
		cool = last_temperature_c <= 38.0
		reason = "battery %.1f C" % last_temperature_c
	else:
		var slope := trend_slope(_trend)
		var mean := 0.0
		for v in _trend:
			mean += v
		mean /= maxf(1.0, float(_trend.size()))
		# sustained slowdown while DRS is already pinned at its minimum
		hot = _trend.size() >= 20 and slope > 0.05 and mean > target_ms * 1.15 and _min_scale_time > 10.0
		cool = mean < target_ms * 0.9
		reason = "frame-time trend %.3f ms/s" % slope
	set_thermal_stage(thermal_stage + (1 if hot else (-1 if cool else 0)), reason)

## Escalation order from the blueprint: DRS first, then effects, then sim LOD.
func set_thermal_stage(stage: int, reason: String = "") -> void:
	stage = clampi(stage, 0, 3)
	if stage == thermal_stage:
		return
	thermal_stage = stage
	match stage:
		0:
			_apply_tier_internal(_base_tier)
		1:
			_apply_tier_internal(_base_tier)
			set_resolution_scale(scale_min)
		2, 3:
			_apply_tier_internal(maxi(_base_tier - 1, Tier.LOW))
			set_resolution_scale(scale_min)
	thermal_stage_changed.emit(stage, reason)

# ---------------------------------------------------------------- cache

func _load_cache() -> bool:
	var cf := ConfigFile.new()
	if cf.load(CACHE_PATH) != OK:
		return false
	if int(cf.get_value("bench", "version", 0)) != BENCH_VERSION:
		return false
	if str(cf.get_value("bench", "device", "")) != device_key:
		return false
	tier = int(cf.get_value("bench", "tier", Tier.MID))
	_base_tier = tier
	score = float(cf.get_value("bench", "score", 0.0))
	power_profile = int(cf.get_value("bench", "power_profile", PowerProfile.BALANCED))
	return true

func _save_cache(cpu: float, gpu: float) -> void:
	var cf := ConfigFile.new()
	cf.set_value("bench", "version", BENCH_VERSION)
	cf.set_value("bench", "device", device_key)
	cf.set_value("bench", "tier", tier)
	cf.set_value("bench", "score", score)
	cf.set_value("bench", "cpu_mops", cpu)
	cf.set_value("bench", "gpu_fps", gpu)
	cf.set_value("bench", "power_profile", power_profile)
	cf.save(CACHE_PATH)

func clear_cache() -> void:
	if FileAccess.file_exists(CACHE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CACHE_PATH))

func status_text() -> String:
	return "Tier %s  score %.0f  profile %s  scale %.2f  thermal %d%s" % [TIER_NAMES[tier], score, PROFILE_NAMES[power_profile], resolution_scale, thermal_stage, (" (benchmarking)" if benchmarking else "")]
