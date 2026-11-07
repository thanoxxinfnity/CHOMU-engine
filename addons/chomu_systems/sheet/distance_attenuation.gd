extends RefCounted
class_name ChomuDistanceAttenuation

## Distance attenuation system for gameplay, AI, and audio.
## Implements standard game-dev attenuation models: Linear, Inverse, and Logarithmic.
## Designed for mobile-first performance (low allocation, simple math).

enum Model {
	LINEAR,    ## Constant drop-off: 1.0 at min, 0.0 at max.
	INVERSE,   ## Physical-like: 1 / (1 + distance).
	LOGARITHMIC ## Rapid initial drop, slow tail.
}

## Configuration for a specific attenuation source.
class AttenuationConfig:
	var model: int = Model.LINEAR
	var min_distance: float = 1.0
	var max_distance: float = 20.0
	var rolloff_factor: float = 1.0 # Used primarily for Inverse/Log
	
	func _init(_model: int = Model.LINEAR, _min: float = 1.0, _max: float = 20.0, _rolloff: float = 1.0):
		model = _model
		min_distance = _min
		max_distance = _max
		rolloff_factor = _rolloff

## Calculates the attenuation factor (0.0 to 1.0) based on distance.
## [br]
## [b]Linear[/b]: (max - dist) / (max - min)
## [b]Inverse[/b]: min / (min + rolloff * (dist - min))
## [b]Logarithmic[/b]: 1.0 - rolloff * log(dist / min) / log(max / min)
static func calculate(dist: float, config: AttenuationConfig) -> float:
	if dist <= config.min_distance:
		return 1.0
	if dist >= config.max_distance:
		return 0.0
	
	match config.model:
		Model.LINEAR:
			return (config.max_distance - dist) / (config.max_distance - config.min_distance)
		
		Model.INVERSE:
			# Standard inverse distance clamped model
			var factor: float = config.min_distance / (config.min_distance + config.rolloff_factor * (dist - config.min_distance))
			return clampf(factor, 0.0, 1.0)
			
		Model.LOGARITHMIC:
			# Logarithmic attenuation: 1.0 at min, drops based on rolloff
			# We normalize it so it hits 0.0 at max_distance for consistency
			# In GDScript, log() is the natural logarithm (ln)
			var log_val: float = log(dist / config.min_distance) / log(config.max_distance / config.min_distance)
			return clampf(1.0 - log_val * config.rolloff_factor, 0.0, 1.0)
			
		_:
			return 0.0

## Serializes the config to a dictionary for save/load.
static func save_config(config: AttenuationConfig) -> Dictionary:
	return {
		"model": config.model,
		"min_distance": config.min_distance,
		"max_distance": config.max_distance,
		"rolloff_factor": config.rolloff_factor
	}

## Creates a config from a dictionary.
static func load_config(data: Dictionary) -> AttenuationConfig:
	return AttenuationConfig.new(
		data.get("model", Model.LINEAR),
		data.get("min_distance", 1.0),
		data.get("max_distance", 20.0),
		data.get("rolloff_factor", 1.0)
	)
