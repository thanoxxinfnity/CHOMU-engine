class_name ChomuFlickerCircuit
extends Node
## F-42 Flicker circuit. One seed drives both the light flicker and the
## electrical buzz, so the hum drops out exactly when the bulb dips.
## Put it under (or point it at) a Light3D. A procedural buzz plays through an
## AudioStreamPlayer3D it creates (AudioStreamGenerator), or through `audio_player`.

signal flickered(level: float)

@export var light: Light3D
@export var audio_player: AudioStreamPlayer3D
@export var seed := 1337
@export var enabled := true
@export_range(0.0, 1.0) var depth := 0.85     ## how dark a dip goes
@export var rate_hz := 9.0                    ## event rate
@export_range(0.0, 1.0) var chaos := 0.5      ## probability a tick becomes a dip
@export var buzz_hz := 100.0                  ## mains hum (2x 50 Hz)
@export var buzz_volume_db := -14.0
@export var make_audio := true

var level := 1.0      ## current shared circuit level 0..1
var base_energy := 1.0
var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _target := 1.0
var _gen_playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _mix_rate := 22050.0
var _flash_times: Array[float] = []
var _clock := 0.0

func _ready() -> void:
	if light == null and get_parent() is Light3D:
		light = get_parent() as Light3D
	if light:
		base_energy = light.light_energy
	reseed(seed)
	if make_audio and audio_player == null and light:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "Buzz"
		light.add_child.call_deferred(audio_player)
		_setup_audio.call_deferred()
	elif audio_player:
		_setup_audio.call_deferred()

func _exit_tree() -> void:
	# drop the generator playback so it is not leaked at quit
	_gen_playback = null
	if audio_player and is_instance_valid(audio_player):
		audio_player.stop()

func reseed(s: int) -> void:
	seed = s
	_rng.seed = s
	_timer = 0.0
	_target = 1.0
	level = 1.0
	_flash_times.clear()

func _setup_audio() -> void:
	if audio_player == null:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _mix_rate
	gen.buffer_length = 0.15
	audio_player.stream = gen
	audio_player.volume_db = buzz_volume_db
	audio_player.unit_size = 4.0
	audio_player.play()
	_gen_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

## Effective event rate and depth after the photosensitivity-safe clamp.
func effective_rate() -> float:
	return minf(rate_hz, ChomuSettings.SAFE_MAX_FLASH_HZ) if ChomuSettings.photosensitivity_safe else rate_hz

func effective_depth() -> float:
	return minf(depth, 0.35) * ChomuSettings.effects_intensity if ChomuSettings.photosensitivity_safe else depth * ChomuSettings.effects_intensity

func _process(delta: float) -> void:
	step(delta)
	_push_audio()

## Deterministic for a given seed and delta sequence.
func step(delta: float) -> float:
	_clock += delta
	if not enabled:
		level = move_toward(level, 1.0, delta * 8.0)
	else:
		_timer -= delta
		if _timer <= 0.0:
			_timer = 1.0 / maxf(effective_rate(), 0.1) * _rng.randf_range(0.5, 1.5)
			if ChomuSettings.photosensitivity_safe:
				_timer = maxf(_timer, 1.0 / ChomuSettings.SAFE_MAX_FLASH_HZ + 0.02)
			if _rng.randf() < chaos:
				_target = 1.0 - effective_depth() * _rng.randf_range(0.5, 1.0)
				_flash_times.append(_clock)
			else:
				_target = 1.0 - effective_depth() * 0.08 * _rng.randf()
		# safe mode also slows the edge so dips fade instead of snapping
		var speed := 6.0 if ChomuSettings.photosensitivity_safe else 40.0
		level = move_toward(level, _target, delta * speed)
		if absf(level - _target) < 0.02 and _target < 0.9:
			_target = 1.0
	while not _flash_times.is_empty() and _clock - _flash_times[0] > 1.0:
		_flash_times.remove_at(0)
	if light:
		light.light_energy = base_energy * level
	flickered.emit(level)
	return level

## Dips counted in the last second (used by the safety self-test).
func flashes_last_second() -> int:
	return _flash_times.size()

func _push_audio() -> void:
	if _gen_playback == null:
		return
	var n := _gen_playback.get_frames_available()
	if n <= 0:
		return
	var amp := 0.25 * clampf((level - 0.3) / 0.7, 0.0, 1.0) # buzz cuts out when the bulb dips
	var inc := buzz_hz / _mix_rate
	for i in n:
		# hum + odd harmonic + a little crackle from the same RNG stream
		var s := sin(_phase * TAU) * 0.7 + sin(_phase * TAU * 3.0) * 0.2
		if level < 0.95:
			s += (_rng.randf() - 0.5) * 0.3
		_phase = fmod(_phase + inc, 1.0)
		var v := s * amp
		_gen_playback.push_frame(Vector2(v, v))
