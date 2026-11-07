extends RefCounted
class_name ChomuMemorySuspicionStateTracker

## S-09 Memory & Suspicion State Tracker
## Implements a standard game-AI system for tracking a target's last known position (LKP)
## and a suspicion meter that drives AI states (Idle -> Suspicious -> Alert).
## Designed for low RAM and deterministic updates.

class MemoryState:
	## Data container for a specific tracked entity
	var last_known_position: Vector3 = Vector3.ZERO
	var last_seen_time: float = 0.0
	var suspicion_level: float = 0.0 # 0.0 to 1.0
	var is_tracked: bool = false
	var investigation_target: Vector3 = Vector3.ZERO
	var is_investigating: bool = false

class TrackerConfig:
	var suspicion_gain_rate: float = 0.5 # Per second when seeing target
	var suspicion_decay_rate: float = 0.1 # Per second when target is lost
	var alert_threshold: float = 0.7 # Level at which AI becomes 'Alert'
	var suspicion_threshold: float = 0.2 # Level at which AI becomes 'Suspicious'
	var memory_lifetime: float = 10.0 # Seconds before LKP is forgotten
	var investigation_radius: float = 2.0 # Distance to target to stop investigating

var _config: TrackerConfig
var _memories: Dictionary = {} # entity_id (Variant) -> MemoryState
var _rng := RandomNumberGenerator.new()

## Initializes the tracker with an optional seed for deterministic behavior.
func _init(seed_val: int = 12345) -> void:
	_rng.seed = seed_val
	_config = TrackerConfig.new()

## Sets the configuration for the tracker.
func set_config(config: TrackerConfig) -> void:
	_config = config

## Updates the state of a tracked entity.
## @param entity_id: Unique identifier for the target.
## @param current_pos: The current position of the target if visible, otherwise null.
## @param delta: Time elapsed since last update.
func update_entity(entity_id: Variant, current_pos: Variant, delta: float) -> void:
	if not _memories.has(entity_id):
		_memories[entity_id] = MemoryState.new()
	
	var mem: MemoryState = _memories[entity_id]
	var now = Time.get_ticks_msec() / 1000.0
	
	if current_pos is Vector3:
		# Target is visible
		mem.is_tracked = true
		mem.last_known_position = current_pos
		mem.last_seen_time = now
		mem.suspicion_level = clampf(mem.suspicion_level + _config.suspicion_gain_rate * delta, 0.0, 1.0)
		mem.is_investigating = false
	else:
		# Target is hidden
		mem.suspicion_level = clampf(mem.suspicion_level - _config.suspicion_decay_rate * delta, 0.0, 1.0)
		
		# If we were just seeing them, start investigating the LKP
		if mem.is_tracked and mem.suspicion_level > _config.suspicion_threshold:
			mem.is_investigating = true
			mem.investigation_target = mem.last_known_position
		
		# Forget target after lifetime expires
		# We check if it was tracked; if it's already untracked, we don't need to do this
		if mem.is_tracked:
			var elapsed = now - mem.last_seen_time
			if elapsed > _config.memory_lifetime:
				mem.is_tracked = false
				mem.is_investigating = false

## Returns the current state of an entity.
func get_entity_state(entity_id: Variant) -> Dictionary:
	if not _memories.has(entity_id):
		return {}
	
	var mem: MemoryState = _memories[entity_id]
	return {
		"lkp": mem.last_known_position,
		"suspicion": mem.suspicion_level,
		"is_tracked": mem.is_tracked,
		"is_investigating": mem.is_investigating,
		"investigation_target": mem.investigation_target,
		"state": _get_state_label(mem.suspicion_level)
	}

## Helper to map suspicion level to a human-readable state.
func _get_state_label(level: float) -> String:
	if level >= _config.alert_threshold:
		return "ALERT"
	if level >= _config.suspicion_threshold:
		return "SUSPICIOUS"
	return "IDLE"

## Returns the state as a dictionary for serialization.
func save_state() -> Dictionary:
	var data: Dictionary = {}
	for id in _memories:
		var mem: MemoryState = _memories[id]
		data[str(id)] = {
			"lkp": mem.last_known_position,
			"last_seen": mem.last_seen_time,
			"suspicion": mem.suspicion_level,
			"tracked": mem.is_tracked,
			"inv_target": mem.investigation_target,
			"inv_active": mem.is_investigating
		}
	return data

## Restores state from a dictionary.
func load_state(data: Dictionary) -> void:
	_memories.clear()
	for id_str in data:
		var d = data[id_str]
		var mem := MemoryState.new()
		mem.last_known_position = d["lkp"]
		mem.last_seen_time = d["last_seen"]
		mem.suspicion_level = d["suspicion"]
		mem.is_tracked = d["tracked"]
		mem.investigation_target = d["inv_target"]
		mem.is_investigating = d["inv_active"]
		_memories[id_str] = mem
