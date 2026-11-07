@tool
extends RefCounted
## CHoMU Ultra device tier detection (heuristic).
## Reads OS, GPU name, RAM and the running renderer and maps them to a tier:
##   0 = Low, 1 = Medium, 2 = Mobile Ultra, 3 = PC Cinematic.
## It is a starting guess only. The adaptive governor (governor.gd) then watches real frame times and steps
## resolution / preset down when the phone can't hold the target fps. Tune the GPU tables for your devices.

const PRESET_BY_TIER: Array[String] = ["Low", "Medium", "Mobile Ultra", "PC Cinematic"]

static func detect() -> Dictionary:
	var mem: Dictionary = OS.get_memory_info()
	var ram_bytes := int(mem.get("physical", -1))
	var ram_gb := float(ram_bytes) / 1073741824.0 if ram_bytes > 0 else -1.0
	var d := tier_from(OS.get_name(), RenderingServer.get_video_adapter_name(), ram_gb,
		RenderingServer.get_current_rendering_method(), OS.get_processor_count())
	d["vendor"] = RenderingServer.get_video_adapter_vendor()
	d["model"] = OS.get_model_name()
	return d

## Pure function (testable without a device).
static func tier_from(os_name: String, gpu: String, ram_gb: float, renderer: String, cores := 8) -> Dictionary:
	var mobile := os_name in ["Android", "iOS"]
	var g := gpu.to_lower()
	var tier := 1
	var why := ""
	if mobile:
		tier = _mobile_gpu_tier(g)
		why = "mobile GPU '%s'" % gpu
		if ram_gb > 0.0 and ram_gb < 3.5:
			tier = mini(tier, 0)
			why += ", RAM %.1f GB < 3.5" % ram_gb
		elif ram_gb > 0.0 and ram_gb < 5.5:
			tier = mini(tier, 1)
			why += ", RAM %.1f GB < 5.5" % ram_gb
		if cores > 0 and cores < 6:
			tier = mini(tier, 0)
			why += ", %d CPU cores" % cores
		tier = mini(tier, 2)  # phones never get Forward+ cinematic automatically
	else:
		tier = _desktop_gpu_tier(g)
		why = "desktop GPU '%s'" % gpu
		if ram_gb > 0.0 and ram_gb < 7.5:
			tier = mini(tier, 2)
			why += ", RAM %.1f GB" % ram_gb
	# The running renderer limits what is possible.
	if renderer == "gl_compatibility":
		tier = mini(tier, 1)
		why += ", Compatibility renderer"
	elif renderer == "mobile":
		tier = mini(tier, 2)
		why += ", Mobile renderer"
	elif renderer != "forward_plus":
		why += ", renderer '%s'" % renderer
	return {"tier": tier, "preset": PRESET_BY_TIER[tier], "reason": why, "gpu": gpu, "os": os_name,
		"ram_gb": snappedf(ram_gb, 0.1), "renderer": renderer, "cores": cores}

static func _num(re: String, s: String) -> int:
	var r := RegEx.new()
	r.compile(re)
	var m := r.search(s)
	return int(m.get_string(1)) if m else -1

static func _mobile_gpu_tier(g: String) -> int:
	if g == "":
		return 1
	if "adreno" in g:
		var n := _num("adreno[^0-9]*([0-9]{3})", g)
		if n >= 640:             # 640-660 and all 7xx/8xx (710/720/732/740/750 ...)
			return 2
		if n >= 612:             # 612-630 (618/619 are very common mid-range)
			return 1
		return 0
	if "immortalis" in g or "xclipse" in g or "apple" in g:
		return 2
	if "mali" in g:
		var m := _num("mali-?g([0-9]{2,3})", g)
		if m >= 610:   # G610 / G615 / G710 / G715 / G720 / G925 ...
			return 2
		if m in [57, 68, 76, 77, 78]:
			return 1
		return 0
	if "powervr" in g:
		return 0 if ("ge8" in g or "ge83" in g) else 1
	return 1

static func _desktop_gpu_tier(g: String) -> int:
	if g == "" or "llvmpipe" in g or "swiftshader" in g or "software" in g:
		return 1
	for k in ["rtx", "radeon rx", "rx 6", "rx 7", "rx 9", "arc a", "arc b", "titan", "quadro rtx", "apple m2 max", "apple m3", "apple m4"]:
		if k in g:
			return 3
	for k in ["gtx 16", "gtx 10", "apple m", "radeon 780m", "radeon 890m"]:
		if k in g:
			return 2
	if "intel" in g or "uhd" in g or "iris" in g or "radeon(tm) graphics" in g or "radeon graphics" in g:
		return 1
	return 2
