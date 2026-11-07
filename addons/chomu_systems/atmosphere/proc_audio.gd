extends Node
class_name ChomuProcAudio

## Procedural audio graph driven by tension.
## Generates stereo audio buffers based on a tension value (0.0 to 1.0).

@export var sample_rate: float = 44100.0

var _tension: float = 0.0
var _playback: AudioStreamGeneratorPlayback = null
var _nodes: Array[AudioNode] = []
var _phase_accumulator: float = 0.0

class AudioNode:
	## Base class for procedural audio generators
	func mix(frames: int, rate: float, tension: float) -> PackedVector2Array:
		return PackedVector2Array()

class Heartbeat extends AudioNode:
	var _phase: float = 0.0
	var _beat_timer: float = 0.0
	
	func mix(frames: int, rate: float, tension: float) -> PackedVector2Array:
		var output := PackedVector2Array()
		output.resize(frames)
		
		# BPM: 60 to 150
		var bpm := lerp(60.0, 150.0, tension)
		var beat_duration = 60.0 / bpm
		
		for i in range(frames):
			var t := _beat_timer
			var sample := 0.0
			
			# Lub-dub pattern: two sine bursts per beat
			# Lub: 0.0 to 0.1s, Dub: 0.2 to 0.3s
			if t < 0.1:
				sample = sin(2.0 * PI * 60.0 * t) * exp(-t * 20.0)
			elif t < 0.3:
				var dt := t - 0.2
				sample = sin(2.0 * PI * 40.0 * dt) * exp(-dt * 20.0)
			
			output[i] = Vector2(sample * 0.5, sample * 0.5)
			_beat_timer += 1.0 / rate
			if _beat_timer >= beat_duration:
				_beat_timer -= beat_duration
				
		return output

class Granular extends AudioNode:
	var _phase: float = 0.0
	
	func mix(frames: int, rate: float, tension: float) -> PackedVector2Array:
		var output := PackedVector2Array()
		output.resize(frames)
		
		# Density increases with tension
		var grain_prob := lerp(0.001, 0.05, tension)
		
		for i in range(frames):
			var sample := 0.0
			if randf() < grain_prob:
				# Simple noise grain with windowing
				sample = (randf() * 2.0 - 1.0) * 0.2
			output[i] = Vector2(sample, sample)
			
		return output

class FilterSweep extends AudioNode:
	var _last_l := 0.0
	var _last_r := 0.0
	
	func mix(frames: int, rate: float, tension: float) -> PackedVector2Array:
		# This node is used as a post-process. 
		# In this architecture, we'll apply it to the sum in the main render loop.
		return PackedVector2Array()
	
	func process(input: PackedVector2Array, rate: float, tension: float) -> PackedVector2Array:
		var output := PackedVector2Array()
		output.resize(input.size())
		
		# Cutoff: 200Hz to 5000Hz
		var cutoff := lerp(200.0, 5000.0, tension)
		var alpha = (2.0 * PI * cutoff / rate) / (2.0 * PI * cutoff / rate + 1.0)
		
		for i in range(input.size()):
			_last_l = _last_l + alpha * (input[i].x - _last_l)
			_last_r = _last_r + alpha * (input[i].y - _last_r)
			output[i] = Vector2(_last_l, _last_r)
			
		return output

func _init() -> void:
	_nodes.append(Heartbeat.new())
	_nodes.append(Granular.new())

var _filter := FilterSweep.new()

func set_tension(t: float) -> void:
	_tension = clamp(t, 0.0, 1.0)

func render(frames: int) -> PackedVector2Array:
	var sum := PackedVector2Array()
	sum.resize(frames)
	sum.fill(Vector2.ZERO)
	
	for node in _nodes:
		var buf = node.mix(frames, sample_rate, _tension)
		for i in range(frames):
			sum[i] += buf[i]
			
	return _filter.process(sum, sample_rate, _tension)

func play(player: AudioStreamPlayer) -> void:
	if player.stream is AudioStreamGenerator:
		_playback = player.get_playback()
		player.play()

func _process(_delta: float) -> void:
	if _playback:
		# Push 512 frames per process tick to keep buffer filled
		var frames := 512
		var buf = render(frames)
		for i in range(frames):
			_playback.push_frame(buf[i])

func _exit_tree() -> void:
	_playback = null
