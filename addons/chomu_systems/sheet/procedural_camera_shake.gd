extends RefCounted
class_name ChomuProceduralCameraShake

## ChomuProceduralCameraShake
##
## Noise-based camera turbulence for explosions and horror jumpscares.
## Uses a seeded RandomNumberGenerator for deterministic playback and
## Perlin-style noise summed over octaves (fBm) to produce shake offsets.
## Designed mobile-first: cheap per-frame math, low RAM, no rendering
## dependencies. State can be saved/loaded as a Dictionary.

## Configuration for a single shake event.
class ShakeConfig:
	var amplitude: float = 1.0
	var frequency: float = 10.0
	var decay: float = 2.0
	var duration: float = 1.0
	var seed: int = 0

## Runtime state for an active shake instance.
class ShakeInstance:
	var config: ShakeConfig
	var elapsed: float = 0.0
	var active: bool = true

## Main shake controller.
## Applies offsets to a target Node3D each frame via apply_to(node, delta).
var rng: RandomNumberGenerator
var instances: Array[ShakeInstance]
var config_templates: Dictionary
var _octaves: int
var _lacunarity: float
var _gain: float

func _init() -> void:
	rng = RandomNumberGenerator.new()
	instances = []
	config_templates = {}
	_octaves = 4
	_lacunarity = 2.0
	_gain = 0.5

## Register a named shake template for later triggering.
## name: template identifier
## config: ShakeConfig describing amplitude, frequency, decay, duration, seed
func register_template(name: String, config: ShakeConfig) -> void:
	config_templates[name] = config

## Trigger a registered shake by name.
## name: template identifier (must be registered)
## override: optional ShakeConfig to override template values
func trigger(name: String, override: ShakeConfig = null) -> void:
	var base: ShakeConfig
	if config_templates.has(name):
		base = config_templates[name]
	else:
		base = ShakeConfig.new()
	var cfg: ShakeConfig
	if override != null:
		cfg = override
	else:
		cfg = base
	# Clone so each instance has independent mutable state.
	var inst: ShakeInstance = ShakeInstance.new()
	inst.config = ShakeConfig.new()
	inst.config.amplitude = cfg.amplitude
	inst.config.frequency = cfg.frequency
	inst.config.decay = cfg.decay
	inst.config.duration = cfg.duration
	inst.config.seed = cfg.seed
	inst.elapsed = 0.0
	inst.active = true
	instances.append(inst)

## Trigger a one-off shake with explicit values.
func shake(amplitude: float, frequency: float, decay: float, duration: float, seed: int = 0) -> void:
	var cfg: ShakeConfig = ShakeConfig.new()
	cfg.amplitude = amplitude
	cfg.frequency = frequency
	cfg.decay = decay
	cfg.duration = duration
	cfg.seed = seed
	var inst: ShakeInstance = ShakeInstance.new()
	inst.config = cfg
	inst.elapsed = 0.0
	inst.active = true
	instances.append(inst)

## Stop all active shakes immediately.
func clear() -> void:
	instances.clear()

## Advance all shake instances by delta and prune finished ones.
## Returns the combined offset Vector3 for this frame.
func update(delta: float) -> Vector3:
	var combined: Vector3 = Vector3.ZERO
	var i: int = 0
	while i < instances.size():
		var inst: ShakeInstance = instances[i]
		if not inst.active:
			instances.remove_at(i)
			continue
		inst.elapsed += delta
		if inst.elapsed >= inst.config.duration:
			inst.active = false
			instances.remove_at(i)
			continue
		var t: float = inst.elapsed / inst.config.duration
		var decay: float = 1.0 - clamp(t, 0.0, 1.0) * clamp(inst.config.decay, 0.0, 10.0)
		var offset: Vector3 = _sample_offset(inst, inst.elapsed) * inst.config.amplitude * decay
		combined += offset
		i += 1
	return combined

## Apply the current combined shake offset to a node's position.
## Modifies node.position directly each frame it is called.
func apply_to(node: Node3D, delta: float) -> void:
	var offset: Vector3 = update(delta)
	node.position += offset

## Get the current combined offset without applying it.
func get_offset(delta: float) -> Vector3:
	return update(delta)

## Save active shake state to a Dictionary.
func save_state() -> Dictionary:
	var arr: Array[Dictionary] = []
	for inst in instances:
		arr.push_back({
			"elapsed": inst.elapsed,
			"active": inst.active,
			"amplitude": inst.config.amplitude,
			"frequency": inst.config.frequency,
			"decay": inst.config.decay,
			"duration": inst.config.duration,
			"seed": inst.config.seed,
		})
	return {"instances": arr, "octaves": _octaves, "lacunarity": _lacunarity, "gain": _gain}

## Load shake state from a Dictionary produced by save_state.
func load_state(state: Dictionary) -> void:
	instances.clear()
	var arr: Array = state.get("instances", [])
	for d in arr:
		var inst: ShakeInstance = ShakeInstance.new()
		inst.config = ShakeConfig.new()
		inst.config.amplitude = float(d.get("amplitude", 1.0))
		inst.config.frequency = float(d.get("frequency", 10.0))
		inst.config.decay = float(d.get("decay", 2.0))
		inst.config.duration = float(d.get("duration", 1.0))
		inst.config.seed = int(d.get("seed", 0))
		inst.elapsed = float(d.get("elapsed", 0.0))
		inst.active = bool(d.get("active", true))
		instances.append(inst)
	_octaves = int(state.get("octaves", 4))
	_lacunarity = float(state.get("lacunarity", 2.0))
	_gain = float(state.get("gain", 0.5))

## --- internal noise ---

func _sample_offset(inst: ShakeInstance, t: float) -> Vector3:
	rng.seed = inst.config.seed
	var x: float = _fbm(t * inst.config.frequency, inst.config.seed + 0)
	var y: float = _fbm(t * inst.config.frequency, inst.config.seed + 1)
	var z: float = _fbm(t * inst.config.frequency, inst.config.seed + 2)
	return Vector3(x, y, z)

func _fbm(t: float, seed_offset: int) -> float:
	var value: float = 0.0
	var amplitude: float = 1.0
	var freq: float = 1.0
	var max_value: float = 0.0
	for i in range(_octaves):
		value += _perlin_1d(t * freq, seed_offset + i) * amplitude
		max_value += amplitude
		amplitude *= _gain
		freq *= _lacunarity
	if max_value > 0.0:
		value /= max_value
	return value

func _perlin_1d(t: float, seed_offset: int) -> float:
	# Simple deterministic lattice noise using the seeded RNG.
	var i: int = int(t)
	var f: float = t - i
	rng.seed = i + seed_offset * 1000003
	var a: float = rng.randf_range(-1.0, 1.0)
	rng.seed = i + 1 + seed_offset * 1000003
	var b: float = rng.randf_range(-1.0, 1.0)
	var u: float = f * f * (3.0 - 2.0 * f)
	return a + (b - a) * u
