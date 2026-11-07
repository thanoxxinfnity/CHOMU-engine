extends RefCounted
class_name ChomuAntiCheatValidationChecks

## Anti-Cheat Validation Checks — server-side movement & speed hack detection.
##
## Standard shipped-game design: per-peer sliding-window movement validator.
## Each peer reports position updates (tick, position). The validator keeps a
## bounded history per peer and rejects updates that violate:
##   * maximum speed (distance / delta-time)
##   * maximum acceleration (delta-speed / delta-time)
##   * maximum teleport distance (single jump)
##   * tick monotonicity / staleness (ticks must advance, not go backwards)
##
## Deterministic: uses a seeded RandomNumberGenerator only for optional jitter
## tolerance (disabled by default). No rendering dependence. State is saved /
## loaded as a Dictionary.

## Configuration for a single peer's movement limits.
class MovementConfig:
	var max_speed: float = 10.0            # units per second
	var max_acceleration: float = 50.0     # units per second^2
	var max_teleport_distance: float = 5.0 # single-frame jump allowance
	var max_tick_delta: int = 5            # max ticks between updates
	var min_tick_delta: int = 1            # min ticks between updates
	var speed_tolerance: float = 0.1       # extra allowance (float error)
	var enabled: bool = true

## One validated movement sample.
class MovementSample:
	var tick: int = 0
	var position: Vector3 = Vector3.ZERO
	var timestamp_ms: int = 0

## Validation result for a submitted update.
class ValidationResult:
	var valid: bool = false
	var reason: String = ""
	var corrected_position: Vector3 = Vector3.ZERO
	var penalty_points: float = 0.0

## Per-peer sliding window of recent movement samples.
class PeerTracker:
	var peer_id: int = 0
	var config: MovementConfig = MovementConfig.new()
	var samples: Array[MovementSample] = []
	var last_tick: int = -1
	var last_position: Vector3 = Vector3.ZERO
	var last_velocity: Vector3 = Vector3.ZERO
	var penalty_points: float = 0.0
	var violations: int = 0
	var last_result: ValidationResult = ValidationResult.new()

	## Push a sample and trim to max_history.
	func push(sample: MovementSample, max_history: int = 64) -> void:
		samples.append(sample)
		while samples.size() > max_history:
			samples.pop_front()

	## Compute average speed over the window (units/sec).
	func average_speed() -> float:
		if samples.size() < 2:
			return 0.0
		var first: MovementSample = samples[0]
		var last: MovementSample = samples[samples.size() - 1]
		var dt_s: float = (last.timestamp_ms - first.timestamp_ms) / 1000.0
		if dt_s <= 0.0:
			return 0.0
		return last.position.distance_to(first.position) / dt_s

	## Internal per-peer validation logic.
	func _validate(tick: int, position: Vector3, timestamp_ms: int) -> ValidationResult:
		var result: ValidationResult = ValidationResult.new()
		result.valid = true
		result.corrected_position = position

		if not config.enabled:
			return result

		# Tick monotonicity.
		if last_tick >= 0:
			var tick_delta: int = tick - last_tick
			if tick_delta < config.min_tick_delta:
				result.valid = false
				result.reason = "tick_delta_too_small"
				result.penalty_points = 2.0
				return result
			if tick_delta > config.max_tick_delta:
				result.valid = false
				result.reason = "tick_delta_too_large"
				result.penalty_points = 3.0
				return result

		# Teleport check (instantaneous jump).
		var jump_distance: float = last_position.distance_to(position)
		if jump_distance > config.max_teleport_distance + config.speed_tolerance:
			result.valid = false
			result.reason = "teleport_detected"
			result.penalty_points = 5.0
			# Snap back to last known good position.
			result.corrected_position = last_position
			return result

		# Speed check over the window.
		var dt_s: float = (timestamp_ms - samples[samples.size()-1].timestamp_ms) / 1000.0 if samples.size() > 0 else 0.0
		if dt_s > 0.0:
			var velocity: Vector3 = (position - last_position) / dt_s
			var speed: float = velocity.length()
			if speed > config.max_speed + config.speed_tolerance:
				result.valid = false
				result.reason = "speed_hack"
				result.penalty_points = 4.0
				# Clamp to max speed along the same direction.
				var direction: Vector3 = velocity.normalized()
				result.corrected_position = last_position + direction * config.max_speed * dt_s
				return result

			# Acceleration check.
			var accel_delta: Vector3 = velocity - last_velocity
			var accel: float = accel_delta.length() / dt_s if dt_s > 0.0 else 0.0
			if accel > config.max_acceleration + config.speed_tolerance:
				result.valid = false
				result.reason = "acceleration_hack"
				result.penalty_points = 3.0
				# Limit velocity change.
				var max_delta: Vector3 = last_velocity.direction_to(velocity) * min(accel_delta.length(), config.max_acceleration * dt_s)
				var corrected_vel: Vector3 = last_velocity + max_delta
				result.corrected_position = last_position + corrected_vel * dt_s
				return result

		last_velocity = (position - last_position) / dt_s if dt_s > 0.0 else Vector3.ZERO
		return result

## Main validator. One instance per server (or per authority).
var max_history: int = 64
var default_config: MovementConfig = MovementConfig.new()
var trackers: Dictionary = {}  # int -> PeerTracker
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var total_validations: int = 0
var total_rejections: int = 0
var seed: int = 12345

## Initialize with an optional deterministic seed.
func _init(seed_val: int = 12345) -> void:
	seed = seed_val
	rng.seed = seed

## Register a peer with a custom config (or default if omitted).
func register_peer(peer_id: int, config: MovementConfig = null) -> void:
	if config == null:
		config = default_config
	var tracker: PeerTracker = PeerTracker.new()
	tracker.peer_id = peer_id
	tracker.config = config
	trackers[peer_id] = tracker

## Unregister a peer.
func unregister_peer(peer_id: int) -> void:
	trackers.erase(peer_id)

## Set the default config used for new peers.
func set_default_config(config: MovementConfig) -> void:
	default_config = config

## Validate a movement update from a peer.
## Returns a ValidationResult. If invalid, the peer should be penalized / kicked.
func validate(peer_id: int, tick: int, position: Vector3, timestamp_ms: int = -1) -> ValidationResult:
	total_validations += 1
	var tracker: PeerTracker = trackers.get(peer_id, null)
	if tracker == null:
		var result: ValidationResult = ValidationResult.new()
		result.valid = false
		result.reason = "peer_not_registered"
		result.penalty_points = 10.0
		total_rejections += 1
		return result

	if timestamp_ms < 0:
		timestamp_ms = Time.get_ticks_msec()

	var result: ValidationResult = tracker._validate(tick, position, timestamp_ms)
	tracker.last_result = result
	if not result.valid:
		total_rejections += 1
		tracker.violations += 1
		tracker.penalty_points += result.penalty_points
	else:
		# Decay penalty when clean.
		tracker.penalty_points = max(0.0, tracker.penalty_points - 0.1)
		tracker.last_tick = tick
		tracker.last_position = position
		var sample: MovementSample = MovementSample.new()
		sample.tick = tick
		sample.position = position
		sample.timestamp_ms = timestamp_ms
		tracker.push(sample)

	return result

## Get penalty points for a peer (0 if not registered).
func get_penalty_points(peer_id: int) -> float:
	var tracker: PeerTracker = trackers.get(peer_id, null)
	return tracker.penalty_points if tracker != null else 0.0

## Get violation count for a peer.
func get_violations(peer_id: int) -> int:
	var tracker: PeerTracker = trackers.get(peer_id, null)
	return tracker.violations if tracker != null else 0

## Save all state to a Dictionary.
func save_state() -> Dictionary:
	var state: Dictionary = {
		"seed": seed,
		"max_history": max_history,
		"default_config": _config_to_dict(default_config),
		"trackers": {},
		"total_validations": total_validations,
		"total_rejections": total_rejections,
	}
	for peer_id in trackers.keys():
		var tracker: PeerTracker = trackers[peer_id]
		var t_dict: Dictionary = {
			"peer_id": tracker.peer_id,
			"config": _config_to_dict(tracker.config),
			"last_tick": tracker.last_tick,
			"last_position": [tracker.last_position.x, tracker.last_position.y, tracker.last_position.z],
			"last_velocity": [tracker.last_velocity.x, tracker.last_velocity.y, tracker.last_velocity.z],
			"penalty_points": tracker.penalty_points,
			"violations": tracker.violations,
			"samples": [],
		}
		for sample in tracker.samples:
			t_dict["samples"].append({
				"tick": sample.tick,
				"position": [sample.position.x, sample.position.y, sample.position.z],
				"timestamp_ms": sample.timestamp_ms,
			})
		state["trackers"][str(peer_id)] = t_dict
	return state

## Load state from a Dictionary.
func load_state(state: Dictionary) -> void:
	seed = state.get("seed", 12345)
	rng.seed = seed
	max_history = state.get("max_history", 64)
	total_validations = state.get("total_validations", 0)
	total_rejections = state.get("total_rejections", 0)
	trackers = {}
	if state.has("default_config"):
		default_config = _dict_to_config(state["default_config"])
	for key in state.get("trackers", {}).keys():
		var t_dict: Dictionary = state["trackers"][key]
		var peer_id: int = int(key)
		var tracker: PeerTracker = PeerTracker.new()
		tracker.peer_id = peer_id
		tracker.config = _dict_to_config(t_dict.get("config", {}))
		tracker.last_tick = t_dict.get("last_tick", -1)
		var pos_arr: Array = t_dict.get("last_position", [0, 0, 0])
		tracker.last_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		var vel_arr: Array = t_dict.get("last_velocity", [0, 0, 0])
		tracker.last_velocity = Vector3(vel_arr[0], vel_arr[1], vel_arr[2])
		tracker.penalty_points = t_dict.get("penalty_points", 0.0)
		tracker.violations = t_dict.get("violations", 0)
		tracker.samples = []
		for s_dict in t_dict.get("samples", []):
			var s_arr: Array = s_dict.get("position", [0, 0, 0])
			var sample: MovementSample = MovementSample.new()
			sample.tick = s_dict.get("tick", 0)
			sample.position = Vector3(s_arr[0], s_arr[1], s_arr[2])
			sample.timestamp_ms = s_dict.get("timestamp_ms", 0)
			tracker.samples.append(sample)
		trackers[peer_id] = tracker

## Helper: config -> dict.
func _config_to_dict(config: MovementConfig) -> Dictionary:
	return {
		"max_speed": config.max_speed,
		"max_acceleration": config.max_acceleration,
		"max_teleport_distance": config.max_teleport_distance,
		"max_tick_delta": config.max_tick_delta,
		"min_tick_delta": config.min_tick_delta,
		"speed_tolerance": config.speed_tolerance,
		"enabled": config.enabled,
	}

## Helper: dict -> config.
func _dict_to_config(d: Dictionary) -> MovementConfig:
	var c: MovementConfig = MovementConfig.new()
	c.max_speed = d.get("max_speed", 10.0)
	c.max_acceleration = d.get("max_acceleration", 50.0)
	c.max_teleport_distance = d.get("max_teleport_distance", 5.0)
	c.max_tick_delta = d.get("max_tick_delta", 5)
	c.min_tick_delta = d.get("min_tick_delta", 1)
	c.speed_tolerance = d.get("speed_tolerance", 0.1)
	c.enabled = d.get("enabled", true)
	return c
