extends RefCounted

const Impl := preload("res://addons/chomu_systems/atmosphere/proc_audio.gd")

func run(t: Node) -> void:
	var audio := Impl.new()
	t.add_child(audio)
	
	# Test 1: Output range
	audio.set_tension(0.5)
	var buf = audio.render(1024)
	var in_range := true
	for s in buf:
		if abs(s.x) > 1.1 or abs(s.y) > 1.1:
			in_range = false
			break
	t.check("F-45 output range", in_range, "Audio samples should be roughly within [-1, 1]")
	
	# Test 2: Heartbeat frequency vs Tension
	# We render 4 seconds of audio at different tensions and count peaks
	var count_low := _count_peaks(audio, 0.1, 4.0)
	var count_high := _count_peaks(audio, 0.9, 4.0)
	t.check("F-45 heartbeat tension", count_high > count_low, "Higher tension should increase heartbeat BPM")
	
	# Test 3: Granular RMS vs Tension
	# We isolate granular by using a custom node or just checking overall energy 
	# since heartbeat is periodic and granular is noise.
	var rms_low := _calculate_rms(audio, 0.0, 1.0)
	var rms_high := _calculate_rms(audio, 1.0, 1.0)
	t.check("F-45 granular energy", rms_high > rms_low, "Higher tension should increase noise density/RMS")
	
	# Test 4: Filter Sweep
	# Low tension = low pass = fewer high frequency changes (smaller abs diffs)
	var diff_low := _calculate_abs_diff(audio, 0.0, 1.0)
	var diff_high := _calculate_abs_diff(audio, 1.0, 1.0)
	t.check("F-45 filter sweep", diff_high > diff_low, "Higher tension should allow more high-frequency energy")
	
	audio.queue_free()

func _count_peaks(audio: Node, tension: float, seconds: float) -> int:
	audio.set_tension(tension)
	var frames := int(audio.sample_rate * seconds)
	var buf = audio.render(frames)
	var peaks := 0
	var is_peak := false
	for i in range(1, buf.size()):
		var val := abs(buf[i].x)
		if val > 0.1 and not is_peak:
			peaks += 1
			is_peak = true
		elif val < 0.05:
			is_peak = false
	return peaks

func _calculate_rms(audio: Node, tension: float, seconds: float) -> float:
	audio.set_tension(tension)
	var frames := int(audio.sample_rate * seconds)
	var buf = audio.render(frames)
	var sum_sq := 0.0
	for s in buf:
		sum_sq += s.x * s.x
	return sqrt(sum_sq / frames)

func _calculate_abs_diff(audio: Node, tension: float, seconds: float) -> float:
	audio.set_tension(tension)
	var frames := int(audio.sample_rate * seconds)
	var buf = audio.render(frames)
	var diff := 0.0
	for i in range(1, buf.size()):
		diff += abs(buf[i].x - buf[i-1].x)
	return diff
