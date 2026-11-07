class_name ChomuAudioPitchVolumeRandomization
extends RefCounted

## Public API:
##   - `new(seed: int = 0) -> ChomuAudioPitchVolumeRandomization`: Creates a new instance with optional RNG seed.
##   - `set_seed(seed: int) -> void`: Sets the RNG seed for deterministic randomization.
##   - `set_pitch_range(min: float, max: float) -> void`: Sets the pitch range for randomization (in semitones).
##   - `set_volume_range(min: float, max: float) -> void`: Sets the volume range for randomization (0.0-1.0).
##   - `randomize_pitch_volume() -> Dictionary`: Returns a dictionary with `pitch` (float) and `volume` (float) values.
##   - `to_dict() -> Dictionary`: Serializes the current state (seed, pitch range, volume range) to a Dictionary.
##   - `from_dict(state: Dictionary) -> void`: Deserializes the state from a Dictionary.

var _rng: RandomNumberGenerator
var _pitch_min: float = 0.0
var _pitch_max: float = 0.0
var _volume_min: float = 0.5
var _volume_max: float = 1.0

func _init(seed: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed
	_pitch_min = 0.0
	_pitch_max = 0.0
	_volume_min = 0.5
	_volume_max = 1.0

func set_seed(seed: int) -> void:
	_rng.seed = seed

func set_pitch_range(min: float, max: float) -> void:
	_pitch_min = min
	_pitch_max = max

func set_volume_range(min: float, max: float) -> void:
	_volume_min = min
	_volume_max = max

func randomize_pitch_volume() -> Dictionary:
	var pitch: float = _pitch_min + (_pitch_max - _pitch_min) * _rng.randf()
	var volume: float = _volume_min + (_volume_max - _volume_min) * _rng.randf()
	return {
		"pitch": pitch,
		"volume": volume
	}

func to_dict() -> Dictionary:
	return {
		"seed": _rng.seed,
		"pitch_min": _pitch_min,
		"pitch_max": _pitch_max,
		"volume_min": _volume_min,
		"volume_max": _volume_max
	}

func from_dict(state: Dictionary) -> void:
	if state.has("seed"):
		_rng.seed = state["seed"]
	if state.has("pitch_min"):
		_pitch_min = state["pitch_min"]
		_pitch_max = state["pitch_max"]
	if state.has("volume_min"):
		_volume_min = state["volume_min"]
		_volume_max = state["volume_max"]
