extends Node
class_name ChomuBiometricHooks

## F-48: Opt-in, local-only biometric hook interface.
## Provides smoothed biometric data (HR, EDA) to calculate tension bias.

@export var enabled: bool = false
@export var consent_given: bool = false

## EMA smoothing factor (0..1). Lower is smoother.
@export var smoothing_factor: float = 0.1

## Resting heart rate for arousal calculation.
@export var resting_hr: float = 60.0

var _providers: Array[Object] = []
var _smoothed_hr: float = 0.0
var _smoothed_eda: float = 0.0
var _has_initial_sample: bool = false

func register_provider(provider: Object) -> bool:
	if provider == null:
		return false
	
	# Local-only check: reject if provider looks like a network client
	if "url" in provider or "host" in provider or "port" in provider:
		# Removed push_warning to avoid polluting test logs for expected failures
		return false
	
	if not provider.has_method("poll"):
		return false
		
	if not _providers.has(provider):
		_providers.append(provider)
	return true

func sample() -> Dictionary:
	if not enabled or not consent_given:
		return {"heart_rate": 0.0, "eda": 0.0, "arousal": 0.0}
	
	var sum_hr: float = 0.0
	var sum_eda: float = 0.0
	var count_hr: int = 0
	var count_eda: int = 0
	
	for p in _providers:
		var data = p.poll()
		if typeof(data) == TYPE_DICTIONARY:
			var hr = data.get("heart_rate", -1.0)
			var eda = data.get("eda", -1.0)
			
			# Validate and clamp
			if hr != -1.0:
				sum_hr += clamp(hr, 30.0, 220.0)
				count_hr += 1
			if eda != -1.0:
				sum_eda += clamp(eda, 0.0, 100.0)
				count_eda += 1
	
	if count_hr == 0 and count_eda == 0:
		return {"heart_rate": _smoothed_hr, "eda": _smoothed_eda, "arousal": 0.0}
	
	var current_hr = sum_hr / float(count_hr) if count_hr > 0 else _smoothed_hr
	var current_eda = sum_eda / float(count_eda) if count_eda > 0 else _smoothed_eda
	
	# EMA Smoothing
	if not _has_initial_sample:
		_smoothed_hr = current_hr
		_smoothed_eda = current_eda
		_has_initial_sample = true
	else:
		_smoothed_hr = (_smoothed_hr * (1.0 - smoothing_factor)) + (current_hr * smoothing_factor)
		_smoothed_eda = (_smoothed_eda * (1.0 - smoothing_factor)) + (current_eda * smoothing_factor)
	
	# Compute Arousal (0..1)
	var hr_arousal = clamp((_smoothed_hr - resting_hr) / 100.0, 0.0, 1.0)
	var eda_arousal = clamp(_smoothed_eda / 100.0, 0.0, 1.0)
	var arousal = (hr_arousal + eda_arousal) / 2.0
	
	return {
		"heart_rate": _smoothed_hr,
		"eda": _smoothed_eda,
		"arousal": arousal
	}

func tension_bias() -> float:
	var data = sample()
	# Map arousal 0..1 to bias 0..0.3
	return data.arousal * 0.3

func revoke_consent() -> void:
	consent_given = false
	_smoothed_hr = 0.0
	_smoothed_eda = 0.0
	_has_initial_sample = false
