extends RefCounted
class_name ChomuMacroRecorderPlaybackUtility

## Macro Recorder & Playback Utility (S-21)
## Provides a deterministic system for recording input streams (events) and playing them back.
## Designed for automated QA testing and accessibility input mapping.
## 
## Data Layout:
## - Events are stored as a sequence of [timestamp, event_id, value/data].
## - Playback is driven by a virtual clock to ensure determinism regardless of frame rate.

class MacroEvent:
	var timestamp: float = 0.0
	var event_id: String = ""
	var data: Variant = null

	func _init(_ts: float = 0.0, _id: String = "", _data: Variant = null):
		timestamp = _ts
		event_id = _id
		data = _data

	func to_dict() -> Dictionary:
		return {"ts": timestamp, "id": event_id, "data": data}

	static func from_dict(d: Dictionary) -> MacroEvent:
		return MacroEvent.new(d.get("ts", 0.0), d.get("id", ""), d.get("data"))

var _is_recording: bool = false
var _is_playing: bool = false
var _recording_start_time: float = 0.0
var _playback_start_time: float = 0.0
var _playback_index: int = 0

var _events: Array[MacroEvent] = []
var _playback_speed: float = 1.0

## Signal emitted when a recorded event is played back.
signal event_played(event_id: String, data: Variant)

## Starts recording input events.
func start_recording() -> void:
	_events.clear()
	_is_recording = true
	_recording_start_time = Time.get_ticks_msec() / 1000.0

## Stops recording input events.
func stop_recording() -> void:
	_is_recording = false

## Records an event into the current session.
func record_event(event_id: String, data: Variant = null) -> void:
	if not _is_recording:
		return
	
	var now = (Time.get_ticks_msec() / 1000.0) - _recording_start_time
	_events.append(MacroEvent.new(now, event_id, data))

## Starts playback of the recorded events.
func start_playback(speed: float = 1.0) -> void:
	if _events.is_empty():
		return
	
	_playback_speed = speed
	_playback_index = 0
	_playback_start_time = Time.get_ticks_msec() / 1000.0
	_is_playing = true

## Stops playback.
func stop_playback() -> void:
	_is_playing = false
	_playback_index = 0

## Updates the playback state. Should be called every frame/physics tick.
## Returns an Array of events that triggered this frame.
func update() -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []
	if not _is_playing:
		return triggered

	var current_time = ((Time.get_ticks_msec() / 1000.0) - _playback_start_time) * _playback_speed
	
	while _playback_index < _events.size():
		var ev = _events[_playback_index]
		if current_time >= ev.timestamp:
			event_played.emit(ev.event_id, ev.data)
			triggered.append({"id": ev.event_id, "data": ev.data})
			_playback_index += 1
		else:
			break
	
	if _playback_index >= _events.size():
		_is_playing = false
	
	return triggered

## Serializes the current recorded macro to a Dictionary.
func save_state() -> Dictionary:
	var serialized_events: Array[Dictionary] = []
	for ev in _events:
		serialized_events.append(ev.to_dict())
	
	return {
		"events": serialized_events,
		"playback_speed": _playback_speed
	}

## Loads a macro from a Dictionary.
func load_state(data: Dictionary) -> void:
	_events.clear()
	var ev_data = data.get("events", [])
	for d in ev_data:
		_events.append(MacroEvent.from_dict(d))
	_playback_speed = data.get("playback_speed", 1.0)

## Returns the number of recorded events.
func get_event_count() -> int:
	return _events.size()

## Checks if the system is currently recording.
func is_recording() -> bool:
	return _is_recording

## Checks if the system is currently playing back.
func is_playing() -> bool:
	return _is_playing
