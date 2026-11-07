extends RefCounted
class_name ChomuBoidFlockingSteeringBehavior

## ChomuBoidFlockingSteeringBehavior
##
## Reference implementation of Boid Flocking & Steering Behavior for CHoMU Systems.
## Implements Reynolds-style flocking (separation, alignment, cohesion) plus
## obstacle avoidance and target seeking. Data-driven, deterministic with a
## seeded RandomNumberGenerator, headless-safe (no rendering dependencies).
##
## Designed mobile-first: fixed neighbor radius, squared-distance checks,
## O(N * neighbors) per step, and minimal allocations.

## Configuration for a single boid's steering weights and limits.
class BoidConfig:
	var separation_weight: float = 1.5
	var alignment_weight: float = 1.0
	var cohesion_weight: float = 1.0
	var obstacle_weight: float = 1.0
	var target_weight: float = 1.0
	var max_speed: float = 5.0
	var max_force: float = 0.5
	var neighbor_radius: float = 8.0
	var separation_radius: float = 3.0
	var desired_separation: float = 2.0
	var obstacle_avoid_distance: float = 4.0

## Runtime state of one boid in the flock.
class BoidState:
	var id: int = 0
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var acceleration: Vector3 = Vector3.ZERO
	var config: BoidConfig = BoidConfig.new()

## Result of a single steering update for one boid.
class SteeringOutput:
	var id: int = 0
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var acceleration: Vector3 = Vector3.ZERO
	var separation: Vector3 = Vector3.ZERO
	var alignment: Vector3 = Vector3.ZERO
	var cohesion: Vector3 = Vector3.ZERO
	var obstacle: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3.ZERO

## Flock-level parameters shared by all boids.
@export_group("Flock")
@export var flock_size: int = 32
@export var world_bounds: AABB = AABB(Vector3(-32, -8, -32), Vector3(64, 16, 64))
@export var wrap_world: bool = true
@export var target_position: Vector3 = Vector3.ZERO
@export var obstacle_positions: Array[Vector3] = []
@export var obstacle_radii: Array[float] = []
@export var seed: int = 12345

@export_group("Defaults")
## Default configuration applied to new boids. Not @export because BoidConfig
## is a script class and cannot be exported directly.
var default_config: BoidConfig = BoidConfig.new()

## Internal state.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _boids: Array[BoidState] = []
var _initialized: bool = false

## Signal emitted when the flock is (re)initialized.
signal flock_initialized(count: int)
## Signal emitted after each simulation step.
signal flock_stepped(delta: float, outputs: Array[SteeringOutput])

## Initialize the flock with random positions inside world_bounds using the seed.
## Call this before step(). Re-initializing resets all boid state.
func initialize() -> void:
	_rng.seed = seed
	_boids.clear()
	var count: int = max(1, flock_size)
	for i in range(count):
		var boid: BoidState = BoidState.new()
		boid.id = i
		boid.position = _random_position_in_bounds()
		boid.velocity = _random_velocity()
		boid.config = _copy_config(default_config)
		_boids.append(boid)
	_initialized = true
	flock_initialized.emit(count)

## Advance the flock by delta seconds. Returns per-boid steering outputs.
## If not initialized, calls initialize() automatically.
func step(delta: float) -> Array[SteeringOutput]:
	if not _initialized:
		initialize()
	var outputs: Array[SteeringOutput] = []
	for boid in _boids:
		var out: SteeringOutput = _step_boid(boid, delta)
		outputs.append(out)
	flock_stepped.emit(delta, outputs)
	return outputs

## Get the current boid states (read-only reference to internal array).
func get_boids() -> Array[BoidState]:
	return _boids

## Get boid state by id, or null if not found.
func get_boid(id: int) -> BoidState:
	for boid in _boids:
		if boid.id == id:
			return boid
	return null

## Set the config for a specific boid id. Returns false if id not found.
func set_boid_config(id: int, config: BoidConfig) -> bool:
	for boid in _boids:
		if boid.id == id:
			boid.config = config
			return true
	return false

## Set the global target position the flock steers toward.
func set_target_position(pos: Vector3) -> void:
	target_position = pos

## Add a spherical obstacle at pos with given radius.
func add_obstacle(pos: Vector3, radius: float) -> void:
	obstacle_positions.append(pos)
	obstacle_radii.append(radius)

## Clear all obstacles.
func clear_obstacles() -> void:
	obstacle_positions.clear()
	obstacle_radii.clear()

## Save flock state to a Dictionary (positions, velocities, ids, configs).
func save_state() -> Dictionary:
	var dict: Dictionary = {
		"seed": seed,
		"flock_size": flock_size,
		"world_bounds": world_bounds,
		"wrap_world": wrap_world,
		"target_position": target_position,
		"obstacle_positions": obstacle_positions,
		"obstacle_radii": obstacle_radii,
		"boids": []
	}
	for boid in _boids:
		var b: Dictionary = {
			"id": boid.id,
			"position": boid.position,
			"velocity": boid.velocity,
			"config": _config_to_dict(boid.config)
		}
		dict["boids"].append(b)
	return dict

## Load flock state from a Dictionary produced by save_state().
## Re-initializes the flock and applies saved per-boid state.
func load_state(state: Dictionary) -> void:
	seed = state.get("seed", 12345)
	flock_size = state.get("flock_size", 32)
	world_bounds = state.get("world_bounds", AABB(Vector3(-32, -8, -32), Vector3(64, 16, 64)))
	wrap_world = state.get("wrap_world", true)
	target_position = state.get("target_position", Vector3.ZERO)
	obstacle_positions = state.get("obstacle_positions", [])
	obstacle_radii = state.get("obstacle_radii", [])
	initialize()
	var saved: Array = state.get("boids", [])
	for b in saved:
		var id: int = b.get("id", 0)
		var boid: BoidState = get_boid(id)
		if boid != null:
			boid.position = b.get("position", boid.position)
			boid.velocity = b.get("velocity", boid.velocity)
			var cfg_dict: Dictionary = b.get("config", {})
			boid.config = _dict_to_config(cfg_dict)

## Internal: step a single boid.
func _step_boid(boid: BoidState, delta: float) -> SteeringOutput:
	var sep: Vector3 = _separation(boid)
	var ali: Vector3 = _alignment(boid)
	var coh: Vector3 = _cohesion(boid)
	var obs: Vector3 = _obstacle_avoidance(boid)
	var trg: Vector3 = _target_seek(boid)

	var steering: Vector3 = sep * boid.config.separation_weight
	steering += ali * boid.config.alignment_weight
	steering += coh * boid.config.cohesion_weight
	steering += obs * boid.config.obstacle_weight
	steering += trg * boid.config.target_weight

	steering = _limit_length(steering, boid.config.max_force)
	boid.acceleration = steering
	boid.velocity += boid.acceleration * delta
	boid.velocity = _limit_length(boid.velocity, boid.config.max_speed)
	boid.position += boid.velocity * delta

	if wrap_world:
		boid.position = _wrap_position(boid.position)

	var out: SteeringOutput = SteeringOutput.new()
	out.id = boid.id
	out.position = boid.position
	out.velocity = boid.velocity
	out.acceleration = boid.acceleration
	out.separation = sep
	out.alignment = ali
	out.cohesion = coh
	out.obstacle = obs
	out.target = trg
	return out

## Internal: separation steering - steer away from close neighbors.
func _separation(boid: BoidState) -> Vector3:
	var steer: Vector3 = Vector3.ZERO
	var count: int = 0
	var sep_radius_sq: float = boid.config.separation_radius * boid.config.separation_radius
	for other in _boids:
		if other.id == boid.id:
			continue
		var diff: Vector3 = boid.position - other.position
		var dist_sq: float = diff.length_squared()
		if dist_sq > 0.0 and dist_sq < sep_radius_sq:
			var dist: float = sqrt(dist_sq)
			var diff_normalized: Vector3 = diff / dist
			# Weight by inverse distance: closer neighbors push harder.
			steer += (diff_normalized / dist)
			count += 1
	if count > 0:
		steer /= count
		steer = steer.normalized() * boid.config.max_speed
		steer -= boid.velocity
		steer = _limit_length(steer, boid.config.max_force)
	return steer

## Internal: alignment steering - match average neighbor velocity.
func _alignment(boid: BoidState) -> Vector3:
	var avg_vel: Vector3 = Vector3.ZERO
	var count: int = 0
	var radius_sq: float = boid.config.neighbor_radius * boid.config.neighbor_radius
	for other in _boids:
		if other.id == boid.id:
			continue
		var diff: Vector3 = boid.position - other.position
		if diff.length_squared() < radius_sq:
			avg_vel += other.velocity
			count += 1
	if count > 0:
		avg_vel /= count
		avg_vel = avg_vel.normalized() * boid.config.max_speed
		var steer: Vector3 = avg_vel - boid.velocity
		return _limit_length(steer, boid.config.max_force)
	return Vector3.ZERO

## Internal: cohesion steering - move toward average neighbor position.
func _cohesion(boid: BoidState) -> Vector3:
	var center: Vector3 = Vector3.ZERO
	var count: int = 0
	var radius_sq: float = boid.config.neighbor_radius * boid.config.neighbor_radius
	for other in _boids:
		if other.id == boid.id:
			continue
		var diff: Vector3 = boid.position - other.position
		if diff.length_squared() < radius_sq:
			center += other.position
			count += 1
	if count > 0:
		center /= count
		var desired: Vector3 = (center - boid.position).normalized() * boid.config.max_speed
		var steer: Vector3 = desired - boid.velocity
		return _limit_length(steer, boid.config.max_force)
	return Vector3.ZERO

## Internal: obstacle avoidance - steer away from nearby spherical obstacles.
func _obstacle_avoidance(boid: BoidState) -> Vector3:
	var steer: Vector3 = Vector3.ZERO
	var count: int = 0
	var avoid_dist: float = boid.config.obstacle_avoid_distance
	for i in range(obstacle_positions.size()):
		var pos: Vector3 = obstacle_positions[i]
		var radius: float = obstacle_radii[i] if i < obstacle_radii.size() else 1.0
		var diff: Vector3 = boid.position - pos
		var dist_sq: float = diff.length_squared()
		var threshold: float = avoid_dist + radius
		if dist_sq > 0.0 and dist_sq < threshold * threshold:
			var dist: float = sqrt(dist_sq)
			var diff_normalized: Vector3 = diff / dist
			steer += (diff_normalized / dist)
			count += 1
	if count > 0:
		steer /= count
		steer = steer.normalized() * boid.config.max_speed
		steer -= boid.velocity
		steer = _limit_length(steer, boid.config.max_force)
	return steer

## Internal: target seeking - steer toward flock target_position.
func _target_seek(boid: BoidState) -> Vector3:
	var desired: Vector3 = (target_position - boid.position).normalized() * boid.config.max_speed
	var steer: Vector3 = desired - boid.velocity
	return _limit_length(steer, boid.config.max_force)

## Internal: clamp a vector's length to max_len (Godot 4.7 has no Vector3.clamped).
func _limit_length(v: Vector3, max_len: float) -> Vector3:
	var len: float = v.length()
	if len > max_len and len > 0.0:
		return v * (max_len / len)
	return v

## Internal: wrap position into world_bounds if wrap_world enabled.
func _wrap_position(pos: Vector3) -> Vector3:
	var min_corner: Vector3 = world_bounds.position
	var max_corner: Vector3 = world_bounds.position + world_bounds.size
	var wrapped: Vector3 = pos
	if wrapped.x < min_corner.x:
		wrapped.x = max_corner.x
	elif wrapped.x > max_corner.x:
		wrapped.x = min_corner.x
	if wrapped.y < min_corner.y:
		wrapped.y = max_corner.y
	elif wrapped.y > max_corner.y:
		wrapped.y = min_corner.y
	if wrapped.z < min_corner.z:
		wrapped.z = max_corner.z
	elif wrapped.z > max_corner.z:
		wrapped.z = min_corner.z
	return wrapped

## Internal: random position inside world_bounds.
func _random_position_in_bounds() -> Vector3:
	var min_corner: Vector3 = world_bounds.position
	var size: Vector3 = world_bounds.size
	return Vector3(
		_rng.randf_range(min_corner.x, min_corner.x + size.x),
		_rng.randf_range(min_corner.y, min_corner.y + size.y),
		_rng.randf_range(min_corner.z, min_corner.z + size.z)
	)

## Internal: random velocity with magnitude up to max_speed.
func _random_velocity() -> Vector3:
	var speed: float = _rng.randf_range(1.0, default_config.max_speed)
	var dir: Vector3 = Vector3(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	).normalized()
	return dir * speed

## Internal: deep-copy a BoidConfig by field assignment (RefCounted has no clone).
func _copy_config(source: BoidConfig) -> BoidConfig:
	var dest: BoidConfig = BoidConfig.new()
	dest.separation_weight = source.separation_weight
	dest.alignment_weight = source.alignment_weight
	dest.cohesion_weight = source.cohesion_weight
	dest.obstacle_weight = source.obstacle_weight
	dest.target_weight = source.target_weight
	dest.max_speed = source.max_speed
	dest.max_force = source.max_force
	dest.neighbor_radius = source.neighbor_radius
	dest.separation_radius = source.separation_radius
	dest.desired_separation = source.desired_separation
	dest.obstacle_avoid_distance = source.obstacle_avoid_distance
	return dest

## Internal: convert BoidConfig to Dictionary.
func _config_to_dict(config: BoidConfig) -> Dictionary:
	return {
		"separation_weight": config.separation_weight,
		"alignment_weight": config.alignment_weight,
		"cohesion_weight": config.cohesion_weight,
		"obstacle_weight": config.obstacle_weight,
		"target_weight": config.target_weight,
		"max_speed": config.max_speed,
		"max_force": config.max_force,
		"neighbor_radius": config.neighbor_radius,
		"separation_radius": config.separation_radius,
		"desired_separation": config.desired_separation,
		"obstacle_avoid_distance": config.obstacle_avoid_distance
	}

## Internal: convert Dictionary to BoidConfig.
func _dict_to_config(dict: Dictionary) -> BoidConfig:
	var config: BoidConfig = BoidConfig.new()
	config.separation_weight = dict.get("separation_weight", 1.5)
	config.alignment_weight = dict.get("alignment_weight", 1.0)
	config.cohesion_weight = dict.get("cohesion_weight", 1.0)
	config.obstacle_weight = dict.get("obstacle_weight", 1.0)
	config.target_weight = dict.get("target_weight", 1.0)
	config.max_speed = dict.get("max_speed", 5.0)
	config.max_force = dict.get("max_force", 0.5)
	config.neighbor_radius = dict.get("neighbor_radius", 8.0)
	config.separation_radius = dict.get("separation_radius", 3.0)
	config.desired_separation = dict.get("desired_separation", 2.0)
	config.obstacle_avoid_distance = dict.get("obstacle_avoid_distance", 4.0)
	return config
