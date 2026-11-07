class_name ChomuAudioProfiling
extends RefCounted

## Audio profiling system for tracking per-channel audio metrics (volume, peak, RMS, play count).
## Designed as a data-driven, headless-friendly core for profiling audio usage in-game.
## State is serializable via save_state()/load_state().

## Configuration for a single audio channel profile.
class ChannelProfile:
	var name: String = ""
	var volume: float = 1.0
	var peak: float = 0.0
	var rms: float = 0.0
	var play_count: int = 0
	var total_play_time: float = 0.0
	var last_play_time: float = 0.0
	var is_playing: bool = false

## Result of profiling a single audio block.
class ProfileResult:
	var channel: String = ""
	var peak: float = 0.0
	var rms: float = 0.0
	var frame_count: int = 0
	var timestamp: float = 0.0

## Main audio profiler.
## Tracks per-channel statistics over time and exposes snapshots for debugging/telemetry.
var profiles: Dictionary = {}
var profile_order: Array[String] = []
var sample_rate: float = 44100.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0

## Initialize the profiler.
## @param seed RNG seed for deterministic jitter/noise simulation (default 12345).
## @param sample_rate Audio sample rate in Hz (default 44100.0).
func _init(seed: int = 12345, sample_rate: float = 44100.0) -> void:
	_rng.seed = seed
	sample_rate = sample_rate

## Register a new audio channel to profile.
## @param name Unique channel name.
## @param initial_volume Starting volume (0.0-1.0, default 1.0).
## @return true if registered, false if already exists.
func register_channel(name: String, initial_volume: float = 1.0) -> bool:
	if name in profiles:
		return false
	var p: ChannelProfile = ChannelProfile.new()
	p.name = name
	p.volume = clampf(initial_volume, 0.0, 1.0)
	profiles[name] = p
	profile_order.push_back(name)
	return true

## Remove a channel from profiling.
## @return true if removed.
func unregister_channel(name: String) -> bool:
	if not name in profiles:
		return false
	profiles.erase(name)
	profile_order.erase(name)
	return true

## Set volume for a channel (clamped 0.0-1.0).
func set_channel_volume(name: String, volume: float) -> bool:
	if not name in profiles:
		return false
	var p: ChannelProfile = profiles[name]
	p.volume = clampf(volume, 0.0, 1.0)
	return true

## Get volume for a channel (0.0 if missing).
func get_channel_volume(name: String) -> float:
	if not name in profiles:
		return 0.0
	return profiles[name].volume

## Mark a channel as playing (starts play timer).
func start_playback(name: String) -> bool:
	if not name in profiles:
		return false
	var p: ChannelProfile = profiles[name]
	p.is_playing = true
	p.last_play_time = _time
	p.play_count += 1
	return true

## Mark a channel as stopped (accumulates play time).
func stop_playback(name: String) -> bool:
	if not name in profiles:
		return false
	var p: ChannelProfile = profiles[name]
	if p.is_playing:
		p.total_play_time += _time - p.last_play_time
	p.is_playing = false
	return true

## Feed a block of stereo samples for a channel and update peak/RMS stats.
## Samples are interleaved float32 in [-1, 1].
## @return ProfileResult with computed metrics for this block.
func profile_block(name: String, samples: PackedFloat32Array) -> ProfileResult:
	var result: ProfileResult = ProfileResult.new()
	result.channel = name
	result.timestamp = _time
	if not name in profiles or samples.size() == 0:
		result.frame_count = samples.size()
		return result

	var p: ChannelProfile = profiles[name]
	var sum_squares: float = 0.0
	var peak: float = 0.0
	var frame_count: int = samples.size() / 2
	if frame_count == 0:
		frame_count = samples.size()

	for i in samples.size():
		var s: float = samples[i]
		var abs_s: float = abs(s) * p.volume
		if abs_s > peak:
			peak = abs_s
		sum_squares += s * s

	result.peak = peak
	result.rms = sqrt(sum_squares / float(frame_count)) if frame_count > 0 else 0.0
	result.frame_count = frame_count

	# Update running peak/RMS with simple EMA-like smoothing.
	p.peak = max(p.peak, peak)
	p.rms = p.rms * 0.9 + result.rms * 0.1

	if p.is_playing:
		p.total_play_time += 1.0 / sample_rate

	return result

## Advance internal time (call each frame/physics tick).
## @param delta Seconds to advance.
func advance_time(delta: float) -> void:
	_time += delta

## Get current internal time.
func get_time() -> float:
	return _time

## Get a snapshot dictionary of all channel profiles.
func get_snapshot() -> Dictionary:
	var snap: Dictionary = {}
	for name in profile_order:
		var p: ChannelProfile = profiles[name]
		snap[name] = {
			"volume": p.volume,
			"peak": p.peak,
			"rms": p.rms,
			"play_count": p.play_count,
			"total_play_time": p.total_play_time,
			"is_playing": p.is_playing,
		}
	return snap

## Save full profiler state to a Dictionary (for serialization).
func save_state() -> Dictionary:
	var state: Dictionary = {}
	state["sample_rate"] = sample_rate
	state["time"] = _time
	state["order"] = profile_order.duplicate()
	var prof_data: Array[Dictionary] = []
	for name in profile_order:
		var p: ChannelProfile = profiles[name]
		prof_data.append({
			"name": p.name,
			"volume": p.volume,
			"peak": p.peak,
			"rms": p.rms,
			"play_count": p.play_count,
			"total_play_time": p.total_play_time,
			"last_play_time": p.last_play_time,
			"is_playing": p.is_playing,
		})
	state["profiles"] = prof_data
	return state

## Load profiler state from a Dictionary.
## @return true on success.
func load_state(state: Dictionary) -> void:
	if state.has("sample_rate"):
		sample_rate = float(state["sample_rate"])
	if state.has("time"):
		_time = float(state["time"])
	profiles.clear()
	profile_order.clear()
	if state.has("order"):
		var order_raw: Array = state["order"]
		profile_order = []
		for o in order_raw:
			profile_order.push_back(String(o))
	if state.has("profiles"):
		var prof_raw: Array = state["profiles"]
		for entry in prof_raw:
			var p: ChannelProfile = ChannelProfile.new()
			p.name = String(entry["name"])
			p.volume = float(entry["volume"])
			p.peak = float(entry["peak"])
			p.rms = float(entry["rms"])
			p.play_count = int(entry["play_count"])
			p.total_play_time = float(entry["total_play_time"])
			p.last_play_time = float(entry["last_play_time"])
			p.is_playing = bool(entry["is_playing"])
			profiles[p.name] = p

## Get list of registered channel names.
func get_channels() -> Array[String]:
	return profile_order.duplicate()
